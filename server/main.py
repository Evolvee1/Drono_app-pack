from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
import logging
import os
import json
import time
import asyncio
from dotenv import load_dotenv
from contextlib import asynccontextmanager
from typing import Optional, Dict, Any, List
from datetime import datetime
import uuid
from pydantic import BaseModel
from fastapi.responses import Response

from models.database_models import Device, Simulation, Command, DeviceStatus
from core.command_executor import command_executor
from core.alerting import alert_manager
from core.websocket_manager import websocket_manager
from core.monitoring import device_monitor, simulation_monitor
from core.adb_controller import adb_controller
from core.device_manager import DeviceManager
from core.loop_utils import loop_manager
# Import Instagram routes
from api.instagram_routes import router as instagram_router

# Create an instance of DeviceManager
device_manager = DeviceManager()

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for FastAPI app"""
    # Ensure we're using a consistent event loop
    loop = loop_manager.get_loop()
    
    # Startup
    logger.info("Starting up services...")
    try:
        # Start services in order
        await alert_manager.start()
        await websocket_manager.start()
        await device_monitor.start()
        await simulation_monitor.start()
        await device_manager.initialize()
        logger.info("All services started successfully")
        yield
    except Exception as e:
        logger.error(f"Error during startup: {e}")
        raise
    finally:
        # Shutdown
        logger.info("Shutting down services...")
        try:
            await device_manager.shutdown()
            await alert_manager.stop()
            await websocket_manager.stop()
            await device_monitor.stop()
            await simulation_monitor.stop()
            logger.info("All services stopped successfully")
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")

# Custom JSON encoder to handle datetime serialization
class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)

# Create FastAPI app
app = FastAPI(title="Drono Control Server", lifespan=lifespan)

# Include Instagram routes
app.include_router(instagram_router)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Auth endpoints
@app.post("/auth/token")
async def get_token(username: str, password: str):
    """Get authentication token"""
    logger.info(f"Token request for user: {username}")
    # For now, just return a dummy token
    return {"token": "dummy_token"}

# Device endpoints
@app.get("/devices", response_model=list[Device])
async def get_devices():
    """Get all devices"""
    try:
        logger.info("Getting all devices")
        devices = adb_controller.get_devices()
        for device in devices:
            device_monitor.register_device(Device(**device))
        logger.info(f"Found {len(devices)} devices")
        
        # Convert to JSON and back with CustomJSONEncoder to handle datetime serialization
        devices_json = json.dumps(devices, cls=CustomJSONEncoder)
        return json.loads(devices_json)
    except Exception as e:
        logger.error(f"Failed to get devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/devices/{device_id}/status")
async def get_device_status(device_id: str):
    """Get device status"""
    try:
        logger.info(f"Getting status for device: {device_id}")
        # Get device status from ADB controller
        devices = adb_controller.get_devices()
        device = next((d for d in devices if d['id'] == device_id), None)
        
        if not device:
            logger.warning(f"Device {device_id} not found")
            raise HTTPException(
                status_code=404,
                detail=f"Device {device_id} not found"
            )
            
        logger.info(f"Device {device_id} status: {device}")
        return device
    except Exception as e:
        logger.error(f"Failed to get device status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/devices/scan")
async def scan_devices():
    """Scan for connected devices"""
    try:
        logger.info("Scanning for devices")
        devices = adb_controller.get_devices()
        for device in devices:
            device_monitor.register_device(Device(**device))
        logger.info(f"Scan completed, found {len(devices)} devices")
        return {"message": "Device scan completed", "devices": devices}
    except Exception as e:
        logger.error(f"Failed to scan devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Define a simpler device command request model
class DeviceCommandRequest(BaseModel):
    command: str
    parameters: Dict[str, Any] = {}
    dryrun: bool = False

# Define a model for batch commands to multiple devices
class BatchCommandRequest(BaseModel):
    command: str
    parameters: Dict[str, Any] = {}
    device_ids: List[str]
    dryrun: bool = False

# Simple device command endpoint (easier for Flutter app to use)
@app.post("/api/devices/{device_id}/command", response_model=dict)
async def execute_device_command(device_id: str, command_request: DeviceCommandRequest):
    """Execute a simple command on a device"""
    try:
        logger.info(f"Executing {command_request.command} on device {device_id}")
        
        # Create a new command object
        command = Command(
            id=str(uuid.uuid4()),
            device_id=device_id,
            type=command_request.command,
            parameters=command_request.parameters,
            status="pending",
            created_at=datetime.now()
        )
        
        # Execute the command
        if command_request.dryrun:
            logger.info(f"DRY RUN: Would execute {command.type} on device {device_id}")
            response_data = {
                "success": True,
                "message": f"Dry run: {command.type} command would be executed",
                "command_id": command.id,
                "timestamp": datetime.now().isoformat()
            }
            return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))
        
        # If command is 'start', we need to format parameters for the drono_control.sh script
        if command.type == "start":
            # Prepare parameters for the script
            script_params = {}
            
            # Copy basic parameters
            if "url" in command.parameters:
                script_params["url"] = command.parameters["url"]
            if "iterations" in command.parameters:
                script_params["iterations"] = command.parameters["iterations"]
            if "min_interval" in command.parameters:
                script_params["min_interval"] = command.parameters["min_interval"]
            if "max_interval" in command.parameters:
                script_params["max_interval"] = command.parameters["max_interval"]
                
            # Handle boolean toggles - these need to be passed properly to command_executor
            # to be formatted as "toggle feature true/false"
            for toggle_feature in ["webview_mode", "rotate_ip", "random_devices", "aggressive_clearing"]:
                if toggle_feature in command.parameters:
                    script_params[toggle_feature] = command.parameters[toggle_feature]
                    
            # Handle dismiss_restore flag
            if "dismiss_restore" in command.parameters and command.parameters["dismiss_restore"]:
                script_params["dismiss_restore"] = True
                    
            # Set command parameters to the script-compatible format
            command.parameters = script_params
        
        # For real execution
        result = await command_executor.execute_command(command)
        
        if result:
            logger.info(f"Command {command.type} executed successfully on device {device_id}")
            response_data = {
                "success": True, 
                "message": f"Command {command.type} executed successfully",
                "command_id": command.id,
                "timestamp": datetime.now().isoformat()
            }
            return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))
        else:
            logger.error(f"Command {command.type} execution failed on device {device_id}")
            response_data = {
                "success": False,
                "message": f"Command {command.type} execution failed",
                "command_id": command.id,
                "timestamp": datetime.now().isoformat()
            }
            return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))
    except Exception as e:
        logger.error(f"Failed to execute command: {e}")
        response_data = {
            "success": False,
            "message": f"Error: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }
        return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))

# Batch command endpoint for sending commands to multiple devices
@app.post("/api/devices/batch/command", response_model=dict)
async def execute_batch_command(batch_request: BatchCommandRequest):
    """Execute the same command on multiple devices"""
    try:
        logger.info(f"Executing batch {batch_request.command} on {len(batch_request.device_ids)} devices")
        
        results = {}
        for device_id in batch_request.device_ids:
            # Check if device exists
            device = await device_manager.get_device(device_id)
            if not device:
                results[device_id] = {
                    "success": False,
                    "message": f"Device with ID {device_id} not found",
                    "timestamp": datetime.now().isoformat()
                }
                continue
                
            # Create a command object for this device
            command = Command(
                id=str(uuid.uuid4()),
                device_id=device_id,
                type=batch_request.command,
                parameters=batch_request.parameters,
                status="pending",
                created_at=datetime.now()
            )
            
            # Process command parameters the same way as in single-device command
            if command.type == "start" and not batch_request.dryrun:
                # Prepare parameters for the script
                script_params = {}
                
                # Copy basic parameters
                if "url" in command.parameters:
                    script_params["url"] = command.parameters["url"]
                if "iterations" in command.parameters:
                    script_params["iterations"] = command.parameters["iterations"]
                if "min_interval" in command.parameters:
                    script_params["min_interval"] = command.parameters["min_interval"]
                if "max_interval" in command.parameters:
                    script_params["max_interval"] = command.parameters["max_interval"]
                    
                # Handle boolean toggles
                for toggle_feature in ["webview_mode", "rotate_ip", "random_devices", "aggressive_clearing"]:
                    if toggle_feature in command.parameters:
                        script_params[toggle_feature] = command.parameters[toggle_feature]
                        
                # Handle dismiss_restore flag
                if "dismiss_restore" in command.parameters and command.parameters["dismiss_restore"]:
                    script_params["dismiss_restore"] = True
                        
                # Set command parameters to the script-compatible format
                command.parameters = script_params
            
            # Execute or simulate the command
            if batch_request.dryrun:
                logger.info(f"DRY RUN: Would execute {command.type} on device {device_id}")
                results[device_id] = {
                    "success": True,
                    "message": f"Dry run: {command.type} command would be executed",
                    "command_id": command.id,
                    "timestamp": datetime.now().isoformat()
                }
            else:
                # Execute the command
                result = await command_executor.execute_command(command)
                
                if result:
                    logger.info(f"Command {command.type} executed successfully on device {device_id}")
                    results[device_id] = {
                        "success": True, 
                        "message": f"Command {command.type} executed successfully",
                        "command_id": command.id,
                        "timestamp": datetime.now().isoformat()
                    }
                else:
                    logger.error(f"Command {command.type} execution failed on device {device_id}")
                    results[device_id] = {
                        "success": False,
                        "message": f"Command {command.type} execution failed",
                        "command_id": command.id,
                        "timestamp": datetime.now().isoformat()
                    }
        
        # Create a summary response
        success_count = sum(1 for r in results.values() if r.get("success", False))
        
        response_data = {
            "success": success_count > 0,
            "message": f"Executed {batch_request.command} on {success_count} of {len(batch_request.device_ids)} devices",
            "results": results,
            "timestamp": datetime.now().isoformat()
        }
        
        return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))
    except Exception as e:
        logger.error(f"Failed to execute batch command: {e}")
        response_data = {
            "success": False,
            "message": f"Error: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }
        return json.loads(json.dumps(response_data, cls=CustomJSONEncoder))

# WebSocket endpoints
@app.websocket("/devices/ws")
async def devices_websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for device updates"""
    try:
        logger.info("New WebSocket connection request for devices channel")
        # Connection will be accepted in websocket_manager.connect
        await websocket_manager.connect(websocket, "devices")
        logger.info("WebSocket connection established for devices channel")
        try:
            while True:
                data = await websocket.receive_text()
                logger.debug(f"Received WebSocket message: {data}")
                # Handle incoming messages if needed
        except WebSocketDisconnect:
            logger.info("Devices WebSocket disconnected")
            await websocket_manager.disconnect(websocket, "devices")
    except Exception as e:
        logger.error(f"Devices WebSocket error: {e}")
        try:
            await websocket.close()
        except:
            pass

