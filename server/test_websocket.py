import asyncio
import websockets
import json
import logging
import argparse
import sys
import time
from typing import Optional

# Setup logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("WebSocketClient")

# Default settings
DEFAULT_SERVER = "localhost"
DEFAULT_PORT = 8000
MAX_RECONNECT_ATTEMPTS = 5
RECONNECT_DELAY = 3  # seconds

class WebSocketClient:
    def __init__(self, server: str, port: int, max_reconnect: int = MAX_RECONNECT_ATTEMPTS):
        self.server = server
        self.port = port
        self.uri = f"ws://{server}:{port}/devices/ws"
        self.max_reconnect = max_reconnect
        self.reconnect_attempts = 0
        self.websocket: Optional[websockets.WebSocketClientProtocol] = None
        self.connected = False
        self.last_devices = []

    async def connect(self) -> bool:
        """Establish connection to the WebSocket server"""
        logger.info(f"Connecting to {self.uri}")
        
        try:
            self.websocket = await websockets.connect(
                self.uri, 
                ping_interval=20,
                ping_timeout=10,
                close_timeout=5
            )
            self.connected = True
            self.reconnect_attempts = 0
            logger.info("Connected to WebSocket server")
            return True
        except Exception as e:
            logger.error(f"Connection error: {e}")
            return False

    async def reconnect(self) -> bool:
        """Attempt to reconnect to the server"""
        if self.reconnect_attempts >= self.max_reconnect:
            logger.error(f"Max reconnection attempts ({self.max_reconnect}) reached")
            return False
            
        self.reconnect_attempts += 1
        delay = RECONNECT_DELAY * self.reconnect_attempts
        
        logger.info(f"Reconnection attempt {self.reconnect_attempts}/{self.max_reconnect} after {delay}s")
        await asyncio.sleep(delay)
        
        return await self.connect()

    async def send_message(self, message_data: dict) -> bool:
        """Send a message to the WebSocket server"""
        if not self.connected or not self.websocket:
            logger.error("Cannot send message: not connected")
            return False
            
        try:
            message = json.dumps(message_data)
            await self.websocket.send(message)
            logger.info(f"Sent: {message}")
            return True
        except Exception as e:
            logger.error(f"Error sending message: {e}")
            self.connected = False
            return False

    async def request_device_status(self, device_id: str) -> bool:
        """Request status for a specific device"""
        return await self.send_message({
            "type": "request_status",
            "device_id": device_id
        })

    async def listen(self):
        """Main loop to listen for WebSocket messages"""
        while True:
            if not self.connected:
                success = await self.connect() if self.reconnect_attempts == 0 else await self.reconnect()
                if not success:
                    if self.reconnect_attempts >= self.max_reconnect:
                        logger.error("Failed to connect after max attempts. Exiting.")
                        return
                    continue
            
            try:
                # Listen for messages
                while self.connected:
                    try:
                        message = await self.websocket.recv()
                        data = json.loads(message)
                        logger.info(f"Received: {json.dumps(data, indent=2)}")
                        
                        # Process different message types
                        if data.get("type") == "initial_devices" and data.get("devices"):
                            self.last_devices = data.get("devices", [])
                            logger.info(f"Received {len(self.last_devices)} devices")
                            
                            # Request status for the first device
                            if self.last_devices:
                                device_id = self.last_devices[0]["id"]
                                logger.info(f"Requesting status for device {device_id}")
                                await self.request_device_status(device_id)
                        
                        elif data.get("device") and data.get("simulation"):
                            # Status update received
                            device = data.get("device", {})
                            simulation = data.get("simulation", {})
                            
                            device_id = device.get("id", "unknown")
                            is_running = simulation.get("is_running", False)
                            
                            status = "RUNNING" if is_running else "STOPPED"
                            logger.info(f"Device {device_id} simulation status: {status}")
                            
                            # Display progress information if available
                            if is_running and "current_iteration" in simulation and "iterations" in simulation:
                                current = simulation["current_iteration"]
                                total = simulation["iterations"]
                                percentage = round((current / total) * 100, 1) if total > 0 else 0
                                logger.info(f"Progress: {current}/{total} ({percentage}%)")
                            
                    except websockets.exceptions.ConnectionClosed as e:
                        logger.warning(f"Connection closed: {e}")
                        self.connected = False
                        break
                    except json.JSONDecodeError as e:
                        logger.error(f"Invalid JSON received: {e}")
                    except Exception as e:
                        logger.error(f"Error in message loop: {e}")
                        self.connected = False
                        break
                        
            except Exception as e:
                logger.error(f"Unexpected error in listen loop: {e}")
                self.connected = False
                await asyncio.sleep(1)

async def interactive_mode(client: WebSocketClient):
    """Run an interactive session allowing to send commands"""
    print("\nInteractive WebSocket Client")
    print("===========================")
    print("Commands:")
    print("  status <device_id> - Request status for a device")
    print("  list              - Show last known devices")
    print("  quit/exit         - Exit the client")
    print()
    
    while True:
        try:
            command = input("> ").strip()
            
            if command.lower() in ("quit", "exit"):
                print("Exiting...")
                return
            
            elif command.lower() == "list":
                if not client.last_devices:
                    print("No devices known yet")
                else:
                    for i, device in enumerate(client.last_devices):
                        print(f"{i+1}. {device.get('model', 'Unknown')} ({device.get('id')})")
            
            elif command.lower().startswith("status "):
                parts = command.split(maxsplit=1)
                if len(parts) < 2:
                    print("Usage: status <device_id>")
                    continue
                    
                device_id = parts[1].strip()
                if await client.request_device_status(device_id):
                    print(f"Status request sent for device {device_id}")
                else:
                    print("Failed to send status request")
            
            else:
                print("Unknown command. Type 'quit' to exit.")
                
        except KeyboardInterrupt:
            print("\nExiting...")
            return
        except Exception as e:
            print(f"Error: {e}")


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="WebSocket Client for Drono App")
    parser.add_argument("--server", default=DEFAULT_SERVER, help=f"Server hostname (default: {DEFAULT_SERVER})")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Server port (default: {DEFAULT_PORT})")
    parser.add_argument("--reconnect", type=int, default=MAX_RECONNECT_ATTEMPTS, 
                       help=f"Maximum reconnection attempts (default: {MAX_RECONNECT_ATTEMPTS})")
    parser.add_argument("--interactive", action="store_true", help="Run in interactive mode")
    
    return parser.parse_args()

async def main():
    args = parse_args()
    
    client = WebSocketClient(args.server, args.port, args.reconnect)
    
    # Start the listener in a separate task
    listener_task = asyncio.create_task(client.listen())
    
    try:
        if args.interactive:
            # Run interactive mode
            await interactive_mode(client)
            listener_task.cancel()
        else:
            # Just run the listener
            await listener_task
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        listener_task.cancel()
        try:
            await listener_task
        except asyncio.CancelledError:
            pass
    except Exception as e:
        logger.error(f"Error in main: {e}")
    finally:
        if client.websocket:
            await client.websocket.close()
        logger.info("Client stopped")

if __name__ == "__main__":
    logger.info("Starting WebSocket client")
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(0) 