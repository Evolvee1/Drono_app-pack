import logging
import json
import asyncio
import os
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

from core.adb_controller import adb_controller
from core.websocket_manager import connection_manager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("drono_lite.log")
    ]
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(title="Drono Lite Control Server")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Models for API requests and responses
class DeviceCommandRequest(BaseModel):
    command: str
    parameters: Dict[str, Any] = {}

class BatchCommandRequest(BaseModel):
    command: str
    parameters: Dict[str, Any] = {}
    device_ids: List[str]

class URLDistributionRequest(BaseModel):
    url: str
    device_ids: Optional[List[str]] = None
    iterations: int = 100
    min_interval: int = 1
    max_interval: int = 2

# Background tasks
async def broadcast_status_updates():
    """Background task to periodically send status updates to clients"""
    while True:
        try:
            devices_status = await adb_controller.get_all_devices_status()
            if devices_status:
                await connection_manager.broadcast_all({
                    "type": "status_update",
                    "data": {
                        "devices_status": devices_status,
                        "timestamp": datetime.now().isoformat()
                    }
                })
        except Exception as e:
            logger.error(f"Error in status update broadcast: {e}")
        
        # Wait 2 seconds before next update
        await asyncio.sleep(2)

# Start background task on app startup
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(broadcast_status_updates())

# API endpoints for device management and control
@app.get("/devices")
async def get_devices():
    """Get all connected devices"""
    try:
        devices = adb_controller.get_devices()
        return {"devices": devices, "count": len(devices)}
    except Exception as e:
        logger.error(f"Failed to get devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/devices/status")
async def get_all_devices_status():
    """Get status information for all devices"""
    try:
        devices_status = await adb_controller.get_all_devices_status()
        return {"devices_status": devices_status, "timestamp": datetime.now().isoformat()}
    except Exception as e:
        logger.error(f"Failed to get devices status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/devices/{device_id}/status")