@app.websocket("/ws/{channel}")
async def websocket_endpoint(websocket: WebSocket, channel: str):
    """WebSocket endpoint for real-time updates"""
    try:
        logger.info(f"New WebSocket connection request for channel: {channel}")
        # Connection will be accepted in websocket_manager.connect
        await websocket_manager.connect(websocket, channel)
        logger.info(f"WebSocket connection established for channel: {channel}")
        try:
            while True:
                data = await websocket.receive_text()
                logger.debug(f"Received WebSocket message on channel {channel}: {data}")
                # Process received message if needed
                try:
                    message = json.loads(data)
                    if "type" in message and "data" in message:
                        if message["type"] == "ping":
                            # Respond to ping with pong
                            await websocket.send_text(json.dumps({"type": "pong", "data": {"timestamp": time.time()}}))
                except json.JSONDecodeError:
                    logger.warning(f"Received invalid JSON on channel {channel}: {data}")
                except Exception as e:
                    logger.error(f"Error processing WebSocket message: {e}")
        except WebSocketDisconnect:
            logger.info(f"WebSocket disconnected from channel: {channel}")
            await websocket_manager.disconnect(websocket, channel)
    except Exception as e:
        logger.error(f"WebSocket error on channel {channel}: {e}")
        try:
            await websocket.close()
        except:
            pass

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        logger.info("Health check requested")
        return {
            "status": "healthy",
            "services": {
                "alert_manager": "running",
                "websocket_manager": "running",
                "device_monitor": "running",
                "simulation_monitor": "running"
            }
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Error handlers
@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle general exceptions"""
    logger.error(f"Unexpected error: {exc}")
    await alert_manager.send_alert(
        "error",
        f"Unexpected error: {str(exc)}",
        None
    )
    return {"detail": "Internal server error"}

# Import routers
from api.devices import router as devices_router
from api.commands import router as commands_router
from api.auth import router as auth_router
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pathlib import Path
import uvicorn

# Server configuration
SERVER_HOST = os.getenv("SERVER_HOST", "0.0.0.0")
SERVER_PORT = int(os.getenv("SERVER_PORT", "8000"))
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# Mount routers
app.include_router(auth_router, prefix="/auth", tags=["Authentication"])
app.include_router(devices_router, prefix="/devices", tags=["Devices"])
app.include_router(commands_router, prefix="/commands", tags=["Commands"])

# Mount static files for demo UI
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
    
    # Root route for Drono UI
    @app.get("/")
    async def root():
        return FileResponse(str(static_dir / "index.html"))
else:
    # Fallback health check endpoint
    @app.get("/")
    async def root():
        return {"status": "ok", "version": "1.0.0"}

if __name__ == "__main__":
    logger.info(f"Starting server on {SERVER_HOST}:{SERVER_PORT}")
    uvicorn.run("main:app", host=SERVER_HOST, port=SERVER_PORT, reload=DEBUG)