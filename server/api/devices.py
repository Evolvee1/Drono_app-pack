from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import asyncio
import json
import logging
from datetime import datetime
import re
import time

from api.auth import User, get_current_active_user
from core.device_manager import DeviceManager
from core.command_executor import CommandExecutor

router = APIRouter()
logger = logging.getLogger(__name__)

# Create a device_manager_instance that will be properly initialized in main.py
device_manager = None

# Store active WebSocket connections
active_connections = []

# Add rate limiting for status updates
last_status_update = {}
STATUS_UPDATE_INTERVAL = 2.0  # Minimum seconds between status updates per device

# Create command executor instance for status checks
command_executor = CommandExecutor()

class DeviceResponse(BaseModel):
    id: str
    model: str
    status: str
    running: bool
    last_command_status: Optional[str] = None
    last_updated: Optional[str] = None

class DeviceListResponse(BaseModel):
    devices: List[DeviceResponse]
    count: int

class DevicePropertiesResponse(BaseModel):
    id: str
    model: str
    properties: Dict[str, str]

# Store the status update task
status_update_task = None

async def get_device_status(device_id: str):
    """Get detailed status of a device with simulation info"""
    try:
        device = await device_manager.get_device(device_id)
        if not device:
            return None
        
        # Get simulation status through command executor
        result = await command_executor.get_status(device_id)
        
        # Extract simulation info from result if available
        simulation_info = {}
        if result.success:
            # Basic extraction of info from output text
            output = result.output
            
            # Check if simulation is running
            is_running = "SIMULATION IS RUNNING" in output
            device.running = is_running
            simulation_info["is_running"] = is_running
            device.last_updated = datetime.now().isoformat()
            
            # Extract URL if present
            url_match = output.find("URL: ")
            if url_match != -1:
                url_end = output.find("\n", url_match)
                if url_end != -1:
                    simulation_info["url"] = output[url_match+5:url_end].strip()
            
            # Extract iterations if present
            iterations_match = output.find("Iterations: ")
            if iterations_match != -1:
                iterations_end = output.find("\n", iterations_match)
                if iterations_end != -1:
                    try:
                        iterations_str = output[iterations_match+12:iterations_end].strip()
                        simulation_info["iterations"] = int(iterations_str)
                    except ValueError:
                        pass
            
            # Extract current iteration if present
            current_iteration_match = output.find("Current Iteration: ")
            if current_iteration_match != -1:
                current_iteration_end = output.find("\n", current_iteration_match)
                if current_iteration_end != -1:
                    try:
                        current_iteration_str = output[current_iteration_match+19:current_iteration_end].strip()
                        if current_iteration_str and current_iteration_str.isdigit():
                            simulation_info["current_iteration"] = int(current_iteration_str)
                    except ValueError:
                        pass
            
            # Look for "Progress: X/Y" pattern in the output
            if "current_iteration" not in simulation_info:
                progress_match = re.search(r"Progress:\s*(\d+)/(\d+)", output)
                if progress_match:
                    try:
                        current = int(progress_match.group(1))
                        total = int(progress_match.group(2))
                        simulation_info["current_iteration"] = current
                        if "iterations" not in simulation_info:
                            simulation_info["iterations"] = total
                    except ValueError:
                        pass
            
            # Check for iteration updates in log section
            if "current_iteration" not in simulation_info and "RECENT LOG ACTIVITY" in output:
                log_section_start = output.find("RECENT LOG ACTIVITY")
                if log_section_start != -1:
                    log_section = output[log_section_start:]
                    
                    # Look for iteration pattern in logs (e.g. "iteration 50/100")
                    iteration_match = re.search(r"[Ii]teration\s+(\d+)/(\d+)", log_section)
                    if iteration_match:
                        try:
                            current = int(iteration_match.group(1))
                            total = int(iteration_match.group(2))
                            simulation_info["current_iteration"] = current
                            if "iterations" not in simulation_info:
                                simulation_info["iterations"] = total
                        except ValueError:
                            pass
            
            # If still no current_iteration found, try to get it directly from logcat
            if "current_iteration" not in simulation_info and is_running:
                try:
                    # Execute a direct logcat command to check for recent iterations
                    from core.adb_controller import AdbController
                    adb = AdbController()
                    
                    # Try to get the current iteration from logcat
                    logcat_output = await adb.execute_adb_command(
                        device_id, 
                        ["logcat", "-d", "-t", "30", "-e", "Processing iteration|Progress:", "--regex"]
                    )
                    
                    # Look for patterns like "Processing iteration 5 of 100" or "Progress: 5/100"
                    iter_matches = re.findall(r"Processing iteration (\d+) of (\d+)", logcat_output)
                    if iter_matches:
                        current = int(iter_matches[-1][0])  # Get the most recent match
                        total = int(iter_matches[-1][1])
                        simulation_info["current_iteration"] = current
                        if "iterations" not in simulation_info:
                            simulation_info["iterations"] = total
                    else:
                        # Try Progress pattern
                        progress_matches = re.findall(r"Progress: (\d+)/(\d+)", logcat_output)
                        if progress_matches:
                            current = int(progress_matches[-1][0])  # Get the most recent match
                            total = int(progress_matches[-1][1])
                            simulation_info["current_iteration"] = current
                            if "iterations" not in simulation_info:
                                simulation_info["iterations"] = total
                except Exception as e:
                    logger.error(f"Error getting iteration from logcat: {e}")
            
            # If still no current_iteration found, try to get it from UI elements
            if "current_iteration" not in simulation_info and is_running:
                try:
                    # Execute a UI dump to look for progress elements
                    from core.adb_controller import AdbController
                    adb = AdbController()
                    
                    # Try to get the current iteration from UI elements
                    ui_output = await adb.execute_adb_command(
                        device_id, 
                        ["shell", "dumpsys", "activity", "top"]
                    )
                    
                    # Look for TextView with progress information
                    tv_progress_matches = re.findall(r"tvProgress.*?text=(?:Progress: )?(\d+)/(\d+)", ui_output)
                    if tv_progress_matches:
                        current = int(tv_progress_matches[0][0])
                        total = int(tv_progress_matches[0][1])
                        simulation_info["current_iteration"] = current
                        if "iterations" not in simulation_info:
                            simulation_info["iterations"] = total
                    
                    # Check other TextView that might contain progress
                    if "current_iteration" not in simulation_info:
                        other_progress = re.findall(r"TextView.*?text=(?:Progress: )?(\d+)/(\d+)", ui_output)
                        if other_progress:
                            current = int(other_progress[0][0])
                            total = int(other_progress[0][1])
                            simulation_info["current_iteration"] = current
                            if "iterations" not in simulation_info:
                                simulation_info["iterations"] = total
                except Exception as e:
                    logger.error(f"Error getting iteration from UI: {e}")
            
            # As a last resort, if simulation is running but progress is still not found,
            # try to directly execute a special command to get just the progress
            if "current_iteration" not in simulation_info and is_running:
                try:
                    direct_progress = await command_executor.execute_command(
                        device_id, 
                        "custom", 
                        {"command": "shell", "arg": "dumpsys activity top | grep -o 'Progress: [0-9]*/[0-9]*'"}
                    )
                    if direct_progress.success and direct_progress.output:
                        progress_match = re.search(r"Progress:\s*(\d+)/(\d+)", direct_progress.output)
                        if progress_match:
                            current = int(progress_match.group(1))
                            total = int(progress_match.group(2))
                            simulation_info["current_iteration"] = current
                            if "iterations" not in simulation_info:
                                simulation_info["iterations"] = total
                except Exception as e:
                    logger.error(f"Error getting direct progress: {e}")
            
            # If we have iterations but no current_iteration, provide a default
            if "iterations" in simulation_info and "current_iteration" not in simulation_info and is_running:
                # Check if we can get the current iteration from device properties
                if hasattr(device, 'current_iteration') and device.current_iteration:
                    simulation_info["current_iteration"] = device.current_iteration
                else:
                    # Set a default value of 1 if running but no specific iteration found
                    simulation_info["current_iteration"] = 1
        
        # Store the current iteration in the device for next time
        if "current_iteration" in simulation_info:
            device.current_iteration = simulation_info["current_iteration"]
        
        return {
            "device": device.to_dict(),
            "simulation": simulation_info
        }
    except Exception as e:
        logger.error(f"Error getting device status: {e}")
        return None

