import logging
import subprocess
import time
import asyncio
import re
from typing import List, Dict, Tuple, Optional

logger = logging.getLogger(__name__)

# Define ADB path constant
ADB_PATH = "adb"  # Use just "adb" if it's in the PATH

class AdbController:
    def __init__(self):
        self._check_adb()
        self.adb_path = ADB_PATH

    def _check_adb(self):
        """Check if ADB is available"""
        try:
            result = subprocess.run(['adb', 'version'], capture_output=True, text=True, check=True)
            logger.info(f"ADB version: {result.stdout.strip()}")
        except subprocess.CalledProcessError as e:
            logger.error(f"ADB is not installed or not in PATH: {e.stderr}")
            raise
        except Exception as e:
            logger.error(f"Failed to check ADB: {e}")
            raise

    def _run_adb_command(self, command: str) -> str:
        """Run an ADB command using subprocess"""
        try:
            logger.debug(f"Running ADB command: adb {command}")
            result = subprocess.run(
                ['adb'] + command.split(),
                capture_output=True,
                text=True,
                check=True
            )
            logger.debug(f"ADB command output: {result.stdout.strip()}")
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            logger.error(f"ADB command failed: {e.stderr}")
            raise
        except Exception as e:
            logger.error(f"Failed to run ADB command: {e}")
            raise

    def get_devices(self) -> List[Dict]:
        """Get list of connected devices using ADB"""
        try:
            logger.info("Getting list of connected devices")
            # Run adb devices command
            output = self._run_adb_command('devices -l')
            devices = []
            
            # Parse the output
            for line in output.splitlines()[1:]:  # Skip the first line (header)
                if not line.strip():
                    continue
                    
                parts = line.split()
                if len(parts) >= 2:
                    device_id = parts[0]
                    status = parts[1]
                    
                    logger.info(f"Found device: {device_id} ({status})")
                    
                    # Get device model
                    try:
                        model = self._run_adb_command(f'-s {device_id} shell getprop ro.product.model')
                        logger.debug(f"Device {device_id} model: {model}")
                    except Exception as e:
                        logger.warning(f"Failed to get model for device {device_id}: {e}")
                        model = "Unknown"
                        
                    # Get battery level
                    try:
                        battery = self._run_adb_command(f'-s {device_id} shell dumpsys battery | grep level')
                        battery = battery.split(':')[1].strip() + '%'
                        logger.debug(f"Device {device_id} battery: {battery}")
                    except Exception as e:
                        logger.warning(f"Failed to get battery for device {device_id}: {e}")
                        battery = "Unknown"
                    
                    device_info = {
                        'id': device_id,
                        'name': model,
                        'model': model,
                        'status': 'online' if status == 'device' else 'offline',
                        'battery': battery,
                        'lastSeen': time.strftime('%Y-%m-%d %H:%M:%S')
                    }
                    logger.info(f"Device info: {device_info}")
                    devices.append(device_info)
            
            if not devices:
                logger.warning("No devices found")
            else:
                logger.info(f"Found {len(devices)} devices")
            
            return devices
        except Exception as e:
            logger.error(f"Failed to get devices: {e}")
            return []

    def execute_command(self, device_id: str, command: str) -> str:
        """Execute a command on a device using ADB"""
        try:
            logger.info(f"Executing command on device {device_id}: {command}")
            result = self._run_adb_command(f'-s {device_id} shell {command}')
            logger.debug(f"Command output: {result}")
            return result
        except Exception as e:
            logger.error(f"Failed to execute command on device {device_id}: {e}")
            raise

    async def run_adb_command(self, device_id: str, command: List[str]) -> Dict[str, str]:
        """Run an ADB command for a specific device"""
        cmd = [self.adb_path, "-s", device_id] + command
        
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            stdout_text = stdout.decode('utf-8', errors='replace')
            stderr_text = stderr.decode('utf-8', errors='replace')
            
            success = process.returncode == 0
            return {
                "success": success,
                "stdout": stdout_text,
                "stderr": stderr_text
            }
        
        except Exception as e:
            error_msg = f"Failed to run ADB command {' '.join(cmd)}: {str(e)}"
            logger.error(error_msg)
            return {
                "success": False,
                "stdout": "",
                "stderr": error_msg
            }
    
    async def execute_adb_command(self, device_id: str, command: List[str]) -> str:
        """Execute an ADB command and return stdout as string.
        Raises an exception if the command fails."""
        result = await self.run_adb_command(device_id, command)
        
        if not result["success"]:
            error_msg = f"ADB command failed: {result['stderr']}"
            logger.error(error_msg)
            raise RuntimeError(error_msg)
        
        return result["stdout"]
    
    async def get_device_properties(self, device_id: str) -> Dict[str, str]:
        """Get device properties"""
        result = await self.run_adb_command(device_id, ["shell", "getprop"])
        
        if not result["success"]:
            logger.error(f"Failed to get properties for device {device_id}: {result['stderr']}")
            return {}
        
        properties = {}
        for line in result["stdout"].split('\n'):
            match = re.match(r'\[([^\]]+)\]:\s*\[([^\]]*)\]', line)
            if match:
                key, value = match.groups()
                properties[key] = value
        
        return properties
    
    async def get_app_pid(self, device_id: str, package_name: str) -> Optional[str]:
        """Get PID of a running app"""
        result = await self.run_adb_command(
            device_id, ["shell", "pidof", package_name]
        )
        
        if not result["success"] or not result["stdout"].strip():
            return None
        
        return result["stdout"].strip()
    
    async def clear_app_data(self, device_id: str, package_name: str) -> bool:
        """Clear app data"""
        result = await self.run_adb_command(
            device_id, ["shell", "pm", "clear", package_name]
        )
        
        return result["success"] and "Success" in result["stdout"]
    
    async def force_stop_app(self, device_id: str, package_name: str) -> bool:
        """Force stop the app"""
        result = await self.run_adb_command(
            device_id, ["shell", "am", "force-stop", package_name]
        )
        
        return result["success"]
    
    async def launch_app(self, device_id: str, package_name: str, activity_name: str) -> bool:
        """Launch the app"""
        result = await self.run_adb_command(
            device_id, ["shell", "am", "start", "-n", f"{package_name}/{activity_name}"]
        )
        
        return result["success"] and "Error" not in result["stdout"]
    
    async def send_broadcast(self, device_id: str, package_name: str, action: str, 
                            extras: Dict[str, str] = None) -> bool:
        """Send a broadcast intent"""
        cmd = ["shell", "am", "broadcast", "-a", action, "-p", package_name]
        
        if extras:
            for key, value in extras.items():
                cmd.extend(["--es", key, value])
        
        result = await self.run_adb_command(device_id, cmd)
        
        return result["success"] and "Broadcast completed" in result["stdout"]
    
    async def edit_shared_prefs(self, device_id: str, package_name: str, 
                               prefs_name: str, key: str, value: str, 
                               value_type: str = "string") -> bool:
        """Edit shared preferences directly using the run-as command"""
        # Map of value types to XML types
        type_map = {
            "string": "String",
            "boolean": "Boolean",
            "int": "Integer",
            "long": "Long",
            "float": "Float"
        }
        
        if value_type not in type_map:
            logger.error(f"Unsupported value type: {value_type}")
            return False
        
        xml_type = type_map[value_type]
        
        # Build sed command to replace the preference value
        # or add it if it doesn't exist
        sed_pattern = f's|<{xml_type} name="{key}".*/>|<{xml_type} name="{key}">{value}</{xml_type}>|'
        grep_cmd = f'grep -q \'name="{key}"\' {{}} && sed -i \'{sed_pattern}\' {{}} || sed -i \'/<\/map>/i\\\\    <{xml_type} name="{key}">{value}</{xml_type}>\' {{}}'
        
        # Run the command
        cmd = [
            "shell", "run-as", package_name, "sh", "-c", 
            f"cd /data/data/{package_name}/shared_prefs && [ -f {prefs_name}.xml ] && {grep_cmd.format(prefs_name + '.xml')}"
        ]
        
        result = await self.run_adb_command(device_id, cmd)
        
        return result["success"]

# Create a singleton instance
adb_controller = AdbController()
