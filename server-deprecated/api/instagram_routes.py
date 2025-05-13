"""
Instagram URL and Settings Routes
These routes provide direct integration with the Instagram manager core module
"""
import os
import sys
import logging
import json
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, HTTPException, Body, BackgroundTasks, Depends

# Import our Instagram manager
from core.instagram_manager import instagram_manager, DeviceInfo

# Set up logger
logger = logging.getLogger("server.instagram_routes")

# Create router
router = APIRouter(
    prefix="/instagram",
    tags=["instagram"],
    responses={404: {"description": "Not found"}},
)

# Background task function to set URL
async def set_instagram_url_task(
    device_id: str,
    url: str,
    webview_mode: bool = True,
    new_webview_per_request: bool = True,
    rotate_ip: bool = True,
    random_devices: bool = True,
    iterations: int = 100,
    min_interval: int = 3,
    max_interval: int = 5,
    delay: int = 3000
):
    """Background task to set Instagram URL and settings"""
    try:
        # Call the Instagram manager directly
        result = await instagram_manager.set_instagram_url(
            device_id=device_id,
            url=url,
            webview_mode=webview_mode,
            new_webview_per_request=new_webview_per_request,
            rotate_ip=rotate_ip,
            random_devices=random_devices,
            iterations=iterations,
            min_interval=min_interval,
            max_interval=max_interval,
            delay=delay
        )
        
        if result["success"]:
            logger.info(f"Successfully set Instagram URL on device {device_id}")
        else:
            logger.error(f"Failed to set Instagram URL on device {device_id}: {result['message']}")
    except Exception as e:
        logger.error(f"Error in background task setting Instagram URL: {e}")

# API Routes
@router.get("/")
async def instagram_root():
    """Root endpoint for Instagram API"""
    return {"status": "online", "message": "Instagram API is available"}

@router.get("/devices")
async def get_devices():
    """Get list of connected devices"""
    try:
        # Get devices directly from the Instagram manager
        devices = await instagram_manager.get_connected_devices()
        return {
            "devices": [device.to_dict() for device in devices],
            "count": len(devices)
        }
    except Exception as e:
        logger.error(f"Error getting devices: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/set-url")
async def set_instagram_url(
    background_tasks: BackgroundTasks,
    url: str = Body(..., embed=True),
    iterations: int = Body(100, embed=True),
    min_interval: int = Body(3, embed=True),
    max_interval: int = Body(5, embed=True),
    webview_mode: bool = Body(True, embed=True),
    new_webview_per_request: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True),
    random_devices: bool = Body(True, embed=True),
    delay: int = Body(3000, embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(True, embed=True)
):
    """Set Instagram URL and settings on device(s) asynchronously"""
    try:
        # Get connected devices
        connected_devices = await instagram_manager.get_connected_devices()
        
        if not connected_devices:
            raise HTTPException(status_code=404, detail="No devices connected")
        
        # Determine which devices to target
        target_devices = []
        if all_devices:
            target_devices = [d.id for d in connected_devices]
        elif devices:
            # Validate that specified devices exist
            device_ids = [d.id for d in connected_devices]
            target_devices = [d for d in devices if d in device_ids]
            if not target_devices:
                raise HTTPException(status_code=404, detail="None of the specified devices are connected")
        else:
            # Default to first device if nothing specified
            target_devices = [connected_devices[0].id]
        
        # Add background tasks for each device
        for device_id in target_devices:
            background_tasks.add_task(
                set_instagram_url_task,
                device_id=device_id,
                url=url,
                webview_mode=webview_mode,
                new_webview_per_request=new_webview_per_request,
                rotate_ip=rotate_ip,
                random_devices=random_devices,
                iterations=iterations,
                min_interval=min_interval,
                max_interval=max_interval,
                delay=delay
            )
        
        # Return immediate response
        settings = {
            "url": url,
            "iterations": iterations,
            "min_interval": min_interval,
            "max_interval": max_interval,
            "webview_mode": webview_mode,
            "new_webview_per_request": new_webview_per_request,
            "rotate_ip": rotate_ip,
            "random_devices": random_devices,
            "delay": delay
        }
        
        return {
            "status": "processing",
            "message": f"Setting Instagram URL on {len(target_devices)} device(s) in the background",
            "settings": settings,
            "target_devices": target_devices
        }
    except Exception as e:
        logger.error(f"Error setting Instagram URL: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/set-url-sync")
