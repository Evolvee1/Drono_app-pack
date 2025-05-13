import asyncio
import json
import logging
from typing import Dict, Set, Optional, Any
from datetime import datetime
from fastapi import WebSocket
from models.database_models import Alert, DeviceStatus

logger = logging.getLogger(__name__)

# Custom JSON encoder to handle datetime serialization
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)

class WebSocketManager:
    def __init__(self):
        self.active_connections: Dict[str, Set[WebSocket]] = {
            "devices": set(),
            "alerts": set(),
            "status": set()
        }
        self.device_status: Dict[str, DeviceStatus] = {}
        self.broadcast_queue = None
        self.processing_task = None
        self._loop = None

    async def start(self):
        """Start the broadcast processing task"""
        if not self.processing_task:
            # Get the current event loop
            self._loop = asyncio.get_running_loop()
            # Create queue in the same event loop
            self.broadcast_queue = asyncio.Queue()
            self.processing_task = self._loop.create_task(self._process_broadcasts())
            logger.info("WebSocket broadcast processing task started")

    async def stop(self):
        """Stop the broadcast processing task"""
        if self.processing_task:
            self.processing_task.cancel()
            try:
                await self.processing_task
            except asyncio.CancelledError:
                pass
            self.processing_task = None
            logger.info("WebSocket broadcast processing task stopped")

    async def connect(self, websocket: WebSocket, channel: str):
        """Connect a new WebSocket client to a channel"""
        await websocket.accept()
        
        # Ensure channel exists, create if not
        if channel not in self.active_connections:
            self.active_connections[channel] = set()
            
        self.active_connections[channel].add(websocket)
        logger.info(f"New WebSocket connection to {channel} channel (total: {len(self.active_connections[channel])})")
        
        # Send initial status for devices channel
        if channel == "devices":
            try:
                # Send current device status immediately after connection
                if self.device_status:
                    device_statuses = {}
                    for device_id, status in self.device_status.items():
                        if hasattr(status, "to_dict"):
                            device_statuses[device_id] = status.to_dict()
                        elif hasattr(status, "dict"):
                            device_statuses[device_id] = status.dict()
                        else:
                            device_statuses[device_id] = status
                    
                    message = json.dumps({
                        "type": "device_status",
                        "data": {
                            "devices": device_statuses
                        }
                    }, cls=CustomJSONEncoder)
                    await websocket.send_text(message)
            except Exception as e:
                logger.error(f"Error sending initial device status: {e}")

    async def disconnect(self, websocket: WebSocket, channel: str):
        """Disconnect a WebSocket client from a channel"""
        if channel in self.active_connections and websocket in self.active_connections[channel]:
            self.active_connections[channel].remove(websocket)
            logger.info(f"WebSocket disconnected from {channel} channel (remaining: {len(self.active_connections[channel])})")

    async def broadcast_alert(self, alert: Alert):
        """Broadcast an alert to all connected clients"""
        if not self.broadcast_queue:
            logger.warning("Broadcast queue not initialized. Call start() first.")
            return
            
        try:
            # Use to_dict to handle datetime serialization
            alert_data = alert.to_dict() if hasattr(alert, "to_dict") else alert.dict()
            
            await self.broadcast_queue.put({
                "type": "alert",
                "channel": "alerts",
                "data": alert_data
            })
        except Exception as e:
            logger.error(f"Failed to queue alert broadcast: {e}")

    async def broadcast_device_status(self, device_id: str, status: DeviceStatus):
        """Broadcast device status update"""
        if not self.broadcast_queue:
            logger.warning("Broadcast queue not initialized. Call start() first.")
            return
            
        self.device_status[device_id] = status
        try:
            # Use to_dict to handle datetime serialization
            status_data = status.to_dict() if hasattr(status, "to_dict") else (
                status.dict() if hasattr(status, "dict") else status
            )
            
            await self.broadcast_queue.put({
                "type": "device_status",
                "channel": "devices",
                "data": {
                    "device_id": device_id,
                    "status": status_data
                }
            })
        except Exception as e:
            logger.error(f"Failed to queue device status broadcast: {e}")

    async def broadcast_simulation_progress(self, device_id: str, progress: Dict):
        """Broadcast simulation progress update"""
        if not self.broadcast_queue:
            logger.warning("Broadcast queue not initialized. Call start() first.")
            return
            
        try:
            # Make a copy and ensure all datetime objects are converted to strings
            progress_data = {}
            for key, value in progress.items():
                if isinstance(value, datetime):
                    progress_data[key] = value.isoformat()
                else:
                    progress_data[key] = value
                
            await self.broadcast_queue.put({
                "type": "simulation_progress",
                "channel": "status",
                "data": {
                    "device_id": device_id,
                    "progress": progress_data
                }
            })
        except Exception as e:
            logger.error(f"Failed to queue simulation progress broadcast: {e}")

    async def send_message(self, channel: str, message_type: str, data: Dict[str, Any]):
        """Send a custom message to a specific channel"""
        if not self.broadcast_queue:
            logger.warning("Broadcast queue not initialized. Call start() first.")
            return
            
        try:
            # Convert any datetime objects in data to ISO strings
            processed_data = self._process_datetime_in_data(data)
            
            await self.broadcast_queue.put({
                "type": message_type,
                "channel": channel,
                "data": processed_data
            })
        except Exception as e:
            logger.error(f"Failed to queue custom message broadcast: {e}")
    
    def _process_datetime_in_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively process dictionary and convert datetime objects to ISO strings"""
        if not isinstance(data, dict):
            return data
            
        result = {}
        for key, value in data.items():
            if isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, dict):
                result[key] = self._process_datetime_in_data(value)
            elif isinstance(value, list):
                result[key] = [
                    item.isoformat() if isinstance(item, datetime) else 
                    (self._process_datetime_in_data(item) if isinstance(item, dict) else item)
                    for item in value
                ]
            else:
                result[key] = value
        return result

    async def _process_broadcasts(self):
        """Process broadcasts from the queue"""
        logger.info("Starting WebSocket broadcast processing loop")
        while True:
            try:
                broadcast = await self.broadcast_queue.get()
                channel = broadcast["channel"]
                message_data = {
                    "type": broadcast["type"],
                    "data": broadcast["data"]
                }
                
                # Use CustomJSONEncoder to ensure all datetime objects are properly serialized
                message = json.dumps(message_data, cls=CustomJSONEncoder)

                # Get all connections for the channel
                if channel in self.active_connections:
                    connections = self.active_connections[channel].copy()
                    
                    # Send to all connected clients
                    disconnected = []
                    for connection in connections:
                        try:
                            await connection.send_text(message)
                        except Exception as e:
                            logger.error(f"Error sending to WebSocket: {str(e)}")
                            # Track failed connection
                            disconnected.append(connection)
                    
                    # Remove disconnected clients
                    for connection in disconnected:
                        self.active_connections[channel].discard(connection)

                self.broadcast_queue.task_done()

            except asyncio.CancelledError:
                logger.info("WebSocket broadcast processing loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing broadcast: {str(e)}")

    async def get_device_status(self, device_id: str) -> Optional[DeviceStatus]:
        """Get the current status of a device"""
        return self.device_status.get(device_id)

    async def get_all_device_statuses(self) -> Dict[str, DeviceStatus]:
        """Get the current status of all devices"""
        return self.device_status.copy()

# Global WebSocket manager instance
websocket_manager = WebSocketManager() 
                }
                
                # Use CustomJSONEncoder to ensure all datetime objects are properly serialized
                message = json.dumps(message_data, cls=CustomJSONEncoder)

                # Get all connections for the channel
                if channel in self.active_connections:
                    connections = self.active_connections[channel].copy()
                    
                    # Send to all connected clients
                    disconnected = []
                    for connection in connections:
                        try:
                            await connection.send_text(message)
                        except Exception as e:
                            logger.error(f"Error sending to WebSocket: {str(e)}")
                            # Track failed connection
                            disconnected.append(connection)
                    
                    # Remove disconnected clients
                    for connection in disconnected:
                        self.active_connections[channel].discard(connection)

                self.broadcast_queue.task_done()

            except asyncio.CancelledError:
                logger.info("WebSocket broadcast processing loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing broadcast: {str(e)}")

    async def get_device_status(self, device_id: str) -> Optional[DeviceStatus]:
        """Get the current status of a device"""
        return self.device_status.get(device_id)

    async def get_all_device_statuses(self) -> Dict[str, DeviceStatus]:
        """Get the current status of all devices"""
        return self.device_status.copy()

# Global WebSocket manager instance