async def get_device_status(device_id: str):
    """Get status information for a specific device"""
    try:
        # Check if device exists
        devices = adb_controller.get_devices()
        device_ids = [d['id'] for d in devices]
        
        if device_id not in device_ids:
            raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
            
        status = adb_controller.get_device_status(device_id)
        return status
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get device status for {device_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/devices/scan")
async def scan_devices():
    """Scan for connected devices"""
    try:
        devices = adb_controller.get_devices()
        # Broadcast device list to all connected WebSocket clients
        await connection_manager.broadcast_all({
            "type": "device_list",
            "data": {
                "devices": devices,
                "count": len(devices)
            }
        })
        return {"devices": devices, "count": len(devices)}
    except Exception as e:
        logger.error(f"Failed to scan devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/devices/{device_id}/command")
async def execute_device_command(device_id: str, command_request: DeviceCommandRequest):
    """Execute a command on a specific device"""
    try:
        # Execute the command
        result = await adb_controller.execute_command(
            device_id, 
            command_request.command, 
            command_request.parameters
        )
        
        # Broadcast command result to WebSocket clients
        await connection_manager.broadcast_all({
            "type": "command_result",
            "data": {
                "device_id": device_id,
                "command": command_request.command,
                "result": result
            }
        })
        
        return result
    except Exception as e:
        logger.error(f"Failed to execute command on device {device_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/devices/batch/command")
async def execute_batch_command(command_request: BatchCommandRequest):
    """Execute a command on multiple devices"""
    results = {}
    
    try:
        # Execute the command on each device
        for device_id in command_request.device_ids:
            result = await adb_controller.execute_command(
                device_id, 
                command_request.command, 
                command_request.parameters
            )
            results[device_id] = result
        
        # Broadcast batch command results
        await connection_manager.broadcast_all({
            "type": "batch_command_result",
            "data": {
                "command": command_request.command,
                "results": results
            }
        })
        
        return {"results": results}
    except Exception as e:
        logger.error(f"Failed to execute batch command: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/distribute-url")
async def distribute_url(request: URLDistributionRequest):
    """Distribute a URL to multiple devices"""
    try:
        # Distribute URL to devices
        results = adb_controller.distribute_url(
            request.device_ids,
            request.url,
            request.iterations,
            request.min_interval,
            request.max_interval
        )
        
        # Broadcast URL distribution results
        await connection_manager.broadcast_all({
            "type": "url_distribution",
            "data": {
                "url": request.url,
                "devices": request.device_ids or [],
                "results": results
            }
        })
        
        return {"results": results}
    except Exception as e:
        logger.error(f"Failed to distribute URL: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# WebSocket endpoints
@app.websocket("/ws/{channel}")
async def websocket_endpoint(websocket: WebSocket, channel: str):
    """WebSocket endpoint for real-time communication"""
    await connection_manager.connect(websocket, channel)
    
    try:
        # Send initial device list
        devices = adb_controller.get_devices()
        await websocket.send_json({
            "type": "device_list",
            "data": {
                "devices": devices,
                "count": len(devices)
            }
        })
        
        # Send initial status information
        try:
            devices_status = await adb_controller.get_all_devices_status()
            await websocket.send_json({
                "type": "status_update",
                "data": {
                    "devices_status": devices_status,
                    "timestamp": datetime.now().isoformat()
                }
            })
        except Exception as e:
            logger.error(f"Failed to send initial status: {e}")
        
        # Listen for messages
        while True:
            # Wait for message from client
            data = await websocket.receive_text()
            
            try:
                # Parse message as JSON
                message = json.loads(data)
                
                # Handle different message types
                if "type" in message:
                    if message["type"] == "scan_devices":
                        # Scan for devices and send results
                        devices = adb_controller.get_devices()
                        await websocket.send_json({
                            "type": "device_list",
                            "data": {
                                "devices": devices,
                                "count": len(devices)
                            }
                        })
                    elif message["type"] == "get_status":
                        # Send status information for all devices
                        devices_status = await adb_controller.get_all_devices_status()
                        await websocket.send_json({
                            "type": "status_update",
                            "data": {
                                "devices_status": devices_status,
                                "timestamp": datetime.now().isoformat()
                            }
                        })
                    elif message["type"] == "get_device_status" and "device_id" in message:
                        # Send status for a specific device
                        device_id = message["device_id"]
                        status = adb_controller.get_device_status(device_id)
                        await websocket.send_json({
                            "type": "device_status",
                            "data": {
                                "device_id": device_id,
                                "status": status,
                                "timestamp": datetime.now().isoformat()
                            }
                        })
                    elif message["type"] == "execute_command" and "device_id" in message and "command" in message:
                        # Execute command on device
                        device_id = message["device_id"]
                        command = message["command"]
                        parameters = message.get("parameters", {})
                        
                        result = await adb_controller.execute_command(device_id, command, parameters)
                        
                        await websocket.send_json({
                            "type": "command_result",
                            "data": {
                                "device_id": device_id,
                                "command": command,
                                "result": result
                            }
                        })
                    elif message["type"] == "distribute_url" and "url" in message:
                        # Distribute URL to devices
                        url = message["url"]
                        device_ids = message.get("device_ids", None)
                        iterations = message.get("iterations", 100)
                        min_interval = message.get("min_interval", 1)
                        max_interval = message.get("max_interval", 2)
                        
                        results = adb_controller.distribute_url(
                            device_ids,
                            url,
                            iterations,
                            min_interval,
                            max_interval
                        )
                        
                        await websocket.send_json({
                            "type": "url_distribution",
                            "data": {
                                "url": url,
                                "devices": device_ids or [],
                                "results": results
                            }
                        })
            except json.JSONDecodeError:
                logger.error(f"Invalid JSON message: {data}")
            except Exception as e:
                logger.error(f"Error handling WebSocket message: {e}")
                await websocket.send_json({
                    "type": "error",
                    "data": {
                        "message": str(e)
                    }
                })
                
    except WebSocketDisconnect:
        connection_manager.disconnect(websocket, channel)
        logger.info(f"Client disconnected from channel: {channel}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        connection_manager.disconnect(websocket, channel)

# Serve dashboard HTML
@app.get("/", response_class=HTMLResponse)
async def get_dashboard():
    """Serve the HTML dashboard"""
    with open(os.path.join("static", "dashboard.html"), "r", encoding="utf-8") as f:
        html_content = f.read()
    return html_content

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 