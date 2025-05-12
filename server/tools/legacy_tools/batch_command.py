#!/usr/bin/env python3
"""
Batch Command Utility

This script allows you to send the same command to multiple Android devices.
It gets a list of devices from the server, lets you select which ones to target,
and then sends the specified command to all selected devices.
"""

import argparse
import asyncio
import json
import sys
import time
import requests
from typing import List, Dict, Any, Optional

SERVER_URL = "http://127.0.0.1:8000"
API_DEVICES_URL = f"{SERVER_URL}/devices"
API_COMMAND_URL = f"{SERVER_URL}/api/devices"

class BatchCommandTool:
    def __init__(self, server_url: str = SERVER_URL):
        self.server_url = server_url
        self.devices = []
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get a list of all connected devices from the server"""
        try:
            response = requests.get(API_DEVICES_URL)
            response.raise_for_status()
            devices = response.json()
            print(f"Found {len(devices)} connected devices")
            return devices
        except requests.RequestException as e:
            print(f"Error getting devices: {e}")
            return []
    
    def select_devices(self, devices: List[Dict[str, Any]], select_all: bool = False, device_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Let the user select which devices to target"""
        if not devices:
            print("No devices available")
            return []
        
        # If device IDs are provided, filter devices by those IDs
        if device_ids:
            selected_devices = [d for d in devices if d['id'] in device_ids]
            if not selected_devices:
                print("None of the specified device IDs were found")
                return []
            print(f"Selected {len(selected_devices)} devices: {', '.join(d['id'] for d in selected_devices)}")
            return selected_devices
        
        # If select_all flag is set, return all devices
        if select_all:
            print(f"Selected all {len(devices)} devices")
            return devices
        
        # Otherwise, let user select interactively
        print("\nAvailable devices:")
        for i, device in enumerate(devices, 1):
            print(f"{i}. {device['id']} - {device['model']} ({device['status']})")
        
        selected_indices = input("\nEnter device numbers to select (comma-separated), or 'all' for all devices: ")
        
        if selected_indices.lower() == 'all':
            return devices
        
        try:
            # Parse comma-separated indices
            indices = [int(idx.strip()) - 1 for idx in selected_indices.split(',')]
            selected_devices = [devices[idx] for idx in indices if 0 <= idx < len(devices)]
            
            if not selected_devices:
                print("No valid devices selected")
                return []
            
            print(f"Selected {len(selected_devices)} devices: {', '.join(d['id'] for d in selected_devices)}")
            return selected_devices
        except (ValueError, IndexError):
            print("Invalid selection")
            return []
    
    def send_command(self, device_id: str, command: str, parameters: Dict[str, Any], dry_run: bool = False) -> Dict[str, Any]:
        """Send a command to a specific device"""
        url = f"{API_COMMAND_URL}/{device_id}/command"
        payload = {
            "command": command,
            "parameters": parameters,
            "dryrun": dry_run
        }
        
        try:
            response = requests.post(url, json=payload)
            response.raise_for_status()
            result = response.json()
            return result
        except requests.RequestException as e:
            print(f"Error sending command to device {device_id}: {e}")
            return {"success": False, "message": str(e)}
    
    def send_batch_command(self, command: str, parameters: Dict[str, Any], 
                          selected_devices: List[Dict[str, Any]], dry_run: bool = False) -> Dict[str, Any]:
        """Send the same command to multiple devices"""
        results = {}
        
        for device in selected_devices:
            device_id = device['id']
            print(f"Sending command to device {device_id} ({device['model']})...")
            
            result = self.send_command(device_id, command, parameters, dry_run)
            results[device_id] = result
            
            success = result.get('success', False)
            if success:
                print(f"✅ Success: {result.get('message', 'Command executed')}")
            else:
                print(f"❌ Failed: {result.get('message', 'Unknown error')}")
            
            # Add a small delay between commands to avoid overwhelming the server
            time.sleep(0.5)
        
        return results

def parse_arguments():
    parser = argparse.ArgumentParser(description='Send commands to multiple Android devices')
    parser.add_argument('--all', action='store_true', help='Select all available devices')
    parser.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    parser.add_argument('--command', required=True, help='Command to execute (e.g., start, stop, pause)')
    parser.add_argument('--url', help='URL parameter for the command')
    parser.add_argument('--iterations', type=int, help='Number of iterations')
    parser.add_argument('--min-interval', type=int, help='Minimum interval between requests (seconds)')
    parser.add_argument('--max-interval', type=int, help='Maximum interval between requests (seconds)')
    parser.add_argument('--webview-mode', action='store_true', help='Enable webview mode')
    parser.add_argument('--no-webview-mode', action='store_false', dest='webview_mode', help='Disable webview mode')
    parser.add_argument('--dismiss-restore', action='store_true', help='Dismiss restore dialog')
    parser.add_argument('--dry-run', action='store_true', help='Simulate command execution without actually performing it')
    
    parser.set_defaults(webview_mode=None)
    
    return parser.parse_args()