async def get_device_progress_from_logcat(device_id: str):
    """Get device progress directly from logcat"""
    try:
        # Direct shell command to get progress from logcat
        from core.command_executor import CommandExecutor
        command_executor = CommandExecutor()
        
        # Use a direct shell command to get progress from logcat
        result = await command_executor.execute_command(
            device_id,
            "custom",
            {"command": "shell", "arg": "logcat -d | grep 'Progress:' | tail -1"}
        )
        
        if result.success and result.output:
            # Look for patterns like "Progress: 25/1000"
            match = re.search(r"Progress: (\d+)/(\d+)", result.output)
            if match:
                current = int(match.group(1))
                total = int(match.group(2))
                
                # Update the device's current_iteration
                device = await device_manager.get_device(device_id)
                if device:
                    device.current_iteration = current
                    device.last_updated = datetime.now().isoformat()
                    logger.info(f"Updated progress for {device_id} from logcat: {current}/{total}")
                    
                    return {
                        "current_iteration": current,
                        "iterations": total,
                        "is_running": True
                    }
    except Exception as e:
        logger.error(f"Error getting progress from logcat: {e}")
    
    return None

async def status_update_loop():
    """Periodically check status of all devices and send updates to WebSocket clients"""
    try:
        while True:
            if not active_connections:
                await asyncio.sleep(1)
                continue
                
            # Get all devices
            devices = await device_manager.get_all_devices()
            
            # For each device, get status and send to all connected clients
            for device in devices:
                # First try to get progress from logcat for faster updates
                if device.running:
                    progress_info = await get_device_progress_from_logcat(device.id)
                    if progress_info:
                        # Create a combined status with just the progress info
                        status = {
                            "device": device.to_dict(),
                            "simulation": progress_info
                        }
                        
                        # Send to all active connections
                        await send_status_to_connections(status)
                    
                # Get full status every 5 seconds (less frequently)
                if time.time() % 5 < 1:  # Only do this approximately once every 5 seconds
                    status = await get_device_status(device.id)
                    if status:
                        # Send to all active connections
                        await send_status_to_connections(status)
            
            # Wait before next update
            await asyncio.sleep(1)  # Check every 1 second for progress updates
    except asyncio.CancelledError:
        logger.info("Status update loop cancelled")
    except Exception as e:
        logger.error(f"Error in status update loop: {e}")

