from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from typing import Dict, Any, Optional, List

from api.auth import User, get_current_active_user
from core.device_manager import DeviceManager
from core.command_executor import CommandExecutor, CommandResult
from config.settings import PRESETS

router = APIRouter()

# Create a device_manager_instance that will be properly initialized in main.py
device_manager = None

# Create command executor instance
command_executor = CommandExecutor()

class CommandRequest(BaseModel):
    device_id: str
    dryrun: Optional[bool] = False

class SimulationStartRequest(CommandRequest):
    preset: Optional[str] = None
    url: Optional[str] = None
    iterations: Optional[int] = None
    min_interval: Optional[float] = None
    max_interval: Optional[float] = None
    rotate_ip: Optional[bool] = None
    webview_mode: Optional[bool] = None
    random_devices: Optional[bool] = None
    aggressive_clearing: Optional[bool] = None

class SimulationSettingsRequest(CommandRequest):
    url: Optional[str] = None
    iterations: Optional[int] = None
    min_interval: Optional[float] = None
    max_interval: Optional[float] = None
    rotate_ip: Optional[bool] = None
    webview_mode: Optional[bool] = None
    random_devices: Optional[bool] = None
    aggressive_clearing: Optional[bool] = None

class SessionActionRequest(CommandRequest):
    action: str

class CommandResponse(BaseModel):
    success: bool
    output: str
    error: Optional[str] = None
    timestamp: str

class PresetListResponse(BaseModel):
    presets: List[str]
    default: str = "veewoy"

@router.post("/start", response_model=CommandResponse)
async def start_simulation(request: SimulationStartRequest, current_user: User = Depends(get_current_active_user)):
    """Start a simulation on a device"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    # Extract custom parameters (if any)
    custom_params = {}
    for field in ['url', 'iterations', 'min_interval', 'max_interval', 
                 'rotate_ip', 'webview_mode', 'random_devices', 'aggressive_clearing']:
        value = getattr(request, field, None)
        if value is not None:
            custom_params[field] = value
    
    result = await command_executor.start_simulation(
        request.device_id, 
        preset=request.preset,
        custom_params=custom_params if custom_params else None,
        dryrun=request.dryrun
    )
    
    # Update device status
    if result.success and not request.dryrun:
        device.running = True
        device.last_command_status = "simulation_started"
    
    return result.to_dict()

@router.post("/stop", response_model=CommandResponse)
async def stop_simulation(request: CommandRequest, current_user: User = Depends(get_current_active_user)):
    """Stop a running simulation"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    result = await command_executor.stop_simulation(request.device_id, request.dryrun)
    
    # Update device status
    if result.success and not request.dryrun:
        device.running = False
        device.last_command_status = "simulation_stopped"
    
    return result.to_dict()

@router.post("/pause", response_model=CommandResponse)
async def pause_simulation(request: CommandRequest, current_user: User = Depends(get_current_active_user)):
    """Pause a running simulation"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    result = await command_executor.pause_simulation(request.device_id, request.dryrun)
    
    # Update device status
    if result.success and not request.dryrun:
        device.last_command_status = "simulation_paused"
    
    return result.to_dict()

@router.post("/resume", response_model=CommandResponse)
async def resume_simulation(request: CommandRequest, current_user: User = Depends(get_current_active_user)):
    """Resume a paused simulation"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    result = await command_executor.resume_simulation(request.device_id, request.dryrun)
    
    # Update device status
    if result.success and not request.dryrun:
        device.last_command_status = "simulation_resumed"
    
    return result.to_dict()

@router.post("/status", response_model=CommandResponse)
async def get_simulation_status(request: CommandRequest, current_user: User = Depends(get_current_active_user)):
    """Get the status of a simulation"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    result = await command_executor.get_status(request.device_id)
    
    return result.to_dict()

@router.post("/settings", response_model=CommandResponse)
async def update_settings(request: SimulationSettingsRequest, current_user: User = Depends(get_current_active_user)):
    """Update app settings without starting a simulation"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    # Extract settings
    settings = {}
    for field in ['url', 'iterations', 'min_interval', 'max_interval', 
                 'rotate_ip', 'webview_mode', 'random_devices', 'aggressive_clearing']:
        value = getattr(request, field, None)
        if value is not None:
            settings[field] = value
    
    if not settings:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No settings provided to update"
        )
    
    result = await command_executor.update_settings(request.device_id, settings, request.dryrun)
    
    # Update device status
    if result.success and not request.dryrun:
        device.last_command_status = "settings_updated"
    
    return result.to_dict()

@router.post("/session", response_model=CommandResponse)
async def handle_session(request: SessionActionRequest, current_user: User = Depends(get_current_active_user)):
    """Handle session actions (accept, decline, dismiss)"""
    device = await device_manager.get_device(request.device_id)
    if not device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Device with ID {request.device_id} not found"
        )
    
    if request.action not in ["accept", "decline", "dismiss"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid session action: {request.action}. Must be one of: accept, decline, dismiss"
        )
    
    result = await command_executor.handle_session(request.device_id, request.action, request.dryrun)
    
    # Update device status
    if result.success and not request.dryrun:
        device.last_command_status = f"session_{request.action}ed"
    
    return result.to_dict()

@router.get("/presets", response_model=PresetListResponse)
async def get_presets(current_user: User = Depends(get_current_active_user)):
    """Get a list of available preset configurations"""
    return PresetListResponse(presets=list(PRESETS.keys()), default="veewoy")

@router.get("/presets/{preset_name}")
async def get_preset_details(preset_name: str, current_user: User = Depends(get_current_active_user)):
    """Get details of a specific preset configuration"""
    if preset_name not in PRESETS:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Preset '{preset_name}' not found"
        )
    
    return PRESETS[preset_name]