def main():
    args = parse_arguments()
    
    # Initialize the batch command tool
    tool = BatchCommandTool()
    
    # Get available devices
    devices = tool.get_devices()
    if not devices:
        print("No devices found. Exiting.")
        sys.exit(1)
    
    # Select devices based on arguments
    selected_devices = tool.select_devices(devices, select_all=args.all, device_ids=args.devices)
    if not selected_devices:
        print("No devices selected. Exiting.")
        sys.exit(1)
    
    # Build command parameters
    parameters = {}
    if args.url:
        parameters['url'] = args.url
    if args.iterations:
        parameters['iterations'] = args.iterations
    if args.min_interval:
        parameters['min_interval'] = args.min_interval
    if args.max_interval:
        parameters['max_interval'] = args.max_interval
    if args.webview_mode is not None:  # Only include if explicitly set
        parameters['webview_mode'] = args.webview_mode
    if args.dismiss_restore:
        parameters['dismiss_restore'] = True
    
    # Print command details
    print(f"\nCommand: {args.command}")
    print(f"Parameters: {json.dumps(parameters, indent=2)}")
    
    # Confirm execution
    if not args.dry_run:
        confirm = input("\nSend this command to all selected devices? (y/n): ")
        if confirm.lower() != 'y':
            print("Aborted by user. Exiting.")
            sys.exit(0)
    
    # Send commands to all selected devices
    results = tool.send_batch_command(args.command, parameters, selected_devices, args.dry_run)
    
    # Print summary
    success_count = sum(1 for r in results.values() if r.get('success', False))
    print(f"\nCommand sent to {len(results)} devices, {success_count} successful, {len(results) - success_count} failed")
    
    return results

if __name__ == "__main__":
    main() 
"""
Batch Command Utility

This script allows you to send the same command to multiple Android devices.
It gets a list of devices from the server, lets you select which ones to target,
and then sends the specified command to all selected devices.
"""

import argparse
import asyncio
import json
import sys
import time
import requests
from typing import List, Dict, Any, Optional

SERVER_URL = "http://127.0.0.1:8000"
API_DEVICES_URL = f"{SERVER_URL}/devices"
API_COMMAND_URL = f"{SERVER_URL}/api/devices"

