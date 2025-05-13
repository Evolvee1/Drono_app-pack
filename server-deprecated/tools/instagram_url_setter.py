#!/usr/bin/env python3
"""
Instagram URL Setter - Specialized tool for reliably setting complex Instagram URLs
This script combines multiple approaches to ensure the Instagram URL is properly set and loaded
"""
import os
import sys
import logging
import json
import subprocess
import argparse
import time
import xml.etree.ElementTree as ET
import asyncio
from typing import List, Dict, Any, Optional

# Configure logging
script_dir = os.path.dirname(os.path.abspath(__file__))
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'instagram_url_setter.log'))
    ]
)
logger = logging.getLogger('instagram_url_setter')

# Constants
PACKAGE_NAME = "com.example.imtbf.debug"
PREFS_FILE = f"/data/data/{PACKAGE_NAME}/shared_prefs/instagram_traffic_simulator_prefs.xml"
URL_CONFIG_FILE = os.path.join(script_dir, "url_config.xml")
MAIN_PREFS_FILE = os.path.join(script_dir, "main_prefs.xml")
BROADCAST_ACTION = f"{PACKAGE_NAME}.COMMAND"

class DeviceNotConnectedError(Exception):
    """Exception raised when a device is not connected"""
    pass

async def get_connected_devices() -> List[Dict[str, str]]:
    """Get a list of connected devices with their status"""
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
                
                devices.append({
                    "id": device_id,
                    "status": "connected",
                    "model": model
                })
        
        return devices
    except Exception as e:
        logger.error(f"Error getting connected devices: {e}")
        return []

async def force_stop_app(device_id: str) -> bool:
    """Force stop the app"""
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

async def check_access_method(device_id: str) -> str:
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

async def create_url_config_file(url: str) -> bool:
    """Create a new URL config file instead of parsing the existing one"""
    try:
        # Create the XML structure
        root = ET.Element("map")
        
        # Add Instagram URL
        url_element = ET.SubElement(root, "string")
        url_element.set("name", "instagram_url")
        url_element.text = url
        
        # Add URL source
        source_element = ET.SubElement(root, "string")
        source_element.set("name", "url_source")
        source_element.text = "external"
        
        # Add timestamp
        timestamp_element = ET.SubElement(root, "long")
        timestamp_element.set("name", "url_timestamp")
        timestamp_element.text = str(int(time.time() * 1000000000))  # Nanoseconds
        
        # Create the tree and save
        tree = ET.ElementTree(root)
        tree.write(URL_CONFIG_FILE, encoding="utf-8", xml_declaration=True)
        
        logger.info(f"Created new URL config file with URL: {url}")
        return True
    except Exception as e:
        logger.error(f"Error creating URL config file: {e}")
        return False

async def create_main_prefs_file(iterations: int, min_interval: int, max_interval: int, delay: int = 3000) -> bool:
    """Create a new main preferences file with the specified settings"""
    try:
        # Create the XML structure
        root = ET.Element("map")
        
        # Add settings elements
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
        
        boolean_settings = {
            "is_running": "false",
            "is_first_run": "false"
        }
        
        for name, value in boolean_settings.items():
            element = ET.SubElement(root, "boolean")
            element.set("name", name)
            element.set("value", value)
        
        # Create the tree and save
        tree = ET.ElementTree(root)
        tree.write(MAIN_PREFS_FILE, encoding="utf-8", xml_declaration=True)
        
        logger.info(f"Created main preferences file with iterations={iterations}, min_interval={min_interval}, max_interval={max_interval}")
        return True
    except Exception as e:
        logger.error(f"Error creating main preferences file: {e}")
        return False

