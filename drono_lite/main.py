import logging
import json
import asyncio
import os
import subprocess
import argparse
import sys
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

from core.adb_controller import adb_controller
from core.websocket_manager import connection_manager

# Only parse arguments when running directly (not via uvicorn)
if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Drono Lite Control Server')
    parser.add_argument('--log-level', type=str, default='INFO',
                       choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                       help='Set the logging level (default: INFO)')
    parser.add_argument('--quiet', action='store_true',
                       help='Suppress ADB controller status messages (equivalent to --log-level=WARNING)')
    args, _ = parser.parse_known_args()
    
    # Set logging level based on arguments
    log_level = logging.WARNING if args.quiet else getattr(logging, args.log_level)
else:
    # Default logging level when run via uvicorn
    log_level = logging.INFO
    # Check if any log level args were passed
    if '--quiet' in sys.argv:
        log_level = logging.WARNING
    for i, arg in enumerate(sys.argv):
        if arg == '--log-level' and i+1 < len(sys.argv):
            try:
                log_level = getattr(logging, sys.argv[i+1])
            except (AttributeError, IndexError):
                pass

# Configure logging
logging.basicConfig(
    level=log_level,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("drono_lite.log")
    ]
)
logger = logging.getLogger(__name__)

# Set specific logger levels
if log_level == logging.WARNING:  # Quiet mode
    logging.getLogger('core.adb_controller').setLevel(logging.WARNING)

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
    delay_min: int = 1
    delay_max: int = 2

# Add new model for logging control
class LoggingConfigRequest(BaseModel):
    level: str = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    target: str = "all"  # 'all', 'adb_controller', or other logger names

# Create a flag to control automatic updates
automatic_updates_enabled = False  # Disabled by default
update_interval = 3600  # 1 hour (3600 seconds) default interval

# Background tasks
async def broadcast_status_updates():
    """Background task to periodically send status updates to clients"""
    global automatic_updates_enabled, update_interval
    last_broadcasted = {}  # Keep track of last sent status for each device
    
    while True:
        try:
            if automatic_updates_enabled:
                devices_status = await adb_controller.get_all_devices_status()
                if devices_status:
                    # Determine which devices have changed status
                    changed_statuses = {}
                    for device_id, status in devices_status.items():
                        # Check if status differs from last broadcast
                        if (device_id not in last_broadcasted or 
                            status != last_broadcasted[device_id]):
                            changed_statuses[device_id] = status
                            last_broadcasted[device_id] = status.copy()  # Store a copy
                    
                    # Only broadcast changes if there are any
                    if changed_statuses:
                        await connection_manager.broadcast_all({
                            "type": "status_update",
                            "data": {
                                "devices_status": changed_statuses,
                                "is_partial": True,
                                "timestamp": datetime.now().isoformat()
                            }
                        })
                        logger.info(f"Broadcast status update for {len(changed_statuses)} changed devices")
        except Exception as e:
            logger.error(f"Error in status update broadcast: {e}")
        
        # Wait for the specified interval before next update
        await asyncio.sleep(update_interval)

# Start background task on app startup
@app.on_event("startup")
async def startup_event():
    """Start background tasks when application starts"""
    # Create broadcast worker task
    asyncio.create_task(connection_manager.start_broadcast_worker())
    
    # Create status update broadcast task
    asyncio.create_task(broadcast_status_updates())
    
    logger.info("Started background tasks for status updates and broadcast worker")

# Add new model for status update configuration
class StatusUpdateConfig(BaseModel):
    automatic: bool = False  # Whether to enable automatic status updates
    interval: int = 900  # Interval in seconds for automatic updates (default: 15 minutes)

