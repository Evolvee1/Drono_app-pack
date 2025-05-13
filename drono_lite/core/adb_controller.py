import logging
import subprocess
import asyncio
import json
import tempfile
import os
import time
import platform
import re
from typing import List, Dict, Optional, Tuple, Any
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

class AdbController:
    """Controller for interacting with Android devices via ADB"""
    
    def __init__(self):
        """Initialize the ADB controller and check if ADB is available"""
        self._check_adb()
        self.package = "com.example.imtbf.debug"
        self.activity = "com.example.imtbf.presentation.activities.MainActivity"
        self.broadcast_action = "com.example.imtbf.debug.COMMAND"
        self.prefs_file = f"/data/data/{self.package}/shared_prefs/instagram_traffic_simulator_prefs.xml"
        self.device_status_cache = {}  # Cache for device status
        self.last_status_update = {}   # Track when status was last updated
        logger.info("ADB Controller initialized in ROOT MODE")
        
    def _check_adb(self):
        """Check if ADB is available"""
        try:
            result = subprocess.run(['adb', 'version'], capture_output=True, text=True, check=True)
            logger.info(f"ADB version: {result.stdout.strip()}")
        except Exception as e:
            logger.error(f"Failed to check ADB: {e}")
            raise RuntimeError("ADB is not installed or not in PATH")
    
    def _escape_shell_string(self, text: str) -> str:
        """Escape a string for shell command usage"""
        # First escape single quotes (replace ' with \')
        escaped = text.replace("'", "\\'")
        return f"'{escaped}'"
    
    def _escape_xml_string(self, text: str) -> str:
        """Escape a string for XML content"""
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;")
            
    def get_devices(self) -> List[Dict]:
        """Get list of connected devices using ADB"""
        try:
            output = subprocess.run(
                ['adb', 'devices', '-l'], 
                capture_output=True, 
                text=True, 
                check=True
            ).stdout
            
            devices = []
            
            # Parse the output
            for line in output.splitlines()[1:]:  # Skip the first line (header)
                if not line.strip():
                    continue
                    
                parts = line.split()
                if len(parts) >= 2:
                    device_id = parts[0]
                    status = parts[1]
                    
                    # Skip devices not in device state
                    if status != "device":
                        continue
                    
                    # Get device model
                    try:
                        model = subprocess.run(
                            ['adb', '-s', device_id, 'shell', 'getprop', 'ro.product.model'],
                            capture_output=True, 
                            text=True, 
                            check=True
                        ).stdout.strip()
                    except Exception:
                        model = "Unknown"
                        
                    # Get battery level
                    try:
                        battery_output = subprocess.run(
                            ['adb', '-s', device_id, 'shell', 'dumpsys', 'battery', '|', 'grep', 'level'],
                            capture_output=True, 
                            text=True, 
                            check=True
                        ).stdout.strip()
                        
                        battery = battery_output.split(':')[1].strip() + '%'
                    except Exception:
                        battery = "Unknown"
                    
                    # We're using root mode for all devices
                    device_info = {
                        'id': device_id,
                        'model': model,
                        'status': 'online',
                        'battery': battery,
                        'has_write_access': True,  # Always true in root mode
                        'has_root_access': True    # Always true in root mode
                    }
                    
                    devices.append(device_info)
            
            return devices
        except Exception as e:
            logger.error(f"Failed to get devices: {e}")
            return []

    def _create_prefs_xml(self, url: str, iterations: int, min_interval: int, max_interval: int, 
                         use_webview: bool = True, rotate_ip: bool = True) -> Tuple[str, str]:
        """Create the XML content for preferences files"""
        timestamp = int(datetime.now().timestamp() * 1000)
        xml_escaped_url = self._escape_xml_string(url)
        
        # Create main preferences XML
        prefs_xml = f"""<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="{str(use_webview).lower()}" />
    <string name="current_session_id">session-{timestamp}</string>
    <string name="target_url">{xml_escaped_url}</string>
    <int name="iterations" value="{iterations}" />
    <int name="min_interval" value="{min_interval}" />
    <int name="max_interval" value="{max_interval}" />
    <boolean name="rotate_ip" value="{str(rotate_ip).lower()}" />
    <boolean name="use_random_device_profile" value="true" />
    <boolean name="new_webview_per_request" value="true" />
    <long name="last_run_timestamp" value="{timestamp}" />
    <boolean name="is_first_run" value="false" />
</map>"""

        # Create URL config XML
        url_config_xml = f"""<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="saved_url">{xml_escaped_url}</string>
    <long name="last_saved_timestamp" value="{timestamp}" />
</map>"""

        return prefs_xml, url_config_xml
    
    def _apply_settings_root_method(self, device_id: str, url: str, iterations: int, 
                                   min_interval: int, max_interval: int, 
                                   use_webview: bool = True, rotate_ip: bool = True) -> bool:
        """Apply settings using root access method"""
        logger.info(f"Applying settings to device {device_id} using ROOT MODE")
        
        try:
            # Generate XML content
            prefs_xml, url_config_xml = self._create_prefs_xml(url, iterations, min_interval, max_interval, use_webview, rotate_ip)
            
            # Create temporary files
            with tempfile.NamedTemporaryFile(suffix="_prefs.xml", delete=False) as prefs_file, \
                 tempfile.NamedTemporaryFile(suffix="_url_config.xml", delete=False) as url_file:
                 
                prefs_filename = prefs_file.name
                url_filename = url_file.name
                
                prefs_file.write(prefs_xml.encode('utf-8'))
                url_file.write(url_config_xml.encode('utf-8'))
            
            # Get base filenames
            prefs_base = os.path.basename(prefs_filename)
            url_base = os.path.basename(url_filename)
            
            # Push to device
            subprocess.run(['adb', '-s', device_id, 'push', prefs_filename, f"/sdcard/{prefs_base}"], check=True)
            subprocess.run(['adb', '-s', device_id, 'push', url_filename, f"/sdcard/{url_base}"], check=True)
            
            # Copy with root 
            # Ensure the app's shared_prefs directory exists
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'mkdir -p /data/data/{self.package}/shared_prefs/'"], check=True)
            
            # Copy the preferences files
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'cp /sdcard/{prefs_base} {self.prefs_file}'"], check=True)
            
            # Set appropriate permissions
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'chmod 660 {self.prefs_file}'"], check=True)
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'chown {self.package}:{self.package} {self.prefs_file}'"], check=True)
            
            # Same for URL config
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'cp /sdcard/{url_base} /data/data/{self.package}/shared_prefs/url_config.xml'"], check=True)
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'chmod 660 /data/data/{self.package}/shared_prefs/url_config.xml'"], check=True)
            subprocess.run(['adb', '-s', device_id, 'shell', 
                           f"su -c 'chown {self.package}:{self.package} /data/data/{self.package}/shared_prefs/url_config.xml'"], check=True)
            
            # Clean up
            os.unlink(prefs_filename)
            os.unlink(url_filename)
            subprocess.run(['adb', '-s', device_id, 'shell', f"rm /sdcard/{prefs_base}"], capture_output=True)
            subprocess.run(['adb', '-s', device_id, 'shell', f"rm /sdcard/{url_base}"], capture_output=True)
            
            # Verify settings
            prefs_check = subprocess.run(['adb', '-s', device_id, 'shell', 
                                         f"su -c 'cat {self.prefs_file}'"], 
                                        capture_output=True, text=True).stdout
            
            success = 'target_url' in prefs_check and (url in prefs_check or self._escape_xml_string(url) in prefs_check)
            if success:
                logger.info(f"Successfully verified settings for device {device_id}")
            else:
                logger.warning(f"Could not verify settings for device {device_id}")
            
            return success
        except Exception as e:
            logger.error(f"Error applying settings with root method: {e}")
            return False

    def distribute_url(self, device_ids: List[str], url: str, iterations: int = 100,
                      min_interval: int = 1, max_interval: int = 2,
                      use_webview: bool = True, rotate_ip: bool = True) -> Dict[str, Dict]:
        """
        Distribute a URL to multiple devices
        
        Args:
            device_ids: List of device IDs 
            url: URL to distribute
            iterations: Number of iterations
            min_interval: Minimum interval (seconds)
            max_interval: Maximum interval (seconds)
            use_webview: Whether to use WebView mode
            rotate_ip: Whether to rotate IP
            
        Returns:
            Dictionary with results for each device
        """
        if not device_ids:
            available_devices = self.get_devices()
            device_ids = [d['id'] for d in available_devices]
            
        if not device_ids:
            return {"error": "No devices available"}
        
        results = {}
        
        for device_id in device_ids:
            # Step 1: Force stop the app
            logger.info(f"Force stopping app on device {device_id}")
            try:
                subprocess.run(
                    ['adb', '-s', device_id, 'shell', f"am force-stop {self.package}"],
                    capture_output=True,
                    check=True
                )
                # Wait for app to fully stop
                time.sleep(2)
            except Exception as e:
                logger.error(f"Failed to stop app on device {device_id}: {e}")
            
            # Step 2: Apply settings using ROOT MODE
            settings_applied = self._apply_settings_root_method(
                device_id, url, iterations, min_interval, max_interval, use_webview, rotate_ip
            )
            
            # Step 3: Start app and apply settings via intents (as backup)
            try:
                # Try multiple approaches to ensure settings are applied
                escaped_url = self._escape_shell_string(url)
                
                # Method 1: Start with intent including all parameters
                logger.info(f"Starting app on device {device_id} with custom_url intent")
                start_cmd = [
                    'adb', '-s', device_id, 'shell', 
                    f"am start -n {self.package}/{self.activity} --es custom_url {escaped_url} --ei iterations {iterations} --ei min_interval {min_interval} --ei max_interval {max_interval} --ez load_from_intent true"
                ]
                
                subprocess.run(start_cmd, capture_output=True, text=True)
                
                # Wait for app to fully start
                time.sleep(2)
                
                # Method 2: Send additional broadcasts to ensure settings are applied
                logger.info(f"Sending broadcast intents to device {device_id}")
                
                # Command broadcast for URL
                subprocess.run([
                    'adb', '-s', device_id, 'shell',
                    f"am broadcast -a {self.package}.COMMAND --es command set_url --es value {escaped_url} -p {self.package}"
                ], capture_output=True)
                
                # SET_URL action broadcast
                subprocess.run([
                    'adb', '-s', device_id, 'shell',
                    f"am broadcast -a {self.package}.SET_URL --es url {escaped_url} -p {self.package}"
                ], capture_output=True)
                
                # Method 3: Try deep linking (useful for some devices)
                import urllib.parse
                encoded_url_for_deep_link = urllib.parse.quote(url)
                
                subprocess.run([
                    'adb', '-s', device_id, 'shell',
                    f"am start -n {self.package}/{self.activity} -a android.intent.action.VIEW -d 'traffic-sim://load_url?url={encoded_url_for_deep_link}&force=true'"
                ], capture_output=True)
                
                # Wait a moment for intents to process
                time.sleep(1)
                
                # Step 4: Send start command
                logger.info(f"Starting simulation on device {device_id}")
                start_result = subprocess.run([
                    'adb', '-s', device_id, 'shell',
                    f"am broadcast -a {self.package}.COMMAND --es command start -p {self.package}"
                ], capture_output=True)
                
                # Verify app is running
                process_id = subprocess.run(
                    ['adb', '-s', device_id, 'shell', f"pidof {self.package}"],
                    capture_output=True,
                    text=True
                ).stdout.strip()
                
                # Check settings after start (helpful debugging)
                current_url = "unknown"
                try:
                    # Check settings using root
                    prefs_check = subprocess.run(['adb', '-s', device_id, 'shell', 
                                               f"su -c 'cat {self.prefs_file}'"], 
                                              capture_output=True, text=True).stdout
                        
                    if 'target_url' in prefs_check:
                        import re
                        match = re.search(r'<string name="target_url">(.*?)</string>', prefs_check)
                        if match:
                            current_url = match.group(1)
                except Exception:
                    pass
                
                # For safety, send a final settings update command
                time.sleep(2)
                subprocess.run([
                    'adb', '-s', device_id, 'shell',
                    f"am broadcast -a {self.package}.COMMAND --es command reload_url --es value {escaped_url} -p {self.package}"
                ], capture_output=True)
                
                results[device_id] = {
                    "success": len(process_id) > 0,
                    "settings_method": "root",
                    "message": f"App is running with PID: {process_id}" if process_id else "Failed to start app",
                    "url": url,
                    "current_url": current_url,
                    "iterations": iterations
                }
                
            except Exception as e:
                logger.error(f"Failed to distribute URL to device {device_id}: {e}")
                results[device_id] = {
                    "success": False,
                    "error": str(e)
                }
        
        return results

    async def execute_command(self, device_id: str, command: str, params: Dict = None) -> Dict:
        """
        Execute a command on a device
        
        Args:
            device_id: Device ID
            command: Command to execute (start, stop, pause, resume)
            params: Command parameters
            
        Returns:
            Dictionary with command result
        """
        params = params or {}
        
        if command == "start":
            # For start command, call the distribute_url with single device ID
            url = params.get("url", "https://example.com")
            iterations = params.get("iterations", 100)
            min_interval = params.get("min_interval", 1)
            max_interval = params.get("max_interval", 2)
            use_webview = params.get("use_webview", True)
            rotate_ip = params.get("rotate_ip", True)
            
            # Use the distribute_url method to ensure best compatibility
            result = self.distribute_url(
                [device_id], url, iterations, min_interval, max_interval, use_webview, rotate_ip
            )
            
            # Convert to expected format
            device_result = result.get(device_id, {})
            return {
                "success": device_result.get("success", False),
                "command": command,
                "device_id": device_id,
                "result": device_result
            }
                
        elif command == "stop":
            # Stop app
            try:
                stop_cmd = [
                    'adb', '-s', device_id, 'shell',
                    f"am force-stop {self.package}"
                ]
                
                process = await asyncio.create_subprocess_exec(
                    *stop_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await process.communicate()
                
                return {
                    "success": process.returncode == 0,
                    "command": command,
                    "device_id": device_id,
                    "stdout": stdout.decode('utf-8', errors='replace'),
                    "stderr": stderr.decode('utf-8', errors='replace')
                }
                
            except Exception as e:
                logger.error(f"Failed to execute command {command} on device {device_id}: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "command": command,
                    "device_id": device_id
                }
                
        else:
            # Other commands send via broadcast
            action_map = {
                "pause": "pause",
                "resume": "resume",
                "reload": "reload_url"
            }
            
            action = action_map.get(command, command)
            
            try:
                # Build command with any parameters
                broadcast_params = ""
                for key, value in params.items():
                    if isinstance(value, bool):
                        broadcast_params += f" --ez {key} {str(value).lower()}"
                    elif isinstance(value, int):
                        broadcast_params += f" --ei {key} {value}"
                    else:
                        # Escape string values
                        escaped_value = self._escape_shell_string(str(value))
                        broadcast_params += f" --es {key} {escaped_value}"
                
                broadcast_cmd = [
                    'adb', '-s', device_id, 'shell',
                    f"am broadcast -a {self.package}.COMMAND --es command {action}{broadcast_params} -p {self.package}"
                ]
                
                process = await asyncio.create_subprocess_exec(
                    *broadcast_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                
                stdout, stderr = await process.communicate()
                
                return {
                    "success": process.returncode == 0,
                    "command": command,
                    "device_id": device_id,
                    "stdout": stdout.decode('utf-8', errors='replace'),
                    "stderr": stderr.decode('utf-8', errors='replace')
                }
                
            except Exception as e:
                logger.error(f"Failed to execute command {command} on device {device_id}: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "command": command,
                    "device_id": device_id
                }

    def get_device_status(self, device_id: str) -> Dict:
        """
        Get detailed status information from a device
        
        Args:
            device_id: Device ID
            
        Returns:
            Dictionary with device status information
        """
        # Check cache to avoid too frequent updates (once per second max)
        current_time = time.time()
        if (device_id in self.last_status_update and 
            current_time - self.last_status_update.get(device_id, 0) < 1.0 and
            device_id in self.device_status_cache):
            return self.device_status_cache[device_id]
            
        logger.info(f"Fetching status for device {device_id}")
        
        # Initialize with default values
        status_info = {
            "device_id": device_id,
            "is_running": False,
            "current_iteration": 0,
            "total_iterations": 0,
            "percentage": 0,
            "url": "",
            "min_interval": 0,
            "max_interval": 0,
            "elapsed_time": 0,
            "estimated_remaining": 0,
            "status": "idle",
            "last_update": datetime.now().isoformat()
        }
        
        try:
            # Check if app is running
            process_id = subprocess.run(
                ['adb', '-s', device_id, 'shell', f"pidof {self.package}"],
                capture_output=True,
                text=True
            ).stdout.strip()
            
            if not process_id:
                status_info["status"] = "stopped"
                self.device_status_cache[device_id] = status_info
                self.last_status_update[device_id] = current_time
                return status_info
                
            # App is running, get detailed status
            # Method 1: Check from preferences file
            try:
                # Get setting information using root access
                prefs_check = subprocess.run(['adb', '-s', device_id, 'shell', 
                                             f"su -c 'cat {self.prefs_file}'"], 
                                            capture_output=True, text=True).stdout
                
                # Extract values
                is_running_match = re.search(r'<boolean name="is_running" value="([^"]+)"', prefs_check)
                iterations_match = re.search(r'<int name="iterations" value="([^"]+)"', prefs_check)
                current_iter_match = re.search(r'<int name="current_iteration" value="([^"]+)"', prefs_check)
                url_match = re.search(r'<string name="target_url">([^<]+)</string>', prefs_check)
                min_interval_match = re.search(r'<int name="min_interval" value="([^"]+)"', prefs_check)
                max_interval_match = re.search(r'<int name="max_interval" value="([^"]+)"', prefs_check)
                start_time_match = re.search(r'<long name="simulation_start_time" value="([^"]+)"', prefs_check)
                
                # Update status with extracted values
                if is_running_match:
                    status_info["is_running"] = is_running_match.group(1).lower() == "true"
                    status_info["status"] = "running" if status_info["is_running"] else "paused"
                
                if iterations_match:
                    status_info["total_iterations"] = int(iterations_match.group(1))
                
                if current_iter_match:
                    status_info["current_iteration"] = int(current_iter_match.group(1))
                
                if url_match:
                    status_info["url"] = url_match.group(1)
                
                if min_interval_match:
                    status_info["min_interval"] = int(min_interval_match.group(1))
                
                if max_interval_match:
                    status_info["max_interval"] = int(max_interval_match.group(1))
                
                # Calculate progress percentage
                if status_info["total_iterations"] > 0 and status_info["current_iteration"] > 0:
                    status_info["percentage"] = round(
                        (status_info["current_iteration"] / status_info["total_iterations"]) * 100, 1
                    )
                
                # Calculate elapsed time and estimated remaining time
                if start_time_match:
                    start_time = int(start_time_match.group(1)) / 1000  # Convert from milliseconds
                    current_time_ms = int(time.time())
                    status_info["elapsed_time"] = current_time_ms - start_time
                    
                    # Estimate remaining time based on elapsed time and progress
                    if status_info["current_iteration"] > 0 and status_info["is_running"]:
                        time_per_iteration = status_info["elapsed_time"] / status_info["current_iteration"]
                        remaining_iterations = status_info["total_iterations"] - status_info["current_iteration"]
                        status_info["estimated_remaining"] = round(time_per_iteration * remaining_iterations)
            except Exception as e:
                logger.debug(f"Error extracting from preferences: {e}")
                
            # Method 2: Try to get progress from UI
            if status_info["current_iteration"] == 0:
                try:
                    # Check if there's a progress TextView visible
                    ui_dump = subprocess.run(
                        ['adb', '-s', device_id, 'shell', "dumpsys activity top | grep tvProgress"],
                        capture_output=True,
                        text=True
                    ).stdout
                    
                    progress_match = re.search(r'Progress: (\d+)/(\d+)', ui_dump)
                    if progress_match:
                        status_info["current_iteration"] = int(progress_match.group(1))
                        status_info["total_iterations"] = int(progress_match.group(2))
                        
                        if status_info["total_iterations"] > 0:
                            status_info["percentage"] = round(
                                (status_info["current_iteration"] / status_info["total_iterations"]) * 100, 1
                            )
                except Exception as e:
                    logger.debug(f"Error getting progress from UI: {e}")
            
            # Method 3: Try to get progress from logcat
            if status_info["current_iteration"] == 0:
                try:
                    logcat_output = subprocess.run(
                        ['adb', '-s', device_id, 'logcat', '-d', '-t', '20', '-v', 'brief', 
                         f"{self.package}:I", "*:S", '|', 'grep', '-i', "Progress"],
                        capture_output=True,
                        text=True,
                        shell=True
                    ).stdout
                    
                    progress_match = re.search(r'Progress: (\d+)/(\d+)', logcat_output)
                    if progress_match:
                        status_info["current_iteration"] = int(progress_match.group(1))
                        status_info["total_iterations"] = int(progress_match.group(2))
                        
                        if status_info["total_iterations"] > 0:
                            status_info["percentage"] = round(
                                (status_info["current_iteration"] / status_info["total_iterations"]) * 100, 1
                            )
                except Exception as e:
                    logger.debug(f"Error getting progress from logcat: {e}")
            
            # Update cache and return status
            self.device_status_cache[device_id] = status_info
            self.last_status_update[device_id] = current_time
            return status_info
            
        except Exception as e:
            logger.error(f"Failed to get device status: {e}")
            return status_info
    
    async def get_all_devices_status(self) -> Dict[str, Dict]:
        """
        Get status for all connected devices
        
        Returns:
            Dictionary mapping device IDs to status information
        """
        devices = self.get_devices()
        results = {}
        
        for device in devices:
            device_id = device["id"]
            status = self.get_device_status(device_id)
            results[device_id] = status
            
        return results

# Create global instance
adb_controller = AdbController() 