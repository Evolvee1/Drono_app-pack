#!/usr/bin/env python3
"""
URL Distribution API - FastAPI endpoint for distributing URLs to devices
"""

import os
import sys
import logging
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Body, Query
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Add the parent directory to path to import modules
script_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(script_dir)
sys.path.append(parent_dir)

# Import the distribute_url function
from distribute_url import distribute_url, get_connected_devices

# Configure logging
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'url_distribution_api.log'))
    ]
)
logger = logging.getLogger('url_distribution_api')

# Create FastAPI app
app = FastAPI(
    title="URL Distribution API",
    description="API for distributing URLs to Android devices",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    """Root endpoint - Health check"""
    return {
        "status": "online", 
        "message": "URL Distribution API is running"
    }

@app.get("/devices")
async def get_devices():
    """Get all connected devices"""
    devices = get_connected_devices()
    return {
        "devices": devices,
        "count": len(devices)
    }

@app.post("/distribute")
async def distribute(
    url: str = Body(..., embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True),
    iterations: int = Body(100, embed=True),
    min_interval: int = Body(1, embed=True),
    max_interval: int = Body(2, embed=True),
    parallel: bool = Body(True, embed=True),
    start: bool = Body(True, embed=True),
    use_webview: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True)
):
    """
    Distribute a URL to multiple devices
    
    - **url**: The URL to distribute (required)
    - **devices**: List of device IDs (optional, defaults to None)
    - **all_devices**: Whether to target all connected devices (default: False)
    - **iterations**: Number of iterations (default: 100)
    - **min_interval**: Minimum interval in seconds (default: 1)
    - **max_interval**: Maximum interval in seconds (default: 2)
    - **parallel**: Whether to run commands in parallel (default: True)
    - **start**: Whether to start the simulation (default: True)
    - **use_webview**: Whether to use webview mode (default: True)
    - **rotate_ip**: Whether to rotate IP (default: True)
    """
    logger.info(f"Received request to distribute URL: {url}")
    
    # Determine which devices to target
    target_devices = None
    if all_devices:
        target_devices = None  # None means all devices in distribute_url
    elif devices:
        target_devices = devices
    else:
        raise HTTPException(
            status_code=400,
            detail="Either 'devices' list or 'all_devices' flag must be provided"
        )
    
    # Distribute the URL
    result = distribute_url(
        url=url,
        devices=target_devices,
        iterations=iterations,
        min_interval=min_interval,
        max_interval=max_interval,
        parallel=parallel,
        start=start,
        use_webview=use_webview,
        rotate_ip=rotate_ip
    )
    
    if not result.get("success", False):
        error_msg = result.get("error", "Unknown error")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to distribute URL: {error_msg}"
        )
    
    return result

@app.get("/status/{device_id}")
async def get_status(device_id: str):
    """
    Get the status of a specific device
    
    - **device_id**: Device ID to check
    """
    # Check if device is connected
    devices = get_connected_devices()
    if device_id not in devices:
        raise HTTPException(
            status_code=404,
            detail=f"Device {device_id} not found or not connected"
        )
    
    # TODO: Implement actual status checking
    # For now, just return that the device is connected
    return {
        "device_id": device_id,
        "connected": True,
        "status": "connected"
    }

@app.post("/stop")
async def stop_devices(
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(False, embed=True)
):
    """
    Stop simulations on devices
    
    - **devices**: List of device IDs (optional)
    - **all_devices**: Whether to target all connected devices (default: False)
    """
    # Determine which devices to target
    target_devices = None
    if all_devices:
        target_devices = get_connected_devices()
    elif devices:
        target_devices = devices
    else:
        raise HTTPException(
            status_code=400,
            detail="Either 'devices' list or 'all_devices' flag must be provided"
        )
    
    # Stop simulations on each device
    results = {}
    for device_id in target_devices:
        result = distribute_url(
            url="https://example.com",  # Dummy URL, not used
            devices=[device_id],
            start=False,  # Don't start simulation
            parallel=False  # Run sequentially
        )
        results[device_id] = {
            "success": result.get("success", False)
        }
    
    return {
        "success": any(r.get("success", False) for r in results.values()),
        "results": results
    }

def main():
    """Run the FastAPI server"""
    parser = uvicorn.Config("url_distribution_api:app", host="0.0.0.0", port=8001, log_level="info")
    server = uvicorn.Server(parser)
    server.run()

if __name__ == "__main__":
    main() 