# Add endpoint to control status updates
@app.post("/settings/status-updates")
async def configure_status_updates(config: StatusUpdateConfig):
    """Configure automatic status updates"""
    global automatic_updates_enabled, update_interval
    
    # Update global settings
    automatic_updates_enabled = config.automatic
    # Allow intervals from 5 seconds to 1 hour (3600 seconds)
    update_interval = max(5, min(3600, config.interval))
    
    # Broadcast configuration change to all clients
    await connection_manager.broadcast_all({
        "type": "status_update_config",
        "data": {
            "automatic": automatic_updates_enabled,
            "interval": update_interval,
            "timestamp": datetime.now().isoformat()
        }
    })
    
    # Format interval for better readability
    interval_display = ""
    if update_interval >= 3600:
        interval_display = f"{update_interval // 3600} hour(s)"
    elif update_interval >= 60:
        interval_display = f"{update_interval // 60} minute(s)"
    else:
        interval_display = f"{update_interval} seconds"
    
    message = (f"Automatic status updates {'enabled' if automatic_updates_enabled else 'disabled'}, "
               f"interval set to {interval_display}")
    logger.info(message)
    
    return {
        "status": "success",
        "message": message,
        "config": {
            "automatic": automatic_updates_enabled,
            "interval": update_interval
        }
    }

# Add endpoint to get current status update configuration
@app.get("/settings/status-updates")
async def get_status_update_config():
    """Get current status update configuration"""
    return {
        "status": "success",
        "config": {
            "automatic": automatic_updates_enabled,
            "interval": update_interval
        }
    }

# Add endpoint to set extended update interval to reduce device lag
@app.post("/settings/extended-interval/{minutes}")
async def set_extended_update_interval(minutes: int):
    """Set an extended update interval in minutes to reduce device lag"""
    global automatic_updates_enabled, update_interval
    
    # Convert minutes to seconds, minimum 1 minute, maximum 24 hours
    new_interval = max(60, min(24*60*60, minutes * 60))
    update_interval = new_interval
    
    # Disable automatic updates by default
    automatic_updates_enabled = False
    
    # Format for display
    interval_display = ""
    if new_interval >= 3600:
        hours = new_interval // 3600
        minutes = (new_interval % 3600) // 60
        interval_display = f"{hours} hour(s)"
        if minutes > 0:
            interval_display += f" and {minutes} minute(s)"
    else:
        interval_display = f"{new_interval // 60} minute(s)"
    
    message = f"Extended update interval set to {interval_display}, automatic updates disabled"
    logger.info(message)
    
    # Broadcast configuration change to all clients
    await connection_manager.broadcast_all({
        "type": "status_update_config",
        "data": {
            "automatic": automatic_updates_enabled,
            "interval": update_interval,
            "timestamp": datetime.now().isoformat()
        }
    })
    
    return {
        "status": "success",
        "message": message,
        "config": {
            "automatic": automatic_updates_enabled,
            "interval": update_interval
        }
    }

