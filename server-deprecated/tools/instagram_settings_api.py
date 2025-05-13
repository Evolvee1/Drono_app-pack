#!/usr/bin/env python3
"""
Instagram Settings API - Server wrapper for the instagram_url_setter.py script
This provides a REST API for setting Instagram URLs and configuration
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

# Add current directory to path
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(script_dir)

# Import functions from instagram_url_setter.py
from instagram_url_setter import (
    get_connected_devices,
    set_instagram_url,
    DeviceNotConnectedError
)

# Configure logging
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'instagram_settings_api.log'))
    ]
)
logger = logging.getLogger('instagram_settings_api')

# Create FastAPI app
app = FastAPI(title="Instagram Settings API", 
              description="API for setting Instagram URLs and configuration",
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
class InstagramSettings(BaseModel):
    url: str = Field(..., description="Instagram URL to set")
    iterations: int = Field(100, description="Number of iterations to run")
    min_interval: int = Field(3, description="Minimum interval between requests (seconds)")
    max_interval: int = Field(5, description="Maximum interval between requests (seconds)")
    webview_mode: bool = Field(True, description="Use webview mode")
    new_webview_per_request: bool = Field(True, description="Create new webview for each request")
    rotate_ip: bool = Field(True, description="Rotate IP between requests")
    random_devices: bool = Field(True, description="Use random device profiles")
    delay: int = Field(3000, description="Delay in milliseconds")
    
class DeviceInfo(BaseModel):
    id: str
    model: Optional[str] = None
    status: str
    
class DevicesList(BaseModel):
    devices: List[DeviceInfo]
    count: int

class SetURLResponse(BaseModel):
    success: bool
    message: str
    device_results: Dict[str, Any]
    success_count: int
    total_count: int

# API Routes
@app.get("/")
async def root():
    """Root endpoint"""
    return {"status": "online", "message": "Instagram Settings API is running"}

@app.get("/devices", response_model=DevicesList)
async def list_devices():
    """Get list of connected devices"""
    try:
        devices = await get_connected_devices()
        device_info = []
        
        for device in devices:
            info = DeviceInfo(
                id=device["id"],
                model=device.get("model", "Unknown"),
                status=device["status"]
            )
            device_info.append(info)
        
        return DevicesList(devices=device_info, count=len(device_info))
    except Exception as e:
        logger.error(f"Error getting devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/set-instagram-url", response_model=SetURLResponse)
async def set_url(
    settings: InstagramSettings = Body(...),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(True, embed=True)
):
    """Set Instagram URL and settings on device(s)"""
    try:
        # Get connected devices
        all_connected_devices = await get_connected_devices()
        
        if not all_connected_devices:
            raise HTTPException(status_code=404, detail="No devices connected")
        
        # Determine which devices to target
        if all_devices:
            target_devices = [d["id"] for d in all_connected_devices]
        elif devices:
            # Validate that specified devices exist
            device_ids = [d["id"] for d in all_connected_devices]
            target_devices = [d for d in devices if d in device_ids]
            if not target_devices:
                raise HTTPException(status_code=404, detail="None of the specified devices are connected")
        else:
            # Default to first device if nothing specified
            target_devices = [all_connected_devices[0]["id"]]
            
        logger.info(f"Setting Instagram URL on {len(target_devices)} device(s)")
        
        # Apply settings to each device
        results = []
        for device_id in target_devices:
            logger.info(f"Applying settings to device {device_id}")
            result = await set_instagram_url(
                device_id=device_id,
                url=settings.url,
                webview_mode=settings.webview_mode,
                new_webview_per_request=settings.new_webview_per_request,
                iterations=settings.iterations,
                min_interval=settings.min_interval,
                max_interval=settings.max_interval
            )
            results.append(result)
        
        # Prepare response
        success_count = sum(1 for r in results if r["success"])
        device_results = {r["device_id"]: {
            "success": r["success"],
            "message": r["message"],
            "details": r.get("details", {})
        } for r in results}
        
        return SetURLResponse(
            success=success_count == len(results),
            message=f"Applied settings to {success_count}/{len(results)} devices",
            device_results=device_results,
            success_count=success_count,
            total_count=len(results)
        )
        
    except DeviceNotConnectedError as e:
        logger.error(f"Device connection error: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error applying settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/set-advanced-settings")
async def set_advanced_settings(
    url: str = Body(..., embed=True),
    device_id: Optional[str] = Body(None, embed=True),
    iterations: int = Body(100, embed=True),
    min_interval: int = Body(3, embed=True),
    max_interval: int = Body(5, embed=True),
    webview_mode: bool = Body(True, embed=True),
    new_webview_per_request: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True),
    random_devices: bool = Body(True, embed=True),
    delay: int = Body(3000, embed=True)
):
    """Set advanced settings with individual parameters"""
    try:
        # Create settings object
        settings = InstagramSettings(
            url=url,
            iterations=iterations,
            min_interval=min_interval,
            max_interval=max_interval,
            webview_mode=webview_mode,
            new_webview_per_request=new_webview_per_request,
            rotate_ip=rotate_ip,
            random_devices=random_devices,
            delay=delay
        )
        
        # Determine device targeting
        if device_id:
            return await set_url(settings=settings, devices=[device_id], all_devices=False)
        else:
            return await set_url(settings=settings, devices=None, all_devices=True)
    
    except Exception as e:
        logger.error(f"Error in set_advanced_settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Run the server
if __name__ == "__main__":
    import subprocess
    
    # Check for required modules
    try:
        import fastapi
        import uvicorn
        import pydantic
    except ImportError:
        print("Installing required packages...")
        subprocess.run([sys.executable, "-m", "pip", "install", "fastapi", "uvicorn[standard]", "pydantic"], check=True)
    
    # Start the server
    print("Starting Instagram Settings API server on port 8001...")
    uvicorn.run("instagram_settings_api:app", host="0.0.0.0", port=8001, reload=True) 