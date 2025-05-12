#!/usr/bin/env python3
"""
Test script for the specific Instagram URL provided by the user
"""
import os
import sys
import asyncio
import logging

# Add parent directory to import path
script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(script_dir)

# Import Instagram manager
from core.instagram_manager import InstagramManager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("instagram_link_test")

async def main():
    # Initialize Instagram manager
    instagram_manager = InstagramManager()
    
    # Get device_id from command line or use the first device
    device_id = sys.argv[1] if len(sys.argv) > 1 else None
    
    if not device_id:
        # Get first device if not specified
        devices = await instagram_manager.get_connected_devices()
        if not devices:
            logger.error("No devices connected")
            return
        device_id = devices[0].id
        logger.info(f"Using device: {device_id}")
    
    # The Instagram URL to test
    test_url = "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"
    
    logger.info(f"Testing Instagram URL: {test_url}")
    
    # Set all features on
    result = await instagram_manager.set_instagram_url(
        device_id=device_id,
        url=test_url,
        webview_mode=True,
        new_webview_per_request=True,
        rotate_ip=True,
        random_devices=True,
        iterations=100,
        min_interval=3,
        max_interval=5
    )
    
    logger.info(f"URL setting result: {result}")
    
    # Check the URL in preferences file directly
    logger.info("Checking URL in preferences...")
    prefs_cmd = await asyncio.create_subprocess_shell(
        f"adb -s {device_id} shell \"run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml | grep target_url\"",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, _ = await prefs_cmd.communicate()
    prefs_output = stdout.decode() if stdout else "Not found"
    logger.info(f"URL in preferences: {prefs_output}")
    
    # Try to get the actual WebView URL
    logger.info("Checking actual WebView URL...")
    actual_url = await instagram_manager.get_actual_webview_url(device_id)
    logger.info(f"Actual WebView URL: {actual_url if actual_url else 'Could not detect'}")
    
    # Check if WebView is running
    logger.info("Checking if WebView is running...")
    webview_cmd = await asyncio.create_subprocess_shell(
        f"adb -s {device_id} shell \"ps | grep webview\"",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, _ = await webview_cmd.communicate()
    webview_output = stdout.decode() if stdout else ""
    is_webview_running = "webview" in webview_output.lower()
    logger.info(f"WebView running: {is_webview_running}")
    
    # Get URL config file
    logger.info("Checking URL in config file...")
    config_url = await asyncio.create_subprocess_shell(
        f"adb -s {device_id} shell \"run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml | grep instagram_url\"",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, _ = await config_url.communicate()
    logger.info(f"URL in config file: {stdout.decode() if stdout else 'Not found'}")
    
    # Restart the app to test persistence
    logger.info("Restarting app to test URL persistence...")
    await instagram_manager.force_stop_app(device_id)
    await instagram_manager.restart_app(device_id)
    
    # Wait for app to fully load
    logger.info("Waiting for app to load...")
    await asyncio.sleep(5)
    
    # Check URL again
    logger.info("Checking URL in preferences after restart...")
    prefs_cmd = await asyncio.create_subprocess_shell(
        f"adb -s {device_id} shell \"run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml | grep target_url\"",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, _ = await prefs_cmd.communicate()
    prefs_output_after = stdout.decode() if stdout else "Not found"
    logger.info(f"URL in preferences after restart: {prefs_output_after}")
    
    # Try to get the actual WebView URL after restart
    logger.info("Checking actual WebView URL after restart...")
    actual_url_after = await instagram_manager.get_actual_webview_url(device_id)
    logger.info(f"Actual WebView URL after restart: {actual_url_after if actual_url_after else 'Could not detect'}")
    
    # Check if WebView is running after restart
    logger.info("Checking if WebView is running after restart...")
    webview_cmd = await asyncio.create_subprocess_shell(
        f"adb -s {device_id} shell \"ps | grep webview\"",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, _ = await webview_cmd.communicate()
    webview_output_after = stdout.decode() if stdout else ""
    is_webview_running_after = "webview" in webview_output_after.lower()
    logger.info(f"WebView running after restart: {is_webview_running_after}")
    
    logger.info("Test completed.")

if __name__ == "__main__":
    asyncio.run(main()) 