# Add endpoint to manually request status updates
@app.post("/devices/request-status")
async def request_status_update():
    """Manually request status updates for all devices"""
    try:
        # Use full check for manual requests since user is explicitly requesting complete status
        devices_status = await adb_controller.get_all_devices_status()
        
        # Broadcast status update to all clients
        await connection_manager.broadcast_all({
            "type": "status_update",
            "data": {
                "devices_status": devices_status,
                "is_partial": False,  # This is a full update
                "timestamp": datetime.now().isoformat()
            }
        })
        
        return {
            "status": "success",
            "message": f"Status updated for {len(devices_status)} devices"
        }
    except Exception as e:
        logger.error(f"Failed to update status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
    """Get status of all connected devices"""
    try:
        devices_status = await adb_controller.get_all_devices_status()
        return {"devices_status": devices_status}
    except Exception as e:
        logger.error(f"Error getting device status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/devices/{device_id}/timing")
async def get_device_timing(device_id: str):
    """Get detailed timing information from a device"""
    try:
        timing_info = adb_controller.get_device_timing_info(device_id)
        return {
            "device_id": device_id,
            "timing_info": timing_info,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting device timing information: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/devices/{device_id}/status")
async def get_device_status(device_id: str):
    """Get status of a specific device"""
    try:
        # Get status with full check
        status = adb_controller.get_device_status(device_id, full_check=True)
        
        # Add timestamp
        status["timestamp"] = datetime.now().isoformat()
        
        return status
    except Exception as e:
        logger.error(f"Error getting device status: {e}")
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
            request.max_interval,
            delay_min=request.delay_min,
            delay_max=request.delay_max
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
        
        # Check if client wants immediate status updates
        # Extract query parameters from the websocket connection
        query_params = dict(websocket.query_params)
        initial_status = query_params.get("initial_status", "false").lower() == "true"
        
        # Only send initial status if explicitly requested
        if initial_status:
            try:
                logger.info(f"Sending initial status update to new WebSocket client in channel: {channel}")
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
        else:
            logger.info(f"Skipping initial status update for WebSocket client in channel: {channel} (can be requested explicitly)")
        
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
                        # Send status for a specific device with quick check (no full status refresh)
                        device_id = message["device_id"]
                        status = adb_controller.get_device_status(device_id, full_check=False)
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
                        delay_min = message.get("delay_min", 1)
                        delay_max = message.get("delay_max", 2)
                        
                        results = adb_controller.distribute_url(
                            device_ids,
                            url,
                            iterations,
                            min_interval,
                            max_interval,
                            delay_min=delay_min,
                            delay_max=delay_max
                        )
                        
                        await websocket.send_json({
                            "type": "url_distribution",
                            "data": {
                                "url": url,
                                "devices": device_ids or [],
                                "results": results
                            }
                        })
                    elif message["type"] == "configure_logging" and "level" in message:
                        # Configure logging levels
                        level_name = message["level"].upper()
                        target = message.get("target", "all").lower()
                        
                        # Validate level
                        if level_name not in ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]:
                            await websocket.send_json({
                                "type": "error",
                                "data": {
                                    "message": f"Invalid logging level: {level_name}"
                                }
                            })
                            continue
                        
                        # Get log level
                        log_level = getattr(logging, level_name)
                        
                        # Apply logging level
                        if target == "all":
                            logging.getLogger().setLevel(log_level)
                            result_message = f"Set logging level to {level_name} for all loggers"
                        elif target == "adb_controller":
                            logging.getLogger("core.adb_controller").setLevel(log_level)
                            result_message = f"Set logging level to {level_name} for ADB controller"
                        else:
                            logging.getLogger(target).setLevel(log_level)
                            result_message = f"Set logging level to {level_name} for logger: {target}"
                        
                        logger.info(result_message)
                        
                        # Broadcast change to all clients
                        await connection_manager.broadcast_all({
                            "type": "logging_configured",
                            "data": {
                                "level": level_name,
                                "target": target,
                                "message": result_message
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

# Test progress tracking endpoint
@app.get("/test/progress/{device_id}")
async def test_progress_tracking(device_id: str):
    """Test endpoint for progress tracking functionality"""
    try:
        # Check if device exists
        devices = adb_controller.get_devices()
        device_ids = [d['id'] for d in devices]
        
        if device_id not in device_ids:
            raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
        
        # First get device status
        status = adb_controller.get_device_status(device_id)
        
        # Now test all the methods used to get status
        test_results = {
            "device_status": status,
            "prefs_file_test": {
                "exists": False,
                "content": None
            },
            "status_file_test": {
                "exists": False,
                "content": None
            },
            "ui_test": {
                "success": False,
                "content": None
            },
            "logcat_test": {
                "success": False,
                "content": None
            }
        }
        
        # Test prefs file access
        prefs_data = adb_controller._get_prefs_from_device(device_id)
        if prefs_data:
            test_results["prefs_file_test"]["exists"] = True
            test_results["prefs_file_test"]["content"] = prefs_data[:500] + "..." if len(prefs_data) > 500 else prefs_data
        
        # Test status file access
        status_data = adb_controller._get_status_file_from_device(device_id)
        if status_data:
            test_results["status_file_test"]["exists"] = True
            test_results["status_file_test"]["content"] = status_data[:500] + "..." if len(status_data) > 500 else status_data
        
        # Test UI dumpsys
        try:
            ui_dump = subprocess.run(
                ['adb', '-s', device_id, 'shell', "dumpsys activity top | grep -E 'tvProgress|tvIteration'"],
                capture_output=True,
                text=True,
                shell=True,
                timeout=5
            ).stdout
            test_results["ui_test"]["success"] = True
            test_results["ui_test"]["content"] = ui_dump[:500] + "..." if len(ui_dump) > 500 else ui_dump
        except Exception as e:
            test_results["ui_test"]["error"] = str(e)
        
        # Test logcat
        try:
            logcat_output = subprocess.run(
                ['adb', '-s', device_id, 'logcat', '-d', '-t', '20', '-v', 'brief'],
                capture_output=True,
                text=True,
                timeout=5
            ).stdout
            
            # Filter the output to find relevant lines
            relevant_lines = []
            for line in logcat_output.splitlines():
                if adb_controller.package in line and ("Progress:" in line or "Iteration:" in line):
                    relevant_lines.append(line)
            
            test_results["logcat_test"]["success"] = True
            test_results["logcat_test"]["content"] = "\n".join(relevant_lines)
            if not relevant_lines:
                test_results["logcat_test"]["content"] = "No progress updates found in logcat"
        except Exception as e:
            test_results["logcat_test"]["error"] = str(e)
            
        return test_results
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to test progress tracking for {device_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Add new API endpoint for controlling logging
@app.post("/logging/configure")
async def configure_logging(config: LoggingConfigRequest):
    """Dynamically configure logging levels"""
    try:
        # Validate the logging level
        level_name = config.level.upper()
        if level_name not in ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]:
            raise HTTPException(status_code=400, detail=f"Invalid logging level: {level_name}")
        
        # Convert string level to logging level
        log_level = getattr(logging, level_name)
        
        # Apply the logging level
        if config.target.lower() == "all":
            # Set level for root logger
            logging.getLogger().setLevel(log_level)
            message = f"Set logging level to {level_name} for all loggers"
        elif config.target.lower() == "adb_controller":
            # Set level specifically for ADB controller
            logging.getLogger("core.adb_controller").setLevel(log_level)
            message = f"Set logging level to {level_name} for ADB controller"
        else:
            # Set level for specific logger
            logging.getLogger(config.target).setLevel(log_level)
            message = f"Set logging level to {level_name} for logger: {config.target}"
        
        logger.info(message)
        
        # Broadcast logging change to WebSocket clients
        await connection_manager.broadcast_all({
            "type": "logging_configured",
            "data": {
                "level": level_name,
                "target": config.target,
                "message": message
            }
        })
        
        return {"status": "success", "message": message}
    except Exception as e:
        logger.error(f"Failed to configure logging: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Add endpoint to get current logging configuration
@app.get("/logging/status")
async def get_logging_status():
    """Get current logging configuration"""
    try:
        # Get logging levels of important loggers
        root_level = logging.getLogger().level
        adb_level = logging.getLogger("core.adb_controller").level
        app_level = logging.getLogger(__name__).level
        
        # Convert logging levels to names
        level_names = {
            logging.DEBUG: "DEBUG",
            logging.INFO: "INFO",
            logging.WARNING: "WARNING",
            logging.ERROR: "ERROR",
            logging.CRITICAL: "CRITICAL"
        }
        
        status = {
            "root": level_names.get(root_level, str(root_level)),
            "adb_controller": level_names.get(adb_level, str(adb_level)),
            "app": level_names.get(app_level, str(app_level))
        }
        
        return {"status": "success", "config": status}
    except Exception as e:
        logger.error(f"Failed to get logging status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True) 