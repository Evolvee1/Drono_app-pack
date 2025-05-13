#!/usr/bin/env python3
"""
Instagram Manager - Unified module for managing Instagram URL configuration
This module provides a centralized way to handle Instagram URL settings across devices
"""
import os
import sys
import logging
import asyncio
import time
import xml.etree.ElementTree as ET
from typing import List, Dict, Any, Optional

# Configure logging
logger = logging.getLogger("core.instagram_manager")

# Constants
PACKAGE_NAME = "com.example.imtbf.debug"
PREFS_FILE = f"/data/data/{PACKAGE_NAME}/shared_prefs/instagram_traffic_simulator_prefs.xml"
URL_CONFIG_FILE_NAME = "url_config.xml"
MAIN_PREFS_FILE_NAME = "instagram_traffic_simulator_prefs.xml"
BROADCAST_ACTION = f"{PACKAGE_NAME}.COMMAND"

# Ensure we have a place to store temporary files
TEMP_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "temp")
os.makedirs(TEMP_DIR, exist_ok=True)

URL_CONFIG_PATH = os.path.join(TEMP_DIR, URL_CONFIG_FILE_NAME)
MAIN_PREFS_PATH = os.path.join(TEMP_DIR, MAIN_PREFS_FILE_NAME)

class DeviceNotConnectedError(Exception):
    """Exception raised when a device is not connected"""
    pass

class DeviceInfo:
    """Class representing device information"""
    def __init__(self, id: str, model: str = "Unknown", status: str = "unknown"):
        self.id = id
        self.model = model
        self.status = status
    
    def to_dict(self) -> Dict[str, str]:
        """Convert to dictionary"""
        return {
            "id": self.id,
            "model": self.model,
            "status": self.status
        }

