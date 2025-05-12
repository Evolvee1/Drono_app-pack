import asyncio
import logging
import os
import re
import subprocess
from typing import Dict, List, Optional

from config.settings import ADB_PATH

logger = logging.getLogger(__name__)

class Device:
    def __init__(self, id: str, model: str, status: str):
        self.id = id
        self.model = model
        self.status = status
        self.last_command_status = None
        self.running = False
        self.last_updated = None
        self.current_iteration = None

    def to_dict(self):
        return {
            "id": self.id,
            "model": self.model,
            "status": self.status,
            "running": self.running,
            "last_command_status": self.last_command_status,
            "last_updated": self.last_updated,
            "current_iteration": self.current_iteration
        }

class DeviceManager:
    def __init__(self):
        self.devices: Dict[str, Device] = {}
        self.adb_path = ADB_PATH
        self.scan_lock = asyncio.Lock()
        self.scan_task = None

    async def initialize(self):
        """Initialize the device manager and start periodic device scanning"""
        logger.info("Initializing device manager")
        await self.scan_devices()
        self.scan_task = asyncio.create_task(self._periodic_scan())

    async def shutdown(self):
        """Shutdown the device manager and stop scanning"""
        if self.scan_task:
            self.scan_task.cancel()
            try:
                await self.scan_task
            except asyncio.CancelledError:
                pass
        logger.info("Device manager shutdown complete")

    async def _periodic_scan(self, interval: int = 30):
        """Periodically scan for connected devices"""
        while True:
            try:
                await asyncio.sleep(interval)
                await self.scan_devices()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error in periodic scan: {e}")

    async def scan_devices(self):
        """Scan and update the list of connected devices"""
        async with self.scan_lock:
            try:
                devices_output = await self._run_adb_command(["devices", "-l"])
                current_devices = {}
                
                # Parse device list output
                lines = devices_output.strip().split('\n')
                for line in lines[1:]:  # Skip the first line (header)
                    if not line.strip():
                        continue
                    
                    parts = line.split()
                    if len(parts) >= 2:
                        device_id = parts[0]
                        status = parts[1]
                        
                        # Skip unauthorized or offline devices
                        if status not in ["device", "unauthorized", "offline"]:
                            continue
                        
                        # Extract model info
                        model = "Unknown"
                        model_match = re.search(r'model:(\S+)', line)
                        if model_match:
                            model = model_match.group(1)
                        
                        # If device already exists, update it
                        if device_id in self.devices:
                            self.devices[device_id].status = status
                            self.devices[device_id].model = model
                        else:
                            self.devices[device_id] = Device(device_id, model, status)
                        
                        current_devices[device_id] = self.devices[device_id]
                
                # Remove disconnected devices
                device_ids = list(self.devices.keys())
                for device_id in device_ids:
                    if device_id not in current_devices:
                        del self.devices[device_id]
                
                logger.info(f"Found {len(self.devices)} connected devices")
                return list(self.devices.values())
            
            except Exception as e:
                logger.error(f"Error scanning devices: {e}")
                return []

    async def get_device(self, device_id: str) -> Optional[Device]:
        """Get a device by its ID"""
        return self.devices.get(device_id)

    async def get_all_devices(self) -> List[Device]:
        """Get all connected devices"""
        return list(self.devices.values())

    async def _run_adb_command(self, command: List[str], device_id: str = None) -> str:
        """Run an ADB command and return the output"""
        cmd = [self.adb_path]
        if device_id:
            cmd.extend(["-s", device_id])
        cmd.extend(command)
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                stderr_text = stderr.decode('utf-8', errors='replace')
                logger.error(f"ADB command failed: {' '.join(cmd)}\nError: {stderr_text}")
                raise Exception(f"ADB command failed: {stderr_text}")
            
            return stdout.decode('utf-8', errors='replace')
        except Exception as e:
            logger.error(f"Failed to run ADB command {' '.join(cmd)}: {e}")
            raise
