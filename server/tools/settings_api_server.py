#!/usr/bin/env python3
"""
Settings API Server - Handles device settings from frontend dashboard
This server provides a REST API for setting and controlling Android devices via ADB
"""
import os
import sys
import logging
import json
import asyncio
import subprocess
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# Add the parent directory to path to import the modules
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(script_dir)

# Import device control functions
from robust_batch_drono import (
    get_connected_devices,
    prepare_command_args,
    execute_batch_command_parallel,
    execute_batch_command_sequential
)

# Configure logging
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'settings_api.log'))
    ]
)
logger = logging.getLogger('settings_api')

# Create FastAPI app
app = FastAPI(title="Device Settings API", 
              description="API for managing settings on Android devices",
              version="1.0.0")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Data models
class DeviceSettings(BaseModel):
    url: str = Field(..., description="Target URL for the simulation")
    iterations: int = Field(900, description="Number of iterations to run")
    min_interval: int = Field(1, description="Minimum interval between requests (seconds)")
    max_interval: int = Field(2, description="Maximum interval between requests (seconds)")
    delay: int = Field(3000, description="Delay in milliseconds")
    webview_mode: bool = Field(True, description="Use webview mode")
    rotate_ip: bool = Field(True, description="Rotate IP between requests")
    random_devices: bool = Field(True, description="Use random device profiles")
    new_webview_per_request: bool = Field(True, description="Create new webview for each request")
    restore_on_exit: bool = Field(False, description="Restore IP on exit")
    use_proxy: bool = Field(False, description="Use proxy for connections")
    proxy_address: str = Field("", description="Proxy server address")
    proxy_port: int = Field(0, description="Proxy server port")

class BatchCommandRequest(BaseModel):
    settings: DeviceSettings = Field(..., description="Device settings to apply")
    devices: Optional[List[str]] = Field(None, description="List of device IDs to target")
    all_devices: bool = Field(False, description="Target all connected devices")
    parallel: bool = Field(True, description="Run commands in parallel")

class DeviceInfo(BaseModel):
    id: str
    status: str
    model: Optional[str] = None
    
class DeviceInfoList(BaseModel):
    devices: List[DeviceInfo]
    count: int

# API Routes
@app.get("/")
async def root():
    return {"status": "online", "message": "Device Settings API is running"}

@app.get("/devices", response_model=DeviceInfoList)
async def get_devices():
    """Get all connected devices"""
    devices = get_connected_devices()
    
    # Get more info about each device
    device_info = []
    for device_id in devices:
        info = {"id": device_id, "status": "connected"}
        # Try to get device model
        try:
            result = await asyncio.to_thread(
                lambda: subprocess.run(
                    ["adb", "-s", device_id, "shell", "getprop", "ro.product.model"],
                    capture_output=True, text=True, check=False
                )
            )
            if result.returncode == 0:
                info["model"] = result.stdout.strip()
        except Exception:
            pass
        
        device_info.append(DeviceInfo(**info))
    
    return DeviceInfoList(devices=device_info, count=len(device_info))

@app.post("/apply-settings")
async def apply_settings(request: BatchCommandRequest):
    """Apply settings to the specified devices"""
    # Get the devices to target
    if request.all_devices:
        devices = get_connected_devices()
    elif request.devices:
        devices = request.devices
    else:
        raise HTTPException(status_code=400, detail="No devices specified")
    
    if not devices:
        raise HTTPException(status_code=404, detail="No connected devices found")
    
    # Convert settings to command arguments format
    settings_dict = request.settings.dict()
    command_args = prepare_command_args(settings_dict)
    
    # Execute the batch command
    logger.info(f"Applying settings to {len(devices)} devices: {settings_dict}")
    
    # Run in a separate thread to avoid blocking
    if request.parallel:
        results = await asyncio.to_thread(execute_batch_command_parallel, devices, command_args)
    else:
        results = await asyncio.to_thread(execute_batch_command_sequential, devices, command_args)
    
    # Process results
    processed_results = {}
    success_count = 0
    
    for device, (return_code, stdout, stderr) in results.items():
        status = "success" if return_code == 0 else "failure"
        processed_results[device] = {
            "status": status,
            "return_code": return_code,
            "success": return_code == 0,
            "details": stdout if return_code == 0 else stderr
        }
        
        if return_code == 0:
            success_count += 1
    
    # Add summary info
    response = {
        "results": processed_results,
        "summary": {
            "total_devices": len(devices),
            "success_count": success_count,
            "failure_count": len(devices) - success_count,
            "success_rate": round((success_count / len(devices)) * 100, 1)
        }
    }
    
    return response