class BatchCommandTool:
    def __init__(self, server_url: str = SERVER_URL):
        self.server_url = server_url
        self.devices = []
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get a list of all connected devices from the server"""
        try:
            response = requests.get(API_DEVICES_URL)
            response.raise_for_status()
            devices = response.json()
            print(f"Found {len(devices)} connected devices")
            return devices
        except requests.RequestException as e:
            print(f"Error getting devices: {e}")
            return []
    
    def select_devices(self, devices: List[Dict[str, Any]], select_all: bool = False, device_ids: List[str] = None) -> List[Dict[str, Any]]:
        """Let the user select which devices to target"""
        if not devices:
            print("No devices available")
            return []
        
        # If device IDs are provided, filter devices by those IDs
        if device_ids:
            selected_devices = [d for d in devices if d['id'] in device_ids]
            if not selected_devices:
                print("None of the specified device IDs were found")
                return []
            print(f"Selected {len(selected_devices)} devices: {', '.join(d['id'] for d in selected_devices)}")
            return selected_devices
        
        # If select_all flag is set, return all devices
        if select_all:
            print(f"Selected all {len(devices)} devices")
            return devices
        
        # Otherwise, let user select interactively
        print("\nAvailable devices:")
        for i, device in enumerate(devices, 1):
            print(f"{i}. {device['id']} - {device['model']} ({device['status']})")
        
        selected_indices = input("\nEnter device numbers to select (comma-separated), or 'all' for all devices: ")
        
        if selected_indices.lower() == 'all':
            return devices
        
        try:
            # Parse comma-separated indices
            indices = [int(idx.strip()) - 1 for idx in selected_indices.split(',')]
            selected_devices = [devices[idx] for idx in indices if 0 <= idx < len(devices)]
            
            if not selected_devices:
                print("No valid devices selected")
                return []
            
            print(f"Selected {len(selected_devices)} devices: {', '.join(d['id'] for d in selected_devices)}")
            return selected_devices
        except (ValueError, IndexError):
            print("Invalid selection")
            return []
    
    def send_command(self, device_id: str, command: str, parameters: Dict[str, Any], dry_run: bool = False) -> Dict[str, Any]:
        """Send a command to a specific device"""
        url = f"{API_COMMAND_URL}/{device_id}/command"
        payload = {
            "command": command,
            "parameters": parameters,
            "dryrun": dry_run
        }
        
        try:
            response = requests.post(url, json=payload)
            response.raise_for_status()
            result = response.json()
            return result
        except requests.RequestException as e:
            print(f"Error sending command to device {device_id}: {e}")
            return {"success": False, "message": str(e)}
    
    def send_batch_command(self, command: str, parameters: Dict[str, Any], 
                          selected_devices: List[Dict[str, Any]], dry_run: bool = False) -> Dict[str, Any]:
        """Send the same command to multiple devices"""
        results = {}
        
        for device in selected_devices:
            device_id = device['id']
            print(f"Sending command to device {device_id} ({device['model']})...")
            
            result = self.send_command(device_id, command, parameters, dry_run)
            results[device_id] = result
            
            success = result.get('success', False)
            if success:
                print(f"✅ Success: {result.get('message', 'Command executed')}")
            else:
                print(f"❌ Failed: {result.get('message', 'Unknown error')}")
            
            # Add a small delay between commands to avoid overwhelming the server
            time.sleep(0.5)
        
        return results

def parse_arguments():
    parser = argparse.ArgumentParser(description='Send commands to multiple Android devices')
    parser.add_argument('--all', action='store_true', help='Select all available devices')
    parser.add_argument('--devices', nargs='+', help='Specific device IDs to target')
    parser.add_argument('--command', required=True, help='Command to execute (e.g., start, stop, pause)')
    parser.add_argument('--url', help='URL parameter for the command')
    parser.add_argument('--iterations', type=int, help='Number of iterations')
    parser.add_argument('--min-interval', type=int, help='Minimum interval between requests (seconds)')
    parser.add_argument('--max-interval', type=int, help='Maximum interval between requests (seconds)')
    parser.add_argument('--webview-mode', action='store_true', help='Enable webview mode')
    parser.add_argument('--no-webview-mode', action='store_false', dest='webview_mode', help='Disable webview mode')
    parser.add_argument('--dismiss-restore', action='store_true', help='Dismiss restore dialog')
    parser.add_argument('--dry-run', action='store_true', help='Simulate command execution without actually performing it')
    
    parser.set_defaults(webview_mode=None)
    
    return parser.parse_args()

def main():
    args = parse_arguments()
    
    # Initialize the batch command tool
    tool = BatchCommandTool()
    
    # Get available devices
    devices = tool.get_devices()
    if not devices:
        print("No devices found. Exiting.")
        sys.exit(1)
    
    # Select devices based on arguments
    selected_devices = tool.select_devices(devices, select_all=args.all, device_ids=args.devices)
    if not selected_devices:
        print("No devices selected. Exiting.")
        sys.exit(1)
    
    # Build command parameters
    parameters = {}
    if args.url:
        parameters['url'] = args.url
    if args.iterations:
        parameters['iterations'] = args.iterations
    if args.min_interval:
        parameters['min_interval'] = args.min_interval
    if args.max_interval:
        parameters['max_interval'] = args.max_interval
    if args.webview_mode is not None:  # Only include if explicitly set
        parameters['webview_mode'] = args.webview_mode
    if args.dismiss_restore:
        parameters['dismiss_restore'] = True
    
    # Print command details
    print(f"\nCommand: {args.command}")
    print(f"Parameters: {json.dumps(parameters, indent=2)}")
    
    # Confirm execution
    if not args.dry_run:
        confirm = input("\nSend this command to all selected devices? (y/n): ")
        if confirm.lower() != 'y':
            print("Aborted by user. Exiting.")
            sys.exit(0)
    
    # Send commands to all selected devices
    results = tool.send_batch_command(args.command, parameters, selected_devices, args.dry_run)
    
    # Print summary
    success_count = sum(1 for r in results.values() if r.get('success', False))
    print(f"\nCommand sent to {len(results)} devices, {success_count} successful, {len(results) - success_count} failed")
    
    return results

if __name__ == "__main__":
    main() 