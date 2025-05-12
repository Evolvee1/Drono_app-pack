#!/usr/bin/env python3
"""
Improved Settings API Server - Handles device settings with greater reliability
This server provides a REST API for setting and controlling Android devices via ADB
"""
import os
import sys
import logging
import json
import asyncio
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

# Add the parent directory to path to import the modules
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(script_dir)

# Import the unified command API
from unified_command_api import set_url_on_devices, get_connected_devices

# Configure logging
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'improved_settings_api.log'))
    ]
)
logger = logging.getLogger('improved_settings_api')

# Create FastAPI app
app = FastAPI(title="Improved Device Settings API", 
              description="API for reliably managing settings on Android devices",
              version="2.0.0")

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
    iterations: int = Field(1000, description="Number of iterations to run")
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
    return {"status": "online", "message": "Improved Device Settings API is running"}

@app.get("/devices", response_model=DeviceInfoList)
async def list_devices():
    """Get all connected devices"""
    try:
        devices = await get_connected_devices()
        
        device_info = []
        for device in devices:
            info = {
                "id": device["id"],
                "status": device["status"],
                "model": device.get("model", "Unknown")
            }
            device_info.append(DeviceInfo(**info))
        
        return DeviceInfoList(devices=device_info, count=len(device_info))
    except Exception as e:
        logger.error(f"Failed to get devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/set-url")
async def set_url(
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
    Set URL on devices with maximum reliability
    """
    try:
        # Get the devices to target
        if all_devices:
            device_list = await get_connected_devices()
            target_devices = [device["id"] for device in device_list]
        elif devices:
            target_devices = devices
        else:
            raise HTTPException(status_code=400, detail="No devices specified")
        
        if not target_devices:
            raise HTTPException(status_code=404, detail="No connected devices found")
        
        # Log the operation
        logger.info(f"Setting URL on {len(target_devices)} devices: {url}")
        
        # Set URL on devices
        result = await set_url_on_devices(
            url=url,
            device_ids=target_devices,
            parallel=parallel,
            iterations=iterations,
            min_interval=min_interval,
            max_interval=max_interval,
            webview_mode=webview_mode,
            rotate_ip=rotate_ip,
            random_devices=random_devices,
            new_webview_per_request=new_webview_per_request,
            restore_on_exit=restore_on_exit,
            use_proxy=use_proxy,
            proxy_address=proxy_address,
            proxy_port=proxy_port
        )
        
        # Generate a user-friendly response
        response = {
            "status": "success" if result["success"] else "partial_success" if result["success_count"] > 0 else "error",
            "devices": target_devices,
            "count": len(target_devices),
            "success_count": result["success_count"],
            "results": {}
        }
        
        # Format the device results
        for device_id, device_result in result["device_results"].items():
            response["results"][device_id] = {
                "status": "success" if device_result["success"] else "error",
                "message": device_result["message"],
                # Include only essential details to keep the response compact
                "details": {
                    "app_running": device_result.get("details", {}).get("verification", {}).get("app_running", False)
                }
            }
        
        return response
    except Exception as e:
        logger.error(f"Error in set_url endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/apply-settings")
async def apply_settings(
    settings: DeviceSettings = Body(..., embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True),
    parallel: bool = Body(True, embed=True)
):
    """
    Apply general settings to devices
    """
    try:
        # This endpoint is now just a wrapper around set_url with the full settings object
        return await set_url(
            url=settings.url,
            devices=devices,
            all_devices=all_devices,
            iterations=settings.iterations,
            min_interval=settings.min_interval,
            max_interval=settings.max_interval,
            webview_mode=settings.webview_mode,
            rotate_ip=settings.rotate_ip,
            random_devices=settings.random_devices,
            new_webview_per_request=settings.new_webview_per_request,
            restore_on_exit=settings.restore_on_exit,
            use_proxy=settings.use_proxy,
            proxy_address=settings.proxy_address,
            proxy_port=settings.proxy_port,
            parallel=parallel
        )
    except Exception as e:
        logger.error(f"Error in apply_settings endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/instagram-settings")
async def instagram_settings(
    url: str = Body(..., embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True),
    parallel: bool = Body(True, embed=True)
):
    """
    Apply Instagram-specific settings (handles complex URLs)
    This endpoint is a simple wrapper around set-url for backwards compatibility
    """
    try:
        return await set_url(
            url=url,
            devices=devices,
            all_devices=all_devices,
            parallel=parallel
        )
    except Exception as e:
        logger.error(f"Error in instagram_settings endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
    print("Starting Improved Device Settings API server...")
    uvicorn.run("improved_settings_api:app", host="0.0.0.0", port=8000, reload=True) 