async def send_status_to_connections(status):
    """Send status to all active connections"""
    if not status:
        return
        
    disconnected = []
    for connection in active_connections:
        try:
            await connection.send_json(status)
        except RuntimeError:
            # Connection probably closed
            disconnected.append(connection)
        except Exception as e:
            logger.error(f"Error sending to WebSocket: {e}")
            disconnected.append(connection)
    
    # Remove disconnected clients
    for connection in disconnected:
        if connection in active_connections:
            active_connections.remove(connection)

@router.get("/", response_model=DeviceListResponse)
async def get_all_devices(current_user: User = Depends(get_current_active_user)):
    """Get a list of all connected devices"""
    devices = await device_manager.get_all_devices()
    device_list = [DeviceResponse(**device.to_dict()) for device in devices]
    return DeviceListResponse(devices=device_list, count=len(device_list))

@router.get("/scan", response_model=DeviceListResponse)
async def scan_devices(current_user: User = Depends(get_current_active_user)):
    """Force a scan for new devices"""
    devices = await device_manager.scan_devices()
    device_list = [DeviceResponse(**device.to_dict()) for device in devices]
    return DeviceListResponse(devices=device_list, count=len(device_list))

@router.get("/{device_id}", response_model=DeviceResponse)
async def get_device(device_id: str, current_user: User = Depends(get_current_active_user)):
    """Get details for a specific device"""
    device = await device_manager.get_device(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {device_id} not found"
        )
    return DeviceResponse(**device.to_dict())