@app.post("/instagram-settings")
async def apply_instagram_settings(
    url: str = Body(..., embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True),
    parallel: bool = Body(True, embed=True)
):
    """Apply Instagram-specific settings (handles complex URLs)"""
    # Get target devices
    if all_devices:
        target_devices = get_connected_devices()
    elif devices:
        target_devices = devices
    else:
        raise HTTPException(status_code=400, detail="No devices specified")
    
    if not target_devices:
        raise HTTPException(status_code=404, detail="No connected devices found")
    
    # Save URL to file (for compatibility with older scripts)
    instagram_url_file = os.path.join(script_dir, "instagram_url.txt")
    try:
        with open(instagram_url_file, "w") as f:
            f.write(url)
        logger.info(f"Saved Instagram URL to {instagram_url_file}")
    except Exception as e:
        logger.error(f"Failed to save Instagram URL: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to save Instagram URL: {str(e)}")
    
    # Use our direct URL setter script for maximum compatibility
    DIRECT_URL_SETTER = os.path.join(script_dir, "direct_url_setter.sh")
    
    # Verify the script exists and is executable
    if not os.path.isfile(DIRECT_URL_SETTER):
        logger.error(f"Direct URL setter script not found: {DIRECT_URL_SETTER}")
        raise HTTPException(status_code=500, detail="Direct URL setter script not found")
    
    if not os.access(DIRECT_URL_SETTER, os.X_OK):
        try:
            os.chmod(DIRECT_URL_SETTER, 0o755)
            logger.info(f"Made direct URL setter script executable: {DIRECT_URL_SETTER}")
        except Exception as e:
            logger.error(f"Failed to make direct URL setter script executable: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to make direct URL setter script executable: {str(e)}")
    
    # Run the direct URL setter script for each device
    results = {}
    
    async def run_for_device(device_id: str) -> Dict[str, Any]:
        """Run the direct URL setter script for a single device"""
        try:
            logger.info(f"Running direct URL setter for device {device_id} with URL: {url}")
            
            # Run the script
            process = await asyncio.create_subprocess_exec(
                DIRECT_URL_SETTER, device_id, url,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            stdout_text = stdout.decode()
            stderr_text = stderr.decode()
            
            if "SUCCESS" in stdout_text:
                logger.info(f"Successfully set Instagram URL on device {device_id}")
                return {
                    "device_id": device_id,
                    "status": "success",
                    "details": stdout_text[-500:] if len(stdout_text) > 500 else stdout_text
                }
            else:
                error_msg = stderr_text if stderr_text else stdout_text
                # Even if no SUCCESS string found, if exit code is 0, consider it successful with a warning
                if process.returncode == 0:
                    logger.warning(f"Possibly set Instagram URL on device {device_id} (cannot verify): {stdout_text}")
                    return {
                        "device_id": device_id,
                        "status": "possible_success",
                        "details": stdout_text[-500:] if len(stdout_text) > 500 else stdout_text
                    }
                else:
                    logger.error(f"Failed to set Instagram URL on device {device_id}: {error_msg}")
                    return {
                        "device_id": device_id,
                        "status": "error",
                        "details": error_msg[-500:] if len(error_msg) > 500 else error_msg
                    }
                
        except Exception as e:
            logger.error(f"Exception running direct URL setter for device {device_id}: {e}")
            return {
                "device_id": device_id,
                "status": "error",
                "details": str(e)
            }
    
    # Process devices in parallel or sequentially
    if parallel:
        # Parallel execution
        tasks = [run_for_device(device_id) for device_id in target_devices]
        device_results = await asyncio.gather(*tasks)
        
        for result in device_results:
            results[result["device_id"]] = {
                "status": result["status"],
                "details": result["details"]
            }
    else:
        # Sequential execution
        for device_id in target_devices:
            result = await run_for_device(device_id)
            results[result["device_id"]] = {
                "status": result["status"],
                "details": result["details"]
            }
    
    # Calculate success rate (count both success and possible_success)
    success_count = sum(1 for result in results.values() if result["status"] in ["success", "possible_success"])
    
    # Return response with results for each device
    return {
        "status": "success" if success_count == len(target_devices) else "partial_success" if success_count > 0 else "error",
        "devices": target_devices,
        "count": len(target_devices),
        "success_count": success_count,
        "results": results
    }

@app.post("/direct-url")
async def set_direct_url(
    url: str = Body(..., embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True),
    iterations: int = Body(1000, embed=True),
    min_interval: int = Body(1, embed=True),
    max_interval: int = Body(2, embed=True),
    webview_mode: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True),
    random_devices: bool = Body(True, embed=True),
    new_webview_per_request: bool = Body(True, embed=True),
    restore_on_exit: bool = Body(False, embed=True),
    use_proxy: bool = Body(False, embed=True),
    proxy_address: str = Body("", embed=True),
    proxy_port: int = Body(0, embed=True),
    parallel: bool = Body(True, embed=True)
):
    """
    Set URL directly with maximum compatibility
    
    This endpoint uses the simplest and most direct approach to set URLs on devices.
    It's optimized for reliability and is the recommended approach for complex URLs.
    """
    # Get target devices
    if all_devices:
        target_devices = get_connected_devices()
    elif devices:
        target_devices = devices
    else:
        raise HTTPException(status_code=400, detail="No devices specified")
    
    if not target_devices:
        raise HTTPException(status_code=404, detail="No connected devices found")
    
    # Using the direct URL command script for maximum compatibility
    DIRECT_CMD = os.path.join(script_dir, "direct_url_command.sh")
    
    # Verify the script exists and is executable
    if not os.path.isfile(DIRECT_CMD):
        logger.error(f"Direct URL command script not found: {DIRECT_CMD}")
        raise HTTPException(status_code=500, detail="Direct URL command script not found")
    
    if not os.access(DIRECT_CMD, os.X_OK):
        try:
            os.chmod(DIRECT_CMD, 0o755)
            logger.info(f"Made direct URL command script executable: {DIRECT_CMD}")
        except Exception as e:
            logger.error(f"Failed to make direct URL command script executable: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to make direct URL command script executable: {str(e)}")
    
    # Run the command script for each device
    results = {}
    
    async def run_for_device(device_id: str) -> Dict[str, Any]:
        """Run the direct URL command script for a single device"""
        try:
            logger.info(f"Running direct URL command for device {device_id} with URL: {url}")
            
            # Format boolean parameters as 'true' or 'false' for bash script
            webview_str = "true" if webview_mode else "false"
            rotate_ip_str = "true" if rotate_ip else "false"
            random_devices_str = "true" if random_devices else "false"
            new_webview_str = "true" if new_webview_per_request else "false"
            restore_str = "true" if restore_on_exit else "false"
            use_proxy_str = "true" if use_proxy else "false"
            
            # Run the script with all parameters
            process = await asyncio.create_subprocess_exec(
                DIRECT_CMD, device_id, url, 
                str(iterations), str(min_interval), str(max_interval),
                webview_str, rotate_ip_str, random_devices_str, new_webview_str, restore_str,
                use_proxy_str, proxy_address, str(proxy_port),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            stdout_text = stdout.decode()
            stderr_text = stderr.decode()
            
            # Consider success if return code is 0 and app is reported as running
            success = process.returncode == 0 and "App is running" in stdout_text
            
            if success:
                logger.info(f"Successfully set URL on device {device_id}")
                return {
                    "device_id": device_id,
                    "status": "success",
                    "details": stdout_text[-300:] if len(stdout_text) > 300 else stdout_text
                }
            elif process.returncode == 0:
                # Exit code 0 but app might not be running
                logger.warning(f"URL possibly set on device {device_id} but app status uncertain")
                return {
                    "device_id": device_id,
                    "status": "possible_success",
                    "details": stdout_text[-300:] if len(stdout_text) > 300 else stdout_text
                }
            else:
                error_msg = stderr_text if stderr_text else stdout_text
                logger.error(f"Failed to set URL on device {device_id}: {error_msg}")
                return {
                    "device_id": device_id,
                    "status": "error",
                    "details": error_msg[-300:] if len(error_msg) > 300 else error_msg
                }
                
        except Exception as e:
            logger.error(f"Exception running direct URL command for device {device_id}: {e}")
            return {
                "device_id": device_id,
                "status": "error",
                "details": str(e)
            }
    
    # Process devices in parallel or sequentially
    if parallel:
        # Parallel execution
        tasks = [run_for_device(device_id) for device_id in target_devices]
        device_results = await asyncio.gather(*tasks)
        
        for result in device_results:
            results[result["device_id"]] = {
                "status": result["status"],
                "details": result["details"]
            }
    else:
        # Sequential execution
        for device_id in target_devices:
            result = await run_for_device(device_id)
            results[result["device_id"]] = {
                "status": result["status"],
                "details": result["details"]
            }
    
    # Calculate success rate (count both success and possible_success)
    success_count = sum(1 for result in results.values() if result["status"] in ["success", "possible_success"])
    
    # Return response with results for each device
    return {
        "status": "success" if success_count == len(target_devices) else "partial_success" if success_count > 0 else "error",
        "devices": target_devices,
        "count": len(target_devices),
        "success_count": success_count,
        "results": results
    }

# Run the server
if __name__ == "__main__":
    import subprocess
    
    # Check for required modules
    try:
        import fastapi
        import uvicorn
    except ImportError:
        print("Installing required packages...")
        subprocess.run([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn[standard]", "pydantic"], check=True)
    
    # Start the server
    print("Starting Device Settings API server...")
    uvicorn.run("settings_api_server:app", host="0.0.0.0", port=8000, reload=True) 