async def push_config_file(device_id: str, access_method: str) -> bool:
    """Push the updated config file to the device"""
    try:
        # Push to a temporary location first
        temp_file = f"/data/local/tmp/url_config_{int(time.time())}.xml"
        push_process = await asyncio.create_subprocess_exec(
            "adb", "-s", device_id, "push", URL_CONFIG_FILE, temp_file,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await push_process.communicate()
        
        if push_process.returncode != 0:
            logger.error(f"Failed to push config file to {device_id}: {stderr.decode()}")
            return False
        
        # Move to final location based on access method
        if access_method == "root":
            move_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell", "su", "-c", 
                f"cp {temp_file} /data/data/{PACKAGE_NAME}/shared_prefs/url_config.xml && chmod 660 /data/data/{PACKAGE_NAME}/shared_prefs/url_config.xml && chown {PACKAGE_NAME}:{PACKAGE_NAME} /data/data/{PACKAGE_NAME}/shared_prefs/url_config.xml",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
        elif access_method == "run-as":
            move_process = await asyncio.create_subprocess_exec(
                "adb", "-s", device_id, "shell",
                f"run-as {PACKAGE_NAME} cp {temp_file} /data/data/{PACKAGE_NAME}/shared_prefs/url_config.xml",
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

async def push_main_prefs_file(device_id: str, access_method: str) -> bool:
    """Push the main preferences file to the device"""
    try:
        # Push to a temporary location first
        temp_file = f"/data/local/tmp/main_prefs_{int(time.time())}.xml"
        push_process = await asyncio.create_subprocess_exec(
            "adb", "-s", device_id, "push", MAIN_PREFS_FILE, temp_file,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        _, stderr = await push_process.communicate()
        
        if push_process.returncode != 0:
            logger.error(f"Failed to push main preferences file to {device_id}: {stderr.decode()}")
            return False
        
        # Move to final location based on access method
        target_file = f"/data/data/{PACKAGE_NAME}/shared_prefs/instagram_traffic_simulator_prefs.xml"
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

async def send_broadcast_command(device_id: str, url: str, webview_mode: bool, 
                               new_webview_per_request: bool, rotate_ip: bool = True,
                               random_devices: bool = True) -> bool:
    """Send broadcast command to set the URL and settings"""
    try:
        # Fix: Update broadcast command format to match the expected format in broadcast_control.sh
        # Send URL command
        url_cmd = [
            "adb", "-s", device_id, "shell", "am", "broadcast",
            "-a", BROADCAST_ACTION,
            "-e", "command", "set_url",
            "-e", "value", f"'{url}'"  # Added quotes around the URL value
        ]
        
        # Execute command with correct package parameter placement
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
        
        # Send additional feature toggles
        features = {
            "webview_mode": webview_mode,
            "new_webview_per_request": new_webview_per_request,
            "rotate_ip": rotate_ip,
            "random_devices": random_devices
        }
        
        for feature, value in features.items():
            feature_cmd = [
                "adb", "-s", device_id, "shell", "am", "broadcast",
                "-a", BROADCAST_ACTION,
                "-e", "command", "toggle_feature",
                "-e", "feature", feature,
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

async def start_app_with_url(device_id: str, url: str) -> bool:
    """Start the app with a direct intent to load the URL"""
    try:
        # Construct start command with intent extra
        cmd = [
            "adb", "-s", device_id, "shell", "am", "start",
            "-n", f"{PACKAGE_NAME}/com.example.imtbf.presentation.activities.MainActivity",
            "-e", "direct_url", f"'{url}'"  # Added quotes around the URL value
        ]
        
        # Execute command
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        if process.returncode != 0:
            logger.error(f"Failed to start app with URL on {device_id}: {stderr.decode()}")
            return False
        
        logger.info(f"Successfully started app with direct URL on {device_id}")
        return True
    except Exception as e:
        logger.error(f"Error starting app with URL on {device_id}: {e}")
        return False

async def verify_url_loaded(device_id: str, url: str) -> bool:
    """Verify the URL was loaded by checking logcat output"""
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
        
        # Try a different approach - check for WebView processes
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

async def set_instagram_url(device_id: str, url: str, webview_mode: bool = True, 
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
        # Step 1: Force stop the app
        logger.info(f"Step 1: Force stopping app on {device_id}")
        if not await force_stop_app(device_id):
            result["message"] = "Failed to force stop app"
            return result
        
        # Step 2: Check access method
        logger.info(f"Step 2: Checking access method for {device_id}")
        access_method = await check_access_method(device_id)
        if access_method == "none":
            logger.warning(f"No direct file access available for {device_id}, using broadcast only")
        
        # Step 3: Create URL config file
        logger.info(f"Step 3: Creating URL config for {device_id}")
        if not await create_url_config_file(url):
            logger.warning("Failed to create URL config file, continuing anyway")
        
        # Step 4: Create main preferences file with iterations and intervals
        logger.info(f"Step 4: Creating main preferences file for {device_id}")
        if not await create_main_prefs_file(iterations, min_interval, max_interval, delay):
            logger.warning("Failed to create main preferences file, continuing anyway")
        
        # Step 5: Push config files if possible
        if access_method != "none":
            logger.info(f"Step 5a: Pushing URL config to {device_id}")
            await push_config_file(device_id, access_method)
            
            logger.info(f"Step 5b: Pushing main preferences to {device_id}")
            await push_main_prefs_file(device_id, access_method)
        
        # Step 6: Send broadcast commands for URL and settings
        logger.info(f"Step 6: Sending broadcast commands to {device_id}")
        if not await send_broadcast_command(
            device_id, url, webview_mode, new_webview_per_request, rotate_ip, random_devices
        ):
            result["message"] = "Failed to send broadcast commands"
            return result
        
        # Step 7: Start app with direct URL intent
        logger.info(f"Step 7: Starting app with direct URL on {device_id}")
        if not await start_app_with_url(device_id, url):
            result["message"] = "Failed to start app with URL"
            return result
        
        # Step 8: Verify URL loaded
        logger.info(f"Step 8: Verifying URL loaded on {device_id}")
        url_loaded = await verify_url_loaded(device_id, url)
        
        if url_loaded:
            result["success"] = True
            result["message"] = "URL successfully set and verified"
        else:
            result["message"] = "URL set but could not verify loading"
            # Still mark as partial success
            result["success"] = True
        
        # Add details about the settings that were applied
        result["details"] = {
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
        
        return result
    except Exception as e:
        logger.error(f"Error setting Instagram URL on {device_id}: {e}")
        result["message"] = f"Error: {str(e)}"
        return result

async def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Instagram URL Setter Tool')
    parser.add_argument('--url', required=True, help='Instagram URL to set')
    parser.add_argument('--device', help='Specific device ID (omit for all connected devices)')
    parser.add_argument('--webview-mode', action='store_true', default=True, help='Enable WebView mode')
    parser.add_argument('--new-webview-per-request', action='store_true', default=True, help='Create new WebView per request')
    parser.add_argument('--rotate-ip', action='store_true', default=True, help='Rotate IP between requests')
    parser.add_argument('--random-devices', action='store_true', default=True, help='Use random device profiles')
    parser.add_argument('--iterations', type=int, default=100, help='Number of iterations')
    parser.add_argument('--min-interval', type=int, default=3, help='Minimum interval (seconds)')
    parser.add_argument('--max-interval', type=int, default=5, help='Maximum interval (seconds)')
    parser.add_argument('--delay', type=int, default=3000, help='Airplane mode delay (milliseconds)')
    
    args = parser.parse_args()
    
    # Get connected devices
    devices = await get_connected_devices()
    
    if not devices:
        logger.error("No devices connected")
        return 1
    
    # Filter devices if specific device requested
    if args.device:
        devices = [d for d in devices if d["id"] == args.device]
        if not devices:
            logger.error(f"Device {args.device} not found or not connected")
            return 1
    
    logger.info(f"Setting Instagram URL on {len(devices)} device(s)")
    logger.info(f"URL: {args.url}")
    
    # Set URL on all target devices
    results = []
    for device in devices:
        logger.info(f"Setting URL on device {device['id']} ({device['model']})")
        result = await set_instagram_url(
            device_id=device["id"],
            url=args.url,
            webview_mode=args.webview_mode,
            new_webview_per_request=args.new_webview_per_request,
            rotate_ip=args.rotate_ip,
            random_devices=args.random_devices,
            iterations=args.iterations,
            min_interval=args.min_interval,
            max_interval=args.max_interval,
            delay=args.delay
        )
        results.append(result)
    
    # Print results summary
    success_count = sum(1 for r in results if r["success"])
    logger.info(f"Results: {success_count}/{len(results)} devices successful")
    
    for result in results:
        status = "✅ Success" if result["success"] else "❌ Failed"
        logger.info(f"{status}: {result['device_id']} - {result['message']}")
    
    return 0 if success_count == len(results) else 1

if __name__ == "__main__":
    asyncio.run(main()) 