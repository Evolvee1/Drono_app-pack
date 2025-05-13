#!/usr/bin/env python3
"""
Test script for the Instagram Manager
This script tests the functionality of the Instagram Manager
"""
import os
import sys
import asyncio
import logging
from pprint import pprint

# Add path to server directory
script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(script_dir)

# Import from core
from core.instagram_manager import instagram_manager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('test_instagram_manager')

async def test_get_devices():
    """Test getting connected devices"""
    print("Testing get_connected_devices()...")
    devices = await instagram_manager.get_connected_devices()
    
    if devices:
        print(f"Found {len(devices)} device(s):")
        for device in devices:
            print(f"  • {device.id} ({device.model}) - {device.status}")
    else:
        print("No devices found.")
    
    return devices

async def test_set_url(device_id, url="https://www.instagram.com/p/test-url-123"):
    """Test setting an Instagram URL"""
    print(f"\nTesting set_instagram_url() on device {device_id}...")
    print(f"URL: {url}")
    
    result = await instagram_manager.set_instagram_url(
        device_id=device_id,
        url=url,
        webview_mode=True,
        new_webview_per_request=True,
        rotate_ip=True,
        random_devices=True,
        iterations=10,
        min_interval=2,
        max_interval=4,
        delay=2000
    )
    
    print("\nResult:")
    pprint(result)
    
    return result["success"]

async def test_restart_app(device_id):
    """Test restarting the app"""
    print(f"\nTesting restart_app() on device {device_id}...")
    
    success = await instagram_manager.restart_app(device_id)
    
    if success:
        print("Successfully restarted app")
    else:
        print("Failed to restart app")
    
    return success

async def main():
    """Main test function"""
    print("===== Testing Instagram Manager =====")
    
    # Step 1: Get connected devices
    devices = await test_get_devices()
    
    if not devices:
        print("No devices connected. Exiting tests.")
        return 1
    
    device_id = devices[0].id
    
    # Step 2: Test setting an Instagram URL
    url_success = await test_set_url(device_id)
    
    # Step 3: Test restarting the app
    restart_success = await test_restart_app(device_id)
    
    # Print summary
    print("\n===== Test Summary =====")
    print(f"Get Devices: {'✅ Success' if devices else '❌ Failed'}")
    print(f"Set URL: {'✅ Success' if url_success else '❌ Failed'}")
    print(f"Restart App: {'✅ Success' if restart_success else '❌ Failed'}")
    
    # Return overall result
    success = all([bool(devices), url_success, restart_success])
    return 0 if success else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code) 