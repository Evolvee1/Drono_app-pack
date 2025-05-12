#!/usr/bin/env python3
"""
Unified Command API - Reliable interface for communicating with Android devices
"""
import os
import sys
import logging
import subprocess
import json
import time
import asyncio
from typing import List, Dict, Any, Optional, Tuple

# Configure logging
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'unified_command.log'))
    ]
)
logger = logging.getLogger('unified_command')

class DeviceCommandError(Exception):
    """Exception raised for errors in device commands"""
    def __init__(self, message, device_id=None, command=None, details=None):
        self.message = message
        self.device_id = device_id
        self.command = command
        self.details = details
        super().__init__(self.message)

class CommandType:
    """Enumeration of command types"""
    BROADCAST = "broadcast"
    PREFERENCE = "preference"
    HYBRID = "hybrid"

class DeviceCommand:
    """Base class for device commands"""
    
    def __init__(self, device_id: str):
        self.device_id = device_id
        
    async def execute(self) -> Dict[str, Any]:
        """Execute the command and return results"""
        raise NotImplementedError("Subclasses must implement execute()")
        
    async def verify(self) -> bool:
        """Verify the command execution was successful"""
        raise NotImplementedError("Subclasses must implement verify()")

class DeviceConnector:
    """Handles connection and communication with Android devices"""
    
    @staticmethod
    async def get_devices() -> List[Dict[str, str]]:
        """Get a list of connected devices with their details"""
        try:
            # Run ADB devices command and capture output
            process = await asyncio.create_subprocess_exec(
                "adb", "devices", "-l",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                raise DeviceCommandError(f"ADB devices command failed: {stderr.decode()}")
            
            # Parse the output to extract device information
            lines = stdout.decode().strip().split('\n')[1:]  # Skip the first line (header)
            devices = []
            
            for line in lines:
                if line.strip() and 'device' in line:
                    parts = line.split()
                    device_id = parts[0].strip()
                    
                    # Get device model
                    model_process = await asyncio.create_subprocess_exec(
                        "adb", "-s", device_id, "shell", "getprop", "ro.product.model",
                        stdout=asyncio.subprocess.PIPE
                    )
                    model_stdout, _ = await model_process.communicate()
                    model = model_stdout.decode().strip() if model_stdout else "Unknown"
                    
                    devices.append({
                        "id": device_id,
                        "status": "connected",
                        "model": model
                    })
            
            logger.info(f"Found {len(devices)} connected devices")
            return devices
            
        except Exception as e:
            logger.error(f"Error getting connected devices: {e}")
            return []
    
    @staticmethod
    async def check_device_connection(device_id: str) -> bool:
        """Check if a device is connected and responding"""
        try:
            process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "get-state",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            return process.returncode == 0 and "device" in stdout.decode()
        except Exception as e:
            logger.error(f"Error checking device connection for {device_id}: {e}")
            return False
    
    @staticmethod
    async def send_broadcast(device_id: str, action: str, extras: Dict[str, Any]) -> Tuple[bool, str]:
        """Send a broadcast intent to the device with the given action and extras"""
        try:
            # Construct the broadcast command
            cmd = ["adb", "-s", device_id, "shell", "am", "broadcast", "-a", action]
            
            # Add extras
            for key, value in extras.items():
                if isinstance(value, bool):
                    cmd.extend(["--ez", key, str(value).lower()])
                elif isinstance(value, int):
                    cmd.extend(["--ei", key, str(value)])
                elif isinstance(value, float):
                    cmd.extend(["--ef", key, str(value)])
                else:
                    cmd.extend(["--es", key, str(value)])
            
            # Add package if available
            if "package" in extras:
                cmd.extend(["-p", extras["package"]])
                
            # Execute the command
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode() or stdout.decode()
                logger.error(f"Failed to send broadcast to {device_id}: {error_msg}")
                return False, error_msg
            
            output = stdout.decode()
            logger.info(f"Broadcast sent to {device_id}: {output}")
            return True, output
        except Exception as e:
            logger.error(f"Exception sending broadcast to {device_id}: {e}")
            return False, str(e)
    
    @staticmethod
    async def set_preference(device_id: str, package: str, pref_file: str, key: str, value: Any, 
                            value_type: str = "string") -> Tuple[bool, str]:
        """Set a preference value directly in the app's shared preferences file"""
        try:
            # First check if we have root access or run-as access
            run_as_access = False
            root_access = False
            
            # Check run-as access
            run_as_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell", f"run-as {package} ls /data/data/{package}/shared_prefs",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, _ = await run_as_process.communicate()
            run_as_access = run_as_process.returncode == 0
            
            # Check root access if run-as failed
            if not run_as_access:
                root_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", device_id, "shell", "su -c 'echo test'",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                _, _ = await root_process.communicate()
                root_access = root_process.returncode == 0
            
            if not run_as_access and not root_access:
                return False, "No run-as or root access available"
            
            # Prepare the command to update the preference
            if value_type.lower() == "string":
                if run_as_access:
                    # Create a temporary file locally, push it, and then use run-as to replace
                    temp_file = f"/data/local/tmp/temp_pref_{int(time.time())}.xml"
                    shell_cmd = f"""
                    run-as {package} cat {pref_file} | sed -e 's|<string name="{key}">[^<]*</string>|<string name="{key}">{value}</string>|g' > {temp_file} && 
                    run-as {package} cp {temp_file} {pref_file}
                    """
                else:
                    # Use root for direct access
                    shell_cmd = f"""
                    su -c 'cat {pref_file} | sed -e "s|<string name=\\"{key}\\">[^<]*</string>|<string name=\\"{key}\\">{value}</string>|g" > /data/local/tmp/temp_pref.xml && 
                    cp /data/local/tmp/temp_pref.xml {pref_file} && 
                    chmod 660 {pref_file} && 
                    chown {package}:{package} {pref_file}'
                    """
            elif value_type.lower() in ["boolean", "int", "long", "float"]:
                if run_as_access:
                    temp_file = f"/data/local/tmp/temp_pref_{int(time.time())}.xml"
                    shell_cmd = f"""
                    run-as {package} cat {pref_file} | sed -e 's|<{value_type} name="{key}" value="[^"]*"|<{value_type} name="{key}" value="{value}"|g' > {temp_file} && 
                    run-as {package} cp {temp_file} {pref_file}
                    """
                else:
                    shell_cmd = f"""
                    su -c 'cat {pref_file} | sed -e "s|<{value_type} name=\\"{key}\\" value=\\"[^\\"]*\\"|<{value_type} name=\\"{key}\\" value=\\"{value}\\"|g" > /data/local/tmp/temp_pref.xml && 
                    cp /data/local/tmp/temp_pref.xml {pref_file} && 
                    chmod 660 {pref_file} && 
                    chown {package}:{package} {pref_file}'
                    """
            else:
                return False, f"Unsupported value type: {value_type}"
            
            # Execute the command
            process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell", shell_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode() or stdout.decode()
                logger.error(f"Failed to set preference on {device_id}: {error_msg}")
                return False, error_msg
            
            logger.info(f"Preference {key} set on {device_id}")
            return True, "Preference updated successfully"
        except Exception as e:
            logger.error(f"Exception setting preference on {device_id}: {e}")
            return False, str(e)
    
    @staticmethod
    async def run_activity(device_id: str, package: str, activity: str, 
                         extras: Optional[Dict[str, Any]] = None) -> Tuple[bool, str]:
        """Start an activity with the given extras"""
        try:
            # Construct the command to start the activity
            cmd = ["adb", "-s", device_id, "shell", "am", "start", "-n", f"{package}/{activity}"]
            
            # Add extras
            if extras:
                for key, value in extras.items():
                    if isinstance(value, bool):
                        cmd.extend(["--ez", key, str(value).lower()])
                    elif isinstance(value, int):
                        cmd.extend(["--ei", key, str(value)])
                    elif isinstance(value, float):
                        cmd.extend(["--ef", key, str(value)])
                    else:
                        cmd.extend(["--es", key, str(value)])
            
            # Execute the command
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode() or stdout.decode()
                logger.error(f"Failed to start activity on {device_id}: {error_msg}")
                return False, error_msg
            
            output = stdout.decode()
            logger.info(f"Activity started on {device_id}: {output}")
            return True, output
        except Exception as e:
            logger.error(f"Exception starting activity on {device_id}: {e}")
            return False, str(e)

class UrlCommand(DeviceCommand):
    """Command to set URL in the app"""
    
    def __init__(self, device_id: str, url: str, iterations: int = 1000, 
                min_interval: int = 1, max_interval: int = 2, 
                webview_mode: bool = True, rotate_ip: bool = True,
                random_devices: bool = True, new_webview_per_request: bool = True):
        super().__init__(device_id)
        self.url = url
        self.iterations = iterations
        self.min_interval = min_interval
        self.max_interval = max_interval
        self.webview_mode = webview_mode
        self.rotate_ip = rotate_ip
        self.random_devices = random_devices
        self.new_webview_per_request = new_webview_per_request
        self.package = "com.example.imtbf.debug"
        self.pref_file = f"/data/data/{self.package}/shared_prefs/instagram_traffic_simulator_prefs.xml"
        self.activity = "com.example.imtbf.presentation.activities.MainActivity"
        self.broadcast_action = "com.example.imtbf.debug.COMMAND"
        
    async def execute(self) -> Dict[str, Any]:
        """Execute the command using a hybrid approach for maximum reliability"""
        logger.info(f"Setting URL on device {self.device_id}: {self.url}")
        
        try:
            # Step 1: Check device connection
            if not await DeviceConnector.check_device_connection(self.device_id):
                return {
                    "success": False,
                    "message": "Device is not connected or not authorized"
                }
            
            # Step 2: Stop the app first if it's running
            await DeviceConnector.send_broadcast(
                self.device_id, 
                self.broadcast_action, 
                {"command": "stop", "package": self.package}
            )
            
            # Step 3: Kill the app to ensure a fresh start
            process = await asyncio.create_subprocess_exec(
                "adb", "-s", self.device_id, "shell", f"am force-stop {self.package}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await process.communicate()
            
            # Step 4: Set the URL via preferences (most reliable method)
            success, message = await DeviceConnector.set_preference(
                self.device_id, 
                self.package, 
                self.pref_file, 
                "target_url", 
                self.url, 
                "string"
            )
            
            # Also set cached_url and start_url for redundancy
            if success:
                await DeviceConnector.set_preference(
                    self.device_id, self.package, self.pref_file, 
                    "cached_url", self.url, "string"
                )
                await DeviceConnector.set_preference(
                    self.device_id, self.package, self.pref_file, 
                    "start_url", self.url, "string"
                )
            
            # Step 5: Set other preferences
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "iterations", str(self.iterations), "int"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "min_interval", str(self.min_interval), "int"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "max_interval", str(self.max_interval), "int"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "use_webview_mode", str(self.webview_mode).lower(), "boolean"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "rotate_ip", str(self.rotate_ip).lower(), "boolean"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "use_random_device_profile", str(self.random_devices).lower(), "boolean"
            )
            await DeviceConnector.set_preference(
                self.device_id, self.package, self.pref_file, 
                "new_webview_per_request", str(self.new_webview_per_request).lower(), "boolean"
            )
            
            # Step 6: Start the app with URL deep link for maximum reliability
            deep_link_success, deep_link_message = await DeviceConnector.run_activity(
                self.device_id,
                self.package,
                self.activity,
                {
                    "action": "android.intent.action.VIEW",
                    "data": f"traffic-sim://load_url?url={self.url}&force=true"
                }
            )
            
            # Step 7: Also send the broadcast command as a backup
            broadcast_success, broadcast_message = await DeviceConnector.send_broadcast(
                self.device_id,
                self.broadcast_action,
                {
                    "command": "set_url",
                    "value": self.url,
                    "package": self.package
                }
            )
            
            # Step 8: Verify the URL was set correctly
            verification = await self.verify()
            
            return {
                "success": success and (deep_link_success or broadcast_success) and verification["success"],
                "message": "URL set successfully" if verification["success"] else "URL set but verification failed",
                "details": {
                    "preference_set": success,
                    "preference_message": message,
                    "deep_link": deep_link_success,
                    "deep_link_message": deep_link_message,
                    "broadcast": broadcast_success,
                    "broadcast_message": broadcast_message,
                    "verification": verification
                }
            }
            
        except Exception as e:
            logger.error(f"Error setting URL on device {self.device_id}: {e}")
            return {
                "success": False,
                "message": f"Error: {str(e)}",
                "details": {}
            }
    
    async def verify(self) -> Dict[str, Any]:
        """Verify the URL was set correctly"""
        try:
            # Check if the app is running
            process = await asyncio.create_subprocess_exec(
                "adb", "-s", self.device_id, "shell", f"pidof {self.package}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await process.communicate()
            app_running = stdout.decode().strip() != ""
            
            # Check the URL in preferences
            if app_running:
                # First try run-as
                run_as_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", self.device_id, "shell", f"run-as {self.package} cat {self.pref_file} | grep target_url",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, _ = await run_as_process.communicate()
                
                if run_as_process.returncode != 0:
                    # Try with root
                    root_process = await asyncio.create_subprocess_exec(
                        "adb", "-s", self.device_id, "shell", f"su -c 'cat {self.pref_file} | grep target_url'",
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, _ = await root_process.communicate()
                    
                prefs_output = stdout.decode().strip()
                url_in_prefs = self.url in prefs_output
                
                # Also send get_status command to check if the app reports the correct URL
                status_success, status_message = await DeviceConnector.send_broadcast(
                    self.device_id,
                    self.broadcast_action,
                    {
                        "command": "get_status",
                        "package": self.package
                    }
                )
                
                return {
                    "success": app_running and url_in_prefs,
                    "app_running": app_running,
                    "url_in_prefs": url_in_prefs,
                    "prefs_output": prefs_output,
                    "status_command": status_success,
                    "status_message": status_message
                }
            else:
                return {
                    "success": False,
                    "app_running": False,
                    "message": "App is not running"
                }
                
        except Exception as e:
            logger.error(f"Error verifying URL on device {self.device_id}: {e}")
            return {
                "success": False,
                "message": f"Verification error: {str(e)}"
            }

# Main command executor functions
async def set_url_on_devices(url: str, device_ids: List[str], parallel: bool = True, **kwargs) -> Dict[str, Any]:
    """Set URL on multiple devices with maximum reliability"""
    results = {}
    
    async def process_device(device_id):
        command = UrlCommand(
            device_id, 
            url, 
            iterations=kwargs.get("iterations", 1000),
            min_interval=kwargs.get("min_interval", 1),
            max_interval=kwargs.get("max_interval", 2),
            webview_mode=kwargs.get("webview_mode", True),
            rotate_ip=kwargs.get("rotate_ip", True),
            random_devices=kwargs.get("random_devices", True),
            new_webview_per_request=kwargs.get("new_webview_per_request", True)
        )
        return {device_id: await command.execute()}
    
    if parallel:
        # Process devices in parallel
        tasks = [process_device(device_id) for device_id in device_ids]
        results_list = await asyncio.gather(*tasks)
        for result in results_list:
            results.update(result)
    else:
        # Process devices sequentially
        for device_id in device_ids:
            device_result = await process_device(device_id)
            results.update(device_result)
    
    # Calculate success rate
    success_count = sum(1 for result in results.values() if result["success"])
    
    return {
        "success": success_count == len(device_ids),
        "success_count": success_count,
        "total_devices": len(device_ids),
        "device_results": results
    }

async def get_connected_devices() -> List[Dict[str, str]]:
    """Get a list of connected devices"""
    return await DeviceConnector.get_devices()

# For testing
async def main():
    """Test function"""
    devices = await get_connected_devices()
    print(f"Connected devices: {json.dumps(devices, indent=2)}")
    
    if devices:
        # Test on first device
        device_id = devices[0]["id"]
        url = "https://example.com"
        
        # Set URL
        result = await set_url_on_devices(url, [device_id])
        print(f"Set URL result: {json.dumps(result, indent=2)}")

if __name__ == "__main__":
    asyncio.run(main()) 