class InstagramManager:
    """Unified manager for Instagram URL settings"""
    
    def __init__(self):
        """Initialize the Instagram manager"""
        self._devices_cache = []
        self._devices_cache_time = 0
        self._cache_valid_time = 5  # Cache valid for 5 seconds
    
    async def get_connected_devices(self) -> List[DeviceInfo]:
        """Get a list of connected devices"""
        # Use cache if it's still valid
        if time.time() - self._devices_cache_time < self._cache_valid_time and self._devices_cache:
            return self._devices_cache
        
        try:
            # Run ADB devices command
            process = await asyncio.create_subprocess_exec(
                "adb", "devices", "-l",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"ADB devices command failed: {stderr.decode()}")
                return []
            
            # Parse output
            lines = stdout.decode().strip().split('\n')[1:]  # Skip header
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
                    
                    devices.append(DeviceInfo(id=device_id, model=model, status="connected"))
            
            # Update cache
            self._devices_cache = devices
            self._devices_cache_time = time.time()
            
            return devices
        except Exception as e:
            logger.error(f"Error getting connected devices: {e}")
            return []
    
    async def force_stop_app(self, device_id: str) -> bool:
        """Force stop the app on the device"""
        try:
            process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell", "am", "force-stop", PACKAGE_NAME,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"Failed to force stop app on {device_id}: {stderr.decode()}")
                return False
            
            logger.info(f"Successfully force stopped app on {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error force stopping app on {device_id}: {e}")
            return False
    
    async def check_access_method(self, device_id: str) -> str:
        """Check which access method can be used (root, run-as, or none)"""
        # Check run-as access
        run_as_process = await asyncio.create_subprocess_exec(
            "adb", "-s", device_id, "shell", f"run-as {PACKAGE_NAME} ls",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, _ = await run_as_process.communicate()
        
        if run_as_process.returncode == 0:
            return "run-as"
        
        # Check root access
        root_process = await asyncio.create_subprocess_exec(
            "adb", "-s", device_id, "shell", "su -c 'id'",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, _ = await root_process.communicate()
        
        if root_process.returncode == 0 and "uid=0" in stdout.decode():
            return "root"
        
        return "none"
    
    async def create_url_config_file(self, url: str) -> bool:
        """Create a URL config file with the specified URL in the exact format needed"""
        try:
            # Create XML content directly with the exact format expected by the app
            # The app expects the URL value to be quoted correctly in the XML
            content = f"""<?xml version="1.0" encoding="utf-8" ?>
<map>
<string name="instagram_url">{url}</string>
<string name="url_source">external</string>
<long name="url_timestamp">{int(time.time() * 1000000000)}</long>
</map>
"""
            # Write to file
            with open(URL_CONFIG_PATH, 'w') as f:
                f.write(content)
            
            logger.info(f'Created URL config file with URL: "{url}"')
            return True
        except Exception as e:
            logger.error(f"Error creating URL config file: {e}")
            return False
    
    async def create_main_prefs_file(self, iterations: int, min_interval: int, max_interval: int, delay: int = 3000, url: str = None) -> bool:
        """Create a main preferences file with specified settings"""
        try:
            # Create the XML structure
            root = ET.Element("map")
            
            # Add integer settings elements
            int_settings = {
                "iterations": iterations,
                "min_interval": min_interval,
                "max_interval": max_interval,
                "airplane_mode_delay": delay,
                "delay_min": 1,
                "delay_max": 5
            }
            
            for name, value in int_settings.items():
                element = ET.SubElement(root, "int")
                element.set("name", name)
                element.set("value", str(value))
            
            # Add boolean settings with proper names matching drono_control.sh
            boolean_settings = {
                "is_running": "false",
                "is_first_run": "false",
                "rotate_ip": "true",
                "use_webview_mode": "true",
                "use_random_device_profile": "true", 
                "new_webview_per_request": "true",
                "handle_marketing_redirects": "true"
            }
            
            for name, value in boolean_settings.items():
                element = ET.SubElement(root, "boolean")
                element.set("name", name)
                element.set("value", value)
            
            # Add the target_url as string field if provided
            if url:
                url_element = ET.SubElement(root, "string")
                url_element.set("name", "target_url")
                url_element.text = url
            
            # Create the tree and save
            tree = ET.ElementTree(root)
            tree.write(MAIN_PREFS_PATH, encoding="utf-8", xml_declaration=True)
            
            logger.info(f"Created main preferences file with iterations={iterations}, min_interval={min_interval}, max_interval={max_interval}")
            return True
        except Exception as e:
            logger.error(f"Error creating main preferences file: {e}")
            return False
    
    async def push_config_file(self, device_id: str, access_method: str) -> bool:
        """Push the URL config file to the device"""
        try:
            # Push to a temporary location first
            temp_file = f"/data/local/tmp/url_config_{int(time.time())}.xml"
            push_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "push", URL_CONFIG_PATH, temp_file,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await push_process.communicate()
            
            if push_process.returncode != 0:
                logger.error(f"Failed to push config file to {device_id}: {stderr.decode()}")
                return False
            
            # Move to final location based on access method
            if access_method == "root":
                target_path = f"/data/data/{PACKAGE_NAME}/shared_prefs/{URL_CONFIG_FILE_NAME}"
                move_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", device_id, "shell", "su", "-c", 
                    f"cp {temp_file} {target_path} && chmod 660 {target_path} && chown {PACKAGE_NAME}:{PACKAGE_NAME} {target_path}",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
            elif access_method == "run-as":
                move_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} cp {temp_file} /data/data/{PACKAGE_NAME}/shared_prefs/{URL_CONFIG_FILE_NAME}",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
            else:
                logger.error(f"No valid access method for {device_id}")
                return False
            
            _, stderr = await move_process.communicate()
            
            if move_process.returncode != 0:
                logger.error(f"Failed to move config file on {device_id}: {stderr.decode()}")
                return False
            
            logger.info(f"Successfully pushed config file to {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error pushing config file to {device_id}: {e}")
            return False
    
    async def push_main_prefs_file(self, device_id: str, access_method: str) -> bool:
        """Push the main preferences file to the device"""
        try:
            # Push to a temporary location first
            temp_file = f"/data/local/tmp/main_prefs_{int(time.time())}.xml"
            push_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "push", MAIN_PREFS_PATH, temp_file,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await push_process.communicate()
            
            if push_process.returncode != 0:
                logger.error(f"Failed to push main preferences file to {device_id}: {stderr.decode()}")
                return False
            
            # Move to final location based on access method
            target_file = f"/data/data/{PACKAGE_NAME}/shared_prefs/{MAIN_PREFS_FILE_NAME}"
            if access_method == "root":
                move_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", device_id, "shell", "su", "-c", 
                    f"cp {temp_file} {target_file} && chmod 660 {target_file} && chown {PACKAGE_NAME}:{PACKAGE_NAME} {target_file}",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
            elif access_method == "run-as":
                move_process = await asyncio.create_subprocess_exec(
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} cp {temp_file} {target_file}",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
            else:
                logger.error(f"No valid access method for {device_id}")
                return False
            
            _, stderr = await move_process.communicate()
            
            if move_process.returncode != 0:
                logger.error(f"Failed to move main preferences file on {device_id}: {stderr.decode()}")
                return False
            
            logger.info(f"Successfully pushed main preferences file to {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error pushing main preferences file to {device_id}: {e}")
            return False
    
    async def send_broadcast_command(self, device_id: str, url: str, webview_mode: bool, 
                                  new_webview_per_request: bool, rotate_ip: bool = True,
                                  random_devices: bool = True) -> bool:
        """Send broadcast commands to set URL and features"""
        try:
            # Send URL command - using command=set_target_url with url parameter
            # For URLs with special characters, we need to properly escape and quote
            escaped_url = url.replace('"', '\\"').replace('$', '\\$')
            url_cmd = [
                "adb", "-s", device_id, "shell", "am", "broadcast",
                "-a", BROADCAST_ACTION,
                "-e", "command", "set_target_url",
                "-e", "url", f'"{escaped_url}"'  # Quote the URL to preserve special characters
            ]
            
            # Add package parameter
            if PACKAGE_NAME:
                url_cmd.extend(["-p", PACKAGE_NAME])
            
            process = await asyncio.create_subprocess_exec(
                *url_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"Failed to send URL broadcast to {device_id}: {stderr.decode()}")
                return False
            
            # Feature mapping to match drono_control.sh
            feature_mapping = {
                "webview_mode": "use_webview_mode",
                "new_webview_per_request": "new_webview_per_request",
                "rotate_ip": "rotate_ip",
                "random_devices": "use_random_device_profile"
            }
            
            # Send feature toggles with the correct feature names
            features = {
                "webview_mode": webview_mode,
                "new_webview_per_request": new_webview_per_request,
                "rotate_ip": rotate_ip,
                "random_devices": random_devices
            }
            
            for feature, value in features.items():
                mapped_feature = feature_mapping.get(feature, feature)
                feature_cmd = [
                    "adb", "-s", device_id, "shell", "am", "broadcast",
                    "-a", BROADCAST_ACTION,
                    "-e", "command", "toggle_feature",
                    "-e", "feature", mapped_feature,  # Use mapped feature name for broadcast
                    "-e", "value", str(value).lower()
                ]
                
                if PACKAGE_NAME:
                    feature_cmd.extend(["-p", PACKAGE_NAME])
                
                feature_process = await asyncio.create_subprocess_exec(
                    *feature_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await feature_process.communicate()
            
            logger.info(f"Successfully sent all broadcast commands to {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error sending broadcast command to {device_id}: {e}")
            return False
    
    async def start_app_with_url(self, device_id: str, url: str) -> bool:
        """Start the app with a direct URL intent"""
        try:
            # Escape special characters that would break the shell command
            escaped_url = url.replace('"', '\\"').replace('$', '\\$')
            
            # Construct the command
            cmd = [
                "adb", "-s", device_id, "shell", "am", "start",
                "-n", f"{PACKAGE_NAME}/com.example.imtbf.presentation.activities.MainActivity",
                "-e", "direct_url", f'"{escaped_url}"'  # Quote URL to preserve special characters
            ]
            
            # Execute the command
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"Failed to start app with URL on {device_id}: {stderr.decode()}")
                return False
            
            # Wait to ensure the app has time to start
            await asyncio.sleep(3)
            
            logger.info(f"Successfully started app with direct URL on {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error starting app with URL on {device_id}: {e}")
            return False
    
    async def verify_url_loaded(self, device_id: str, url: str) -> bool:
        """Verify the URL was loaded correctly"""
        try:
            # Clear logcat first
            clear_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "logcat", "-c",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await clear_process.communicate()
            
            # Wait a moment for app to process
            await asyncio.sleep(3)
            
            # Get logcat output
            logcat_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "logcat", "-d", "WebViewActivity:I", "*:S",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await logcat_process.communicate()
            
            log_output = stdout.decode()
            
            # Check if our URL is in the log
            url_base = url.split("?")[0] if "?" in url else url
            
            if "Loading URL" in log_output and (url in log_output or url_base in log_output):
                logger.info(f"Verified URL loaded on {device_id}")
                return True
            
            # Alternative: check for WebView processes
            webview_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell", "ps | grep webview",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await webview_process.communicate()
            
            if PACKAGE_NAME in stdout.decode() or "sandboxed_process" in stdout.decode():
                logger.info(f"Verified WebView process is running on {device_id}")
                return True
            
            logger.warning(f"Could not verify URL loaded on {device_id}")
            return False
        except Exception as e:
            logger.error(f"Error verifying URL loaded on {device_id}: {e}")
            return False
    
    async def set_instagram_url(self, device_id: str, url: str, webview_mode: bool = True, 
                             new_webview_per_request: bool = True, rotate_ip: bool = True,
                             random_devices: bool = True, iterations: int = 100, 
                             min_interval: int = 3, max_interval: int = 5,
                             delay: int = 3000) -> Dict[str, Any]:
        """Set the Instagram URL using multiple approaches for reliability"""
        result = {
            "device_id": device_id,
            "success": False,
            "message": "",
            "details": {}
        }
        
        try:
            # Check if device exists
            devices = await self.get_connected_devices()
            if not any(d.id == device_id for d in devices):
                result["message"] = f"Device {device_id} not found"
                return result
            
            # Step 1: Force stop the app first
            logger.info(f"Step 1: Force stopping app on {device_id}")
            if not await self.force_stop_app(device_id):
                result["message"] = "Failed to force stop app"
                return result
            
            # Step 2: Check access method
            logger.info(f"Step 2: Checking access method for {device_id}")
            access_method = await self.check_access_method(device_id)
            if access_method == "none":
                logger.warning(f"No direct file access available for {device_id}, using broadcast only")
            
            # Step 3: Create URL config file with instagram_url field
            logger.info(f"Step 3: Creating URL config for {device_id}")
            if not await self.create_url_config_file(url):
                logger.warning("Failed to create URL config file, continuing anyway")
            
            # Step 4: Create main preferences file with iterations and intervals
            logger.info(f"Step 4: Creating main preferences file for {device_id}")
            if not await self.create_main_prefs_file(iterations, min_interval, max_interval, delay, url):
                logger.warning("Failed to create main preferences file, continuing anyway")
            
            # Step 5: Push config files if possible
            if access_method != "none":
                logger.info(f"Step 5a: Pushing URL config to {device_id}")
                await self.push_config_file(device_id, access_method)
                
                logger.info(f"Step 5b: Pushing main preferences to {device_id}")
                await self.push_main_prefs_file(device_id, access_method)
                
                # Step 5c: Direct update of target_url using our new direct method
                logger.info(f"Step 5c: Directly setting target_url in preferences file")
                if not await self.set_target_url_directly(device_id, url):
                    logger.warning("Direct setting of target_url may not have worked, continuing anyway")
            
            # Step 6: Send broadcast commands for URL and settings
            logger.info(f"Step 6: Sending broadcast commands to {device_id}")
            if not await self.send_broadcast_command(
                device_id, url, webview_mode, new_webview_per_request, rotate_ip, random_devices
            ):
                logger.warning("Broadcast commands may not have been successful, continuing anyway")
            
            # Step 7: Start app with direct URL intent
            logger.info(f"Step 7: Starting app with direct URL on {device_id}")
            if not await self.start_app_with_url(device_id, url):
                result["message"] = "Failed to start app with URL"
                return result
            
            # Step 8: Verify URL loaded
            logger.info(f"Step 8: Verifying URL loaded on {device_id}")
            
            # Use the more thorough verification method
            # This will attempt to extract the actual URL from the WebView
            url_loaded = await self.verify_with_actual_url(device_id, url)
            
            if url_loaded:
                result["success"] = True
                result["message"] = "URL successfully set and verified"
            else:
                result["message"] = "URL set but could not verify loading"
                # Still mark as partial success
                result["success"] = True
            
            # Additional step: Check what URL is actually in the preferences file 
            # This will highlight the behavior where the app resets to default
            if access_method != "none":
                logger.info(f"Step 9: Checking persisted target_url value in preferences")
                
                verify_cmd = None
                if access_method == "root":
                    verify_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"su -c 'cat {PREFS_FILE} | grep \"target_url\"'"
                    ]
                else:
                    verify_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"run-as {PACKAGE_NAME} cat {PREFS_FILE} | grep \"target_url\""
                    ]
                
                verify_process = await asyncio.create_subprocess_exec(
                    *verify_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, _ = await verify_process.communicate()
                persisted_url = stdout.decode().strip()
                
                result["details"]["persisted_target_url"] = persisted_url
                
                # Also get the actual WebView URL 
                actual_url = await self.get_actual_webview_url(device_id)
                if actual_url:
                    result["details"]["actual_webview_url"] = actual_url
            
            # Add details about the settings that were applied
            result["details"].update({
                "url": url,
                "iterations": iterations,
                "min_interval": min_interval,
                "max_interval": max_interval,
                "webview_mode": webview_mode,
                "new_webview_per_request": new_webview_per_request,
                "rotate_ip": rotate_ip,
                "random_devices": random_devices,
                "delay": delay
            })
            
            return result
        except Exception as e:
            logger.error(f"Error setting Instagram URL on {device_id}: {e}")
            result["message"] = f"Error: {str(e)}"
            return result
    
    async def restart_app(self, device_id: str) -> bool:
        """Restart the app on the device"""
        try:
            # Force stop first
            if not await self.force_stop_app(device_id):
                return False
                
            # Start the app
            start_cmd = [
                "adb", "-s", device_id, "shell", "am", "start",
                "-n", f"{PACKAGE_NAME}/com.example.imtbf.presentation.activities.MainActivity"
            ]
            
            process = await asyncio.create_subprocess_exec(
                *start_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.error(f"Failed to start app on {device_id}: {stderr.decode()}")
                return False
            
            logger.info(f"Successfully restarted app on {device_id}")
            return True
        except Exception as e:
            logger.error(f"Error restarting app on {device_id}: {e}")
            return False

    async def update_string_preference(self, device_id: str, name: str, value: str, access_method: str) -> bool:
        """Update a string preference in the preferences file, exactly matching drono_control.sh behavior"""
        try:
            logger.info(f"Updating {name} to {value}...")
            
            # Escape special characters for sed (match what drono_control.sh does)
            # In bash this is: local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
            escaped_value = value.replace('/', '\\/').replace('&', '\\&')
            
            # Use the shell commands based on access method
            if access_method == "root":
                # First check if the preference exists (similar to drono_control.sh)
                check_cmd = [
                    "adb", "-s", device_id, "shell", 
                    f"su -c 'grep -q \"<string name=\\\"{name}\\\"\" {PREFS_FILE}'"
                ]
                
                check_process = await asyncio.create_subprocess_exec(
                    *check_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await check_process.communicate()
                
                if check_process.returncode == 0:
                    # The key exists, update it
                    update_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"su -c 'sed -i \"s|<string name=\\\"{name}\\\">[^<]*</string>|<string name=\\\"{name}\\\">{escaped_value}</string>|g\" {PREFS_FILE}'"
                    ]
                    
                    update_process = await asyncio.create_subprocess_exec(
                        *update_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    await update_process.communicate()
                else:
                    logger.warning(f"String preference {name} not found in {PREFS_FILE}")
                    return False
            elif access_method == "run-as":
                # Run-as method for debug builds
                check_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} grep -q \"<string name=\\\"{name}\\\"\" {PREFS_FILE}"
                ]
                
                check_process = await asyncio.create_subprocess_exec(
                    *check_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await check_process.communicate()
                
                if check_process.returncode == 0:
                    # The key exists, update it with exact same pattern as drono_control.sh
                    update_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"run-as {PACKAGE_NAME} sed -i \"s|<string name=\\\"{name}\\\">[^<]*</string>|<string name=\\\"{name}\\\">{escaped_value}</string>|g\" {PREFS_FILE}"
                    ]
                    
                    update_process = await asyncio.create_subprocess_exec(
                        *update_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    await update_process.communicate()
                else:
                    logger.warning(f"String preference {name} not found in {PREFS_FILE}")
                    return False
            else:
                logger.error(f"No valid access method for {device_id}")
                return False
            
            # Verify the change like drono_control.sh does
            verify_cmd = None
            if access_method == "root":
                verify_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"su -c 'cat {PREFS_FILE} | grep \"<string name=\\\"{name}\\\"\"'"
                ]
            else:
                verify_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} cat {PREFS_FILE} | grep \"<string name=\\\"{name}\\\"\""
                ]
            
            verify_process = await asyncio.create_subprocess_exec(
                *verify_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await verify_process.communicate()
            
            output = stdout.decode().strip()
            
            if value in output:
                logger.info(f"Verified: {name} is now set to {value}")
                return True
            else:
                logger.warning(f"Could not verify {name} was set to {value}")
                return False
        except Exception as e:
            logger.error(f"Error updating string preference {name} on {device_id}: {e}")
            return False

    async def set_target_url_directly(self, device_id: str, url: str) -> bool:
        """Use direct ADB shell command to set target_url like drono_control.sh does"""
        try:
            logger.info(f"Using direct method to set target_url to {url}")
            
            # Check access method first
            access_method = await self.check_access_method(device_id)
            if access_method == "none":
                logger.error("No valid access method available")
                return False
                
            # Double escape special characters for sed
            # First for shell interpretation, then for sed itself
            escaped_url = url.replace('\\', '\\\\').replace('/', '\\/').replace('&', '\\&').replace("'", "\\'").replace('"', '\\"')
            
            # Create temp file with the exact XML content we want
            temp_xml = f"""<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="target_url">{url}</string>
</map>"""
            
            # Use temp file path on device
            temp_file_path = f"/data/local/tmp/target_url_{int(time.time())}.xml"
            
            # First create a temp file with just the target_url
            echo_cmd = [
                "adb", "-s", device_id, "shell",
                f"echo '{temp_xml}' > {temp_file_path}"
            ]
            
            echo_process = await asyncio.create_subprocess_exec(
                *echo_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            _, stderr = await echo_process.communicate()
            
            if echo_process.returncode != 0:
                logger.error(f"Failed to create temp file: {stderr.decode()}")
                return False
                
            # Extract value using grep/sed
            if access_method == "root":
                # Use root access to update the file using the grep/sed method
                # First check if target_url already exists
                check_cmd = [
                    "adb", "-s", device_id, "shell", 
                    f"su -c 'grep -q \"target_url\" {PREFS_FILE}'"
                ]
                
                check_process = await asyncio.create_subprocess_exec(
                    *check_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await check_process.communicate()
                
                if check_process.returncode == 0:
                    # Extract the target_url line from our temp file
                    grep_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"grep 'target_url' {temp_file_path} | tr -d '\\r'"
                    ]
                    
                    grep_process = await asyncio.create_subprocess_exec(
                        *grep_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, _ = await grep_process.communicate()
                    target_line = stdout.decode().strip()
                    
                    # Now update the existing line with our new target_url line
                    update_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"su -c 'sed -i \"s|<string name=\\\"target_url\\\">[^<]*</string>|{target_line}|g\" {PREFS_FILE}'"
                    ]
                    
                    update_process = await asyncio.create_subprocess_exec(
                        *update_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    _, stderr = await update_process.communicate()
                    
                    if update_process.returncode != 0:
                        logger.error(f"Failed to update target_url: {stderr.decode()}")
                        return False
                else:
                    # Key doesn't exist, need to add it using our extracted line
                    grep_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"grep 'target_url' {temp_file_path} | tr -d '\\r'"
                    ]
                    
                    grep_process = await asyncio.create_subprocess_exec(
                        *grep_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, _ = await grep_process.communicate()
                    target_line = stdout.decode().strip()
                    
                    add_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"su -c 'sed -i \"/<\\/map>/i\\    {target_line}\" {PREFS_FILE}'"
                    ]
                    
                    add_process = await asyncio.create_subprocess_exec(
                        *add_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    _, stderr = await add_process.communicate()
                    
                    if add_process.returncode != 0:
                        logger.error(f"Failed to add target_url: {stderr.decode()}")
                        return False
                
                # Fix permissions
                fix_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"su -c 'chmod 660 {PREFS_FILE} && chown {PACKAGE_NAME}:{PACKAGE_NAME} {PREFS_FILE}'"
                ]
                
                await asyncio.create_subprocess_exec(*fix_cmd)
                
            elif access_method == "run-as":
                # Use run-as with the same approach
                check_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} grep -q \"target_url\" {PREFS_FILE}"
                ]
                
                check_process = await asyncio.create_subprocess_exec(
                    *check_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                await check_process.communicate()
                
                if check_process.returncode == 0:
                    # Extract the target_url line from our temp file
                    grep_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"grep 'target_url' {temp_file_path} | tr -d '\\r'"
                    ]
                    
                    grep_process = await asyncio.create_subprocess_exec(
                        *grep_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, _ = await grep_process.communicate()
                    target_line = stdout.decode().strip()
                    
                    update_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"run-as {PACKAGE_NAME} sed -i \"s|<string name=\\\"target_url\\\">[^<]*</string>|{target_line}|g\" {PREFS_FILE}"
                    ]
                    
                    update_process = await asyncio.create_subprocess_exec(
                        *update_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    _, stderr = await update_process.communicate()
                    
                    if update_process.returncode != 0:
                        logger.error(f"Failed to update target_url: {stderr.decode()}")
                        return False
                else:
                    # Key doesn't exist, need to add it
                    grep_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"grep 'target_url' {temp_file_path} | tr -d '\\r'"
                    ]
                    
                    grep_process = await asyncio.create_subprocess_exec(
                        *grep_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, _ = await grep_process.communicate()
                    target_line = stdout.decode().strip()
                    
                    add_cmd = [
                        "adb", "-s", device_id, "shell",
                        f"run-as {PACKAGE_NAME} sed -i \"/<\\/map>/i\\    {target_line}\" {PREFS_FILE}"
                    ]
                    
                    add_process = await asyncio.create_subprocess_exec(
                        *add_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    _, stderr = await add_process.communicate()
                    
                    if add_process.returncode != 0:
                        logger.error(f"Failed to add target_url: {stderr.decode()}")
                        return False
            
            # Clean up temp file
            cleanup_cmd = [
                "adb", "-s", device_id, "shell",
                f"rm {temp_file_path}"
            ]
            
            await asyncio.create_subprocess_exec(*cleanup_cmd)
            
            # Verify the change
            verify_cmd = None
            if access_method == "root":
                verify_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"su -c 'cat {PREFS_FILE} | grep \"target_url\"'"
                ]
            else:
                verify_cmd = [
                    "adb", "-s", device_id, "shell",
                    f"run-as {PACKAGE_NAME} cat {PREFS_FILE} | grep \"target_url\""
                ]
            
            verify_process = await asyncio.create_subprocess_exec(
                *verify_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await verify_process.communicate()
            
            output = stdout.decode().strip()
            
            if url in output:
                logger.info(f"Verified: target_url is set to {url}")
                return True
            else:
                logger.warning(f"Could not verify target_url was set to {url}")
                logger.warning(f"Found: {output}")
                
                # Check if URL is in output with different escaping
                clean_url = url.split('?')[0] if '?' in url else url
                if clean_url in output:
                    logger.info(f"Verified base URL part: {clean_url}")
                    return True
                return False
        except Exception as e:
            logger.error(f"Error setting target_url on {device_id}: {e}")
            return False

    async def get_actual_webview_url(self, device_id: str) -> str:
        """Extract the actual URL loaded in the WebView by looking at the WebView's page load data"""
        try:
            # First force a WebView debug output by triggering a dump
            dump_cmd = [
                "adb", "-s", device_id, "shell", 
                "dumpsys webviewupdate | grep 'Current WebView package'"
            ]
            
            await asyncio.create_subprocess_exec(*dump_cmd)
            
            # Clear logcat first
            clear_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "logcat", "-c",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            await clear_process.communicate()
            
            # Attempt to restart the WebView loading by sending a touch event
            touch_cmd = [
                "adb", "-s", device_id, "shell", "input tap 300 300"
            ]
            
            await asyncio.create_subprocess_exec(*touch_cmd)
            
            # Wait a moment for WebView to log
            await asyncio.sleep(2)
            
            # Try to get the URL from logcat with a wide filter
            logcat_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "logcat", "-d", 
                "-e", "WebView|loadUrl|onPageStarted|instagram|url",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await logcat_process.communicate()
            log_output = stdout.decode()
            
            # Look for URL patterns in the log output
            url_patterns = [
                r'loadUrl:\s*(https?://[^\s"\']+)',
                r'onPageStarted:\s*(https?://[^\s"\']+)',
                r'Loading URL:\s*(https?://[^\s"\']+)',
                r'URL:\s*(https?://[^\s"\']+)',
                r'(https?://(?:www\.)?instagram\.com[^\s"\']*)'
            ]
            
            for pattern in url_patterns:
                import re
                matches = re.findall(pattern, log_output)
                if matches:
                    logger.info(f"Found WebView URL: {matches[0]}")
                    return matches[0]
            
            # If we couldn't find it in logs, try dumping the WebView state
            dump_view_cmd = [
                "adb", "-s", device_id, "shell", 
                "dumpsys activity top | grep -A 3 'WebView'"
            ]
            
            dump_process = await asyncio.create_subprocess_exec(
                *dump_view_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, _ = await dump_process.communicate()
            dump_output = stdout.decode()
            
            # Look for URL patterns in the activity dump
            for pattern in url_patterns:
                matches = re.findall(pattern, dump_output)
                if matches:
                    logger.info(f"Found WebView URL in activity dump: {matches[0]}")
                    return matches[0]
            
            logger.warning("Could not extract actual WebView URL")
            return ""
        except Exception as e:
            logger.error(f"Error extracting WebView URL: {e}")
            return ""
            
    async def verify_with_actual_url(self, device_id: str, expected_url: str) -> bool:
        """Verify by checking the actual URL loaded in the WebView"""
        actual_url = await self.get_actual_webview_url(device_id)
        if not actual_url:
            # Fallback to simpler verification
            return await self.verify_url_loaded(device_id, expected_url)
            
        # Compare the URLs - normalize them first
        def normalize_url(url):
            # Remove trailing slashes and protocol
            norm = url.lower().replace("https://", "").replace("http://", "").rstrip("/")
            # Remove empty query parameters
            if "?" in norm:
                base, query = norm.split("?", 1)
                if not query:
                    norm = base
            return norm
            
        expected_norm = normalize_url(expected_url)
        actual_norm = normalize_url(actual_url)
        
        # Either compare whole URLs or check if the actual URL contains essential parts
        if expected_norm == actual_norm:
            logger.info(f"✅ URL verification: WebView loaded exactly the expected URL: {actual_url}")
            return True
            
        # For Instagram URLs with complex parameters, check if the path parts match
        expected_parts = expected_norm.split("/")
        actual_parts = actual_norm.split("/")
        
        # Check domain match
        if not actual_norm.startswith(expected_parts[0]):
            logger.error(f"❌ Domain mismatch: Expected {expected_parts[0]}, got {actual_parts[0]}")
            return False
            
        # Check path match (for instagram.com/explore, instagram.com/p/xyz, etc.)
        path_match = (len(expected_parts) > 1 and 
                     len(actual_parts) > 1 and 
                     expected_parts[1] == actual_parts[1])
                     
        if path_match:
            logger.info(f"✅ URL verification: WebView loaded URL with matching path: {actual_url}")
            return True
            
        logger.error(f"❌ URL verification failed: Expected {expected_url}, WebView loaded {actual_url}")
        return False

# Create a singleton instance
instagram_manager = InstagramManager() 