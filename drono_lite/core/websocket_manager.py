import logging
import json
import asyncio
from typing import Dict, List, Any, Set
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

class ConnectionManager:
    """Manager for WebSocket connections"""
    
    def __init__(self):
        """Initialize the connection manager"""
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self.connection_info: Dict[WebSocket, Dict[str, Any]] = {}
        
    async def connect(self, websocket: WebSocket, channel: str = "default"):
        """
        Accept a WebSocket connection and add it to the appropriate channel
        
        Args:
            websocket: The WebSocket connection
            channel: The channel to subscribe to
        """
        await websocket.accept()
        
        if channel not in self.active_connections:
            self.active_connections[channel] = []
            
        self.active_connections[channel].append(websocket)
        self.connection_info[websocket] = {
            "channel": channel,
            "connected_at": asyncio.get_event_loop().time()
        }
        
        logger.info(f"Client connected to channel '{channel}'. "
                   f"Total connections: {self.count_connections()}")
        
    def disconnect(self, websocket: WebSocket, channel: str = None):
        """
        Disconnect a WebSocket connection
        
        Args:
            websocket: The WebSocket connection to disconnect
            channel: Optional channel to disconnect from (if None, use the stored channel)
        """
        if websocket in self.connection_info:
            # Use provided channel or get from stored info
            if channel is None:
                channel = self.connection_info[websocket]["channel"]
            
            if channel in self.active_connections:
                if websocket in self.active_connections[channel]:
                    self.active_connections[channel].remove(websocket)
                    
                # Remove empty channels
                if len(self.active_connections[channel]) == 0:
                    del self.active_connections[channel]
                    
            # Remove connection info
            if websocket in self.connection_info:
                del self.connection_info[websocket]
                
            logger.info(f"Client disconnected from channel '{channel}'. "
                       f"Total connections: {self.count_connections()}")
                
    async def broadcast(self, channel: str, message: Dict[str, Any]):
        """
        Broadcast a message to all clients in a specific channel
        
        Args:
            channel: The channel to broadcast to
            message: The message to broadcast
        """
        if channel not in self.active_connections:
            return
            
        disconnected_websockets = []
        
        # Convert message to JSON
        json_message = json.dumps(message)
        
        # Broadcast to all connections in the channel
        for websocket in self.active_connections[channel]:
            try:
                await websocket.send_text(json_message)
            except Exception as e:
                logger.warning(f"Failed to send message to WebSocket: {e}")
                disconnected_websockets.append(websocket)
                
        # Clean up disconnected websockets
        for websocket in disconnected_websockets:
            self.disconnect(websocket)
            
    async def broadcast_all(self, message: Dict[str, Any]):
        """
        Broadcast a message to all connected clients
        
        Args:
            message: The message to broadcast
        """
        for channel in list(self.active_connections.keys()):
            await self.broadcast(channel, message)
            
    def count_connections(self) -> int:
        """
        Count the total number of active connections
        
        Returns:
            The total number of connections
        """
        return sum(len(connections) for connections in self.active_connections.values())
        
    def get_channels(self) -> List[str]:
        """
        Get a list of active channels
        
        Returns:
            List of channel names
        """
        return list(self.active_connections.keys())
        
    def get_channel_counts(self) -> Dict[str, int]:
        """
        Get counts of connections per channel
        
        Returns:
            Dictionary with channel names and connection counts
        """
        return {
            channel: len(connections)
            for channel, connections in self.active_connections.items()
        }

# Create global instance
connection_manager = ConnectionManager() 