@router.get("/{device_id}/status")
async def get_device_status_endpoint(device_id: str, current_user: User = Depends(get_current_active_user)):
    """Get detailed status for a specific device including simulation info"""
    device = await device_manager.get_device(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {device_id} not found"
        )
    
    status = await get_device_status(device_id)
    if not status:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get status for device {device_id}"
        )
    
    return status

@router.get("/{device_id}/properties", response_model=DevicePropertiesResponse)
async def get_device_properties(device_id: str, current_user: User = Depends(get_current_active_user)):
    """Get detailed properties for a specific device"""
    device = await device_manager.get_device(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {device_id} not found"
        )
    
    # Get properties using ADB controller
    from core.adb_controller import AdbController
    adb = AdbController()
    properties = await adb.get_device_properties(device_id)
    
    return DevicePropertiesResponse(
        id=device.id,
        model=device.model,
        properties=properties
    )

@router.post("/{device_id}/reboot")
async def reboot_device(device_id: str, current_user: User = Depends(get_current_active_user)):
    """Reboot a specific device"""
    device = await device_manager.get_device(device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {device_id} not found"
        )
    
    from core.adb_controller import AdbController
    adb = AdbController()
    success = await adb.reboot_device(device_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to reboot device {device_id}"
        )
    
    return {"status": "success", "message": f"Device {device_id} is rebooting"}

# Pre-flight CORS request handling for WebSocket
@router.options("/ws")
async def websocket_cors(request: Request):
    response = JSONResponse(content={})
    origin = request.headers.get("origin", "")
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type"
    response.headers["Access-Control-Max-Age"] = "3600"
    return response

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time device status updates"""
    # Manually handle CORS for WebSocket
    origin = websocket.headers.get("origin", "")
    try:
        # Accept connection with CORS headers
        await websocket.accept()
        
        # Add to active connections
        active_connections.append(websocket)
        logger.info(f"New WebSocket connection established. Total connections: {len(active_connections)}")
        
        # Start status update task if not already running
        global status_update_task
        if status_update_task is None or status_update_task.done():
            status_update_task = asyncio.create_task(status_update_loop())
            logger.info("Started status update loop")
        
        # Send initial list of devices
        devices = await device_manager.get_all_devices()
        await websocket.send_json({
            "type": "initial_devices",
            "devices": [device.to_dict() for device in devices]
        })
        logger.info(f"Sent initial device list with {len(devices)} devices")
        
        # Wait for messages (can be used for authentication or filtering)
        while True:
            try:
                data = await websocket.receive_text()
                try:
                    message = json.loads(data)
                    # Handle message types if needed
                    if message.get("type") == "request_status" and "device_id" in message:
                        # Check rate limiting
                        device_id = message["device_id"]
                        current_time = time.time()
                        if device_id in last_status_update:
                            time_since_last = current_time - last_status_update[device_id]
                            if time_since_last < STATUS_UPDATE_INTERVAL:
                                await asyncio.sleep(STATUS_UPDATE_INTERVAL - time_since_last)
                        
                        # Send immediate status update for a specific device
                        status = await get_device_status(device_id)
                        if status:
                            await websocket.send_json(status)
                            last_status_update[device_id] = time.time()
                            logger.info(f"Sent requested status for device {device_id}")
                except json.JSONDecodeError:
                    logger.warning(f"Received invalid JSON: {data}")
            except WebSocketDisconnect:
                logger.info("WebSocket disconnected during receive")
                break
    except WebSocketDisconnect:
        logger.info("WebSocket disconnected during handshake")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        # Clean up
        if websocket in active_connections:
            active_connections.remove(websocket)
            logger.info(f"WebSocket connection removed. Remaining connections: {len(active_connections)}")
