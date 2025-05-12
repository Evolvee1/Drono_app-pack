from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import json
import asyncio
import logging
from datetime import datetime
import random

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mock device data
mock_devices = [
    {
        'id': 'XYZ123',
        'name': 'Samsung Galaxy S21',
        'model': 'SM-G991U',
        'status': 'online',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '8 GB',
        'storage_size': '128 GB',
        'cpu_usage': 42,
        'memory_usage': 65,
        'battery': '78%',
        'uptime': 24.5,
        'temperature': 38,
        'network_usage': 125,
        'last_seen': datetime.now().isoformat(),
        'serial': 'R58M42ABCDE',
        'sim_status': 'Active',
        'sim_provider': 'AT&T'
    },
    {
        'id': 'ABC456',
        'name': 'Google Pixel 6',
        'model': 'GR1YH',
        'status': 'online',
        'os_version': 'Android 13',
        'cpu_info': 'Google Tensor',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 35,
        'memory_usage': 48,
        'battery': '45%',
        'uptime': 12.75,
        'temperature': 42,
        'network_usage': 87,
        'last_seen': datetime.now().isoformat(),
        'serial': 'PX6729FGHIJ',
        'sim_status': 'Active',
        'sim_provider': 'T-Mobile'
    },
    {
        'id': 'DEF789',
        'name': 'OnePlus 9 Pro',
        'model': 'LE2121',
        'status': 'offline',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 0,
        'memory_usage': 0,
        'battery': '9%',
        'uptime': 48.2,
        'temperature': 25,
        'network_usage': 0,
        'last_seen': datetime.now().isoformat(),
        'serial': 'OP9P15KLMNO',
        'sim_status': 'Inactive',
        'sim_provider': 'Verizon'
    }
]

# Connected WebSocket clients
connected_clients = []

@app.get("/")
async def root():
    return {"message": "Drono Mock API Server"}

@app.get("/devices")
async def get_devices():
    # Update timestamps
    for device in mock_devices:
        device['last_seen'] = datetime.now().isoformat()
        # Add some random fluctuation to stats
        if device['status'] == 'online':
            device['cpu_usage'] = min(100, max(0, device['cpu_usage'] + random.randint(-5, 5)))
            device['memory_usage'] = min(100, max(0, device['memory_usage'] + random.randint(-3, 3)))
            device['temperature'] = min(60, max(20, device['temperature'] + random.randint(-2, 2)))
            device['uptime'] += 0.1
    
    return mock_devices

@app.websocket("/devices/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_clients.append(websocket)
    logger.info(f"WebSocket client connected. Total clients: {len(connected_clients)}")
    
    try:
        while True:
            # Just keep the connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        connected_clients.remove(websocket)
        logger.info(f"WebSocket client disconnected. Remaining clients: {len(connected_clients)}")

# Background task to broadcast device updates
async def broadcast_device_updates():
    while True:
        if connected_clients:
            # Update device data
            for device in mock_devices:
                if device['status'] == 'online':
                    device['last_seen'] = datetime.now().isoformat()
                    device['cpu_usage'] = min(100, max(0, device['cpu_usage'] + random.randint(-5, 5)))
                    device['memory_usage'] = min(100, max(0, device['memory_usage'] + random.randint(-3, 3)))
                    device['temperature'] = min(60, max(20, device['temperature'] + random.randint(-2, 2)))
                    device['uptime'] += 0.1
            
            # Send to all connected clients
            for client in connected_clients:
                try:
                    await client.send_json(mock_devices)
                except Exception as e:
                    logger.error(f"Error sending to client: {e}")
                    # Remove disconnected clients
                    if client in connected_clients:
                        connected_clients.remove(client)
        
        # Wait for 5 seconds before next update
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(broadcast_device_updates())
    logger.info("Started background task for device updates")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080) 
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import json
import asyncio
import logging
from datetime import datetime
import random

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mock device data
mock_devices = [
    {
        'id': 'XYZ123',
        'name': 'Samsung Galaxy S21',
        'model': 'SM-G991U',
        'status': 'online',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '8 GB',
        'storage_size': '128 GB',
        'cpu_usage': 42,
        'memory_usage': 65,
        'battery': '78%',
        'uptime': 24.5,
        'temperature': 38,
        'network_usage': 125,
        'last_seen': datetime.now().isoformat(),
        'serial': 'R58M42ABCDE',
        'sim_status': 'Active',
        'sim_provider': 'AT&T'
    },
    {
        'id': 'ABC456',
        'name': 'Google Pixel 6',
        'model': 'GR1YH',
        'status': 'online',
        'os_version': 'Android 13',
        'cpu_info': 'Google Tensor',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 35,
        'memory_usage': 48,
        'battery': '45%',
        'uptime': 12.75,
        'temperature': 42,
        'network_usage': 87,
        'last_seen': datetime.now().isoformat(),
        'serial': 'PX6729FGHIJ',
        'sim_status': 'Active',
        'sim_provider': 'T-Mobile'
    },
    {
        'id': 'DEF789',
        'name': 'OnePlus 9 Pro',
        'model': 'LE2121',
        'status': 'offline',
        'os_version': 'Android 12',
        'cpu_info': 'Snapdragon 888',
        'ram_size': '12 GB',
        'storage_size': '256 GB',
        'cpu_usage': 0,
        'memory_usage': 0,
        'battery': '9%',
        'uptime': 48.2,
        'temperature': 25,
        'network_usage': 0,
        'last_seen': datetime.now().isoformat(),
        'serial': 'OP9P15KLMNO',
        'sim_status': 'Inactive',
        'sim_provider': 'Verizon'
    }
]

# Connected WebSocket clients
connected_clients = []

@app.get("/")
async def root():
    return {"message": "Drono Mock API Server"}

@app.get("/devices")
async def get_devices():
    # Update timestamps
    for device in mock_devices:
        device['last_seen'] = datetime.now().isoformat()
        # Add some random fluctuation to stats
        if device['status'] == 'online':
            device['cpu_usage'] = min(100, max(0, device['cpu_usage'] + random.randint(-5, 5)))
            device['memory_usage'] = min(100, max(0, device['memory_usage'] + random.randint(-3, 3)))
            device['temperature'] = min(60, max(20, device['temperature'] + random.randint(-2, 2)))
            device['uptime'] += 0.1
    
    return mock_devices

@app.websocket("/devices/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_clients.append(websocket)
    logger.info(f"WebSocket client connected. Total clients: {len(connected_clients)}")
    
    try:
        while True:
            # Just keep the connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        connected_clients.remove(websocket)
        logger.info(f"WebSocket client disconnected. Remaining clients: {len(connected_clients)}")

# Background task to broadcast device updates
async def broadcast_device_updates():
    while True:
        if connected_clients:
            # Update device data
            for device in mock_devices:
                if device['status'] == 'online':
                    device['last_seen'] = datetime.now().isoformat()
                    device['cpu_usage'] = min(100, max(0, device['cpu_usage'] + random.randint(-5, 5)))
                    device['memory_usage'] = min(100, max(0, device['memory_usage'] + random.randint(-3, 3)))
                    device['temperature'] = min(60, max(20, device['temperature'] + random.randint(-2, 2)))
                    device['uptime'] += 0.1
            
            # Send to all connected clients
            for client in connected_clients:
                try:
                    await client.send_json(mock_devices)
                except Exception as e:
                    logger.error(f"Error sending to client: {e}")
                    # Remove disconnected clients
                    if client in connected_clients:
                        connected_clients.remove(client)
        
        # Wait for 5 seconds before next update
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(broadcast_device_updates())
    logger.info("Started background task for device updates")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080) 