async def set_instagram_url_sync(
    url: str = Body(..., embed=True),
    iterations: int = Body(100, embed=True),
    min_interval: int = Body(3, embed=True),
    max_interval: int = Body(5, embed=True),
    webview_mode: bool = Body(True, embed=True),
    new_webview_per_request: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True),
    random_devices: bool = Body(True, embed=True),
    delay: int = Body(3000, embed=True),
    devices: Optional[List[str]] = Body(None, embed=True),
    all_devices: bool = Body(True, embed=True)
):
    """Set Instagram URL and settings on device(s) synchronously"""
    try:
        # Get connected devices
        connected_devices = await instagram_manager.get_connected_devices()
        
        if not connected_devices:
            raise HTTPException(status_code=404, detail="No devices connected")
        
        # Determine which devices to target
        target_devices = []
        if all_devices:
            target_devices = [d.id for d in connected_devices]
        elif devices:
            # Validate that specified devices exist
            device_ids = [d.id for d in connected_devices]
            target_devices = [d for d in devices if d in device_ids]
            if not target_devices:
                raise HTTPException(status_code=404, detail="None of the specified devices are connected")
        else:
            # Default to first device if nothing specified
            target_devices = [connected_devices[0].id]
        
        # Process each device synchronously
        results = []
        for device_id in target_devices:
            logger.info(f"Setting Instagram URL on device {device_id}")
            result = await instagram_manager.set_instagram_url(
                device_id=device_id,
                url=url,
                webview_mode=webview_mode,
                new_webview_per_request=new_webview_per_request,
                rotate_ip=rotate_ip,
                random_devices=random_devices,
                iterations=iterations,
                min_interval=min_interval,
                max_interval=max_interval,
                delay=delay
            )
            results.append(result)
        
        # Prepare response
        success_count = sum(1 for r in results if r["success"])
        device_results = {r["device_id"]: {
            "success": r["success"],
            "message": r["message"],
            "details": r.get("details", {})
        } for r in results}
        
        return {
            "success": success_count > 0,
            "message": f"Applied settings to {success_count}/{len(results)} devices",
            "device_results": device_results,
            "success_count": success_count,
            "total_count": len(results)
        }
    except Exception as e:
        logger.error(f"Error setting Instagram URL: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/restart-app")
async def restart_app(
    devices: Optional[List[str]] = Body(None, embed=True), 
    all_devices: bool = Body(True, embed=True)
):
    """Restart the app on the specified device(s)"""
    try:
        # Get connected devices
        connected_devices = await instagram_manager.get_connected_devices()
        
        if not connected_devices:
            raise HTTPException(status_code=404, detail="No devices connected")
        
        # Determine target devices
        target_devices = []
        if all_devices:
            target_devices = [d.id for d in connected_devices]
        elif devices:
            device_ids = [d.id for d in connected_devices]
            target_devices = [d for d in devices if d in device_ids]
            if not target_devices:
                raise HTTPException(status_code=404, detail="None of the specified devices are connected")
        else:
            # Default to first device
            target_devices = [connected_devices[0].id]
        
        # Restart app on each device
        results = []
        for device_id in target_devices:
            logger.info(f"Restarting app on device {device_id}")
            success = await instagram_manager.restart_app(device_id)
            results.append({"device_id": device_id, "success": success})
        
        # Prepare response
        success_count = sum(1 for r in results if r["success"])
        
        return {
            "success": success_count > 0,
            "message": f"Restarted app on {success_count}/{len(results)} devices",
            "results": results
        }
    except Exception as e:
        logger.error(f"Error restarting app: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/device/{device_id}/status")
async def get_device_status(device_id: str):
    """Get status of a specific device"""
    try:
        # Get all devices
        devices = await instagram_manager.get_connected_devices()
        
        # Find the device with the given ID
        device = next((d for d in devices if d.id == device_id), None)
        
        if not device:
            raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
        
        return device.to_dict()
    except Exception as e:
        logger.error(f"Error getting device status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/device/{device_id}/set-url")
async def set_device_url(
    device_id: str,
    url: str = Body(..., embed=True),
    iterations: int = Body(100, embed=True),
    min_interval: int = Body(3, embed=True),
    max_interval: int = Body(5, embed=True),
    webview_mode: bool = Body(True, embed=True),
    new_webview_per_request: bool = Body(True, embed=True),
    rotate_ip: bool = Body(True, embed=True),
    random_devices: bool = Body(True, embed=True),
    delay: int = Body(3000, embed=True)
):
    """Set Instagram URL for a specific device"""
    try:
        # Check if device exists
        devices = await instagram_manager.get_connected_devices()
        if not any(d.id == device_id for d in devices):
            raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
        
        # Set the URL
        result = await instagram_manager.set_instagram_url(
            device_id=device_id,
            url=url,
            webview_mode=webview_mode,
            new_webview_per_request=new_webview_per_request,
            rotate_ip=rotate_ip,
            random_devices=random_devices,
            iterations=iterations,
            min_interval=min_interval,
            max_interval=max_interval,
            delay=delay
        )
        
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["message"])
        
        return {
            "success": True,
            "message": f"Successfully set URL on device {device_id}",
            "details": result["details"]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error setting URL on device {device_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e)) 