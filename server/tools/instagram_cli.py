#!/usr/bin/env python3
"""
Instagram CLI - Command-line tool for managing Instagram URLs on devices
This tool directly uses the Instagram manager module
"""
import os
import sys
import logging
import argparse
import asyncio
from typing import List, Dict, Any

# Add path to import from core
script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(script_dir)

# Import from core
from core.instagram_manager import instagram_manager

# Configure logging
LOG_DIR = os.path.join(script_dir, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'instagram_cli.log'))
    ]
)
logger = logging.getLogger('instagram_cli')

async def list_devices():
    """List connected devices"""
    devices = await instagram_manager.get_connected_devices()
    
    if not devices:
        print("No devices connected")
        return
    
    print(f"Found {len(devices)} connected device(s):")
    for device in devices:
        print(f"  • {device.id} ({device.model}) - {device.status}")

async def set_url(args):
    """Set Instagram URL on device(s)"""
    # Get connected devices
    devices = await instagram_manager.get_connected_devices()
    
    if not devices:
        print("No devices connected")
        return 1
    
    # Determine target devices
    target_devices = []
    if args.device:
        # Filter devices by ID
        target_devices = [d.id for d in devices if d.id == args.device]
        if not target_devices:
            print(f"Device {args.device} not found or not connected")
            return 1
    else:
        # Use all devices
        target_devices = [d.id for d in devices]
    
    print(f"Setting Instagram URL on {len(target_devices)} device(s)...")
    print(f"URL: {args.url}")
    print("Using reliable method (force stop → set settings → restart)")
    
    # Set URL on each device
    results = []
    for device_id in target_devices:
        print(f"\nProcessing device {device_id}...")
        result = await instagram_manager.set_instagram_url(
            device_id=device_id,
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
    
    # Print results
    success_count = sum(1 for r in results if r["success"])
    print(f"\nResults: {success_count}/{len(results)} devices successful")
    
    for result in results:
        status = "✅ Success" if result["success"] else "❌ Failed"
        print(f"{status}: {result['device_id']} - {result['message']}")
    
    return 0 if success_count == len(results) else 1

async def restart_app(args):
    """Restart the app on device(s)"""
    # Get connected devices
    devices = await instagram_manager.get_connected_devices()
    
    if not devices:
        print("No devices connected")
        return 1
    
    # Determine target devices
    target_devices = []
    if args.device:
        # Filter devices by ID
        target_devices = [d.id for d in devices if d.id == args.device]
        if not target_devices:
            print(f"Device {args.device} not found or not connected")
            return 1
    else:
        # Use all devices
        target_devices = [d.id for d in devices]
    
    print(f"Restarting app on {len(target_devices)} device(s)...")
    
    # Restart app on each device
    results = []
    for device_id in target_devices:
        print(f"Restarting app on device {device_id}...")
        success = await instagram_manager.restart_app(device_id)
        results.append({"device_id": device_id, "success": success})
    
    # Print results
    success_count = sum(1 for r in results if r["success"])
    print(f"\nResults: {success_count}/{len(results)} devices successful")
    
    for result in results:
        status = "✅ Success" if result["success"] else "❌ Failed"
        print(f"{status}: {result['device_id']}")
    
    return 0 if success_count == len(results) else 1

async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Instagram CLI Tool')
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # List devices command
    list_parser = subparsers.add_parser('list', help='List connected devices')
    
    # Set URL command
    set_parser = subparsers.add_parser('set-url', help='Set Instagram URL')
    set_parser.add_argument('--url', required=True, help='Instagram URL to set')
    set_parser.add_argument('--device', help='Specific device ID (omit for all connected devices)')
    set_parser.add_argument('--webview-mode', action='store_true', default=True, help='Enable WebView mode')
    set_parser.add_argument('--no-webview-mode', action='store_false', dest='webview_mode', help='Disable WebView mode')
    set_parser.add_argument('--new-webview-per-request', action='store_true', default=True, help='Create new WebView per request')
    set_parser.add_argument('--no-new-webview-per-request', action='store_false', dest='new_webview_per_request', help='Disable new WebView per request')
    set_parser.add_argument('--rotate-ip', action='store_true', default=True, help='Rotate IP between requests')
    set_parser.add_argument('--no-rotate-ip', action='store_false', dest='rotate_ip', help='Disable IP rotation')
    set_parser.add_argument('--random-devices', action='store_true', default=True, help='Use random device profiles')
    set_parser.add_argument('--no-random-devices', action='store_false', dest='random_devices', help='Disable random device profiles')
    set_parser.add_argument('--iterations', type=int, default=100, help='Number of iterations (default: 100)')
    set_parser.add_argument('--min-interval', type=int, default=3, help='Minimum interval in seconds (default: 3)')
    set_parser.add_argument('--max-interval', type=int, default=5, help='Maximum interval in seconds (default: 5)')
    set_parser.add_argument('--delay', type=int, default=3000, help='Delay in milliseconds (default: 3000)')
    
    # Restart app command
    restart_parser = subparsers.add_parser('restart', help='Restart the app')
    restart_parser.add_argument('--device', help='Specific device ID (omit for all connected devices)')
    
    args = parser.parse_args()
    
    # Execute the appropriate command
    if args.command == 'list':
        await list_devices()
        return 0
    elif args.command == 'set-url':
        return await set_url(args)
    elif args.command == 'restart':
        return await restart_app(args)
    else:
        parser.print_help()
        return 1

if __name__ == '__main__':
    try:
        exit_code = asyncio.run(main())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1) 