import logging
import json
import asyncio
from typing import Dict, List, Any, Set
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

class ConnectionManager:
    """Manages WebSocket connections and channels"""
    
    def __init__(self):
        """Initialize the connection manager"""
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.broadcast_queue = asyncio.Queue()
        
    async def connect(self, websocket: WebSocket, channel: str):
        """Connect a new WebSocket client"""
        await websocket.accept()
        
        if channel not in self.active_connections:
            self.active_connections[channel] = []
            
        self.active_connections[channel].append(websocket)
        logger.info(f"Client connected to channel: {channel}")
        
    def disconnect(self, websocket: WebSocket, channel: str):
        """Disconnect a WebSocket client"""
        if channel in self.active_connections:
            if websocket in self.active_connections[channel]:
                self.active_connections[channel].remove(websocket)
                logger.info(f"Client disconnected from channel: {channel}")
            
            # Clean up empty channels
            if not self.active_connections[channel]:
                del self.active_connections[channel]
    
    async def send_personal_message(self, message: Dict[str, Any], websocket: WebSocket):
        """Send a message to a specific client"""
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Error sending personal message: {e}")
    
    async def broadcast_channel(self, message: Dict[str, Any], channel: str):
        """Broadcast a message to all clients in a channel"""
        if channel in self.active_connections:
            disconnected_websockets = []
            
            for websocket in self.active_connections[channel]:
                try:
                    await websocket.send_json(message)
                except Exception as e:
                    logger.error(f"Error broadcasting to channel {channel}: {e}")
                    disconnected_websockets.append(websocket)
            
            # Clean up disconnected websockets
            for websocket in disconnected_websockets:
                self.disconnect(websocket, channel)
    
    async def broadcast_all(self, message: Dict[str, Any]):
        """Broadcast a message to all connected clients in all channels"""
        for channel in list(self.active_connections.keys()):
            await self.broadcast_channel(message, channel)
            
    async def enqueue_broadcast(self, message: Dict[str, Any]):
        """Add a message to the broadcast queue"""
        await self.broadcast_queue.put(message)
        
    async def start_broadcast_worker(self):
        """Worker to process broadcast queue"""
        while True:
            try:
                message = await self.broadcast_queue.get()
                await self.broadcast_all(message)
                self.broadcast_queue.task_done()
            except Exception as e:
                logger.error(f"Error in broadcast worker: {e}")
            
            # Add a small delay to avoid overwhelming connections
            await asyncio.sleep(0.1)
    
    def get_connected_clients_count(self) -> int:
        """Get the total number of connected clients"""
        count = 0
        for channel in self.active_connections:
            count += len(self.active_connections[channel])
        return count
    
    def get_active_channels(self) -> List[str]:
        """Get a list of active channels"""
        return list(self.active_connections.keys())

# Create global instance
connection_manager = ConnectionManager() 