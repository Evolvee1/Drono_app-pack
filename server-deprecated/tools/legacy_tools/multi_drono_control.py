#!/usr/bin/env python3
"""
Multi-Device Drono Control Script

This script directly uses ADB to identify connected devices and runs the drono_control.sh
script for each selected device, one at a time.

This approach bypasses the server API completely, which can be useful when the server is
having issues or when you need maximum reliability.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from typing import List, Dict, Any, Optional

# Path to the drono_control.sh script
DRONO_SCRIPT = "../../android-app/drono_control.sh"

class MultiDronoControl:
    def __init__(self, script_path: str = DRONO_SCRIPT):
        self.script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), script_path))
        if not os.path.exists(self.script_path):
            print(f"Error: drono_control.sh script not found at {self.script_path}")
            sys.exit(1)
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get a list of all connected Android devices using ADB"""
        try:
            # Run ADB devices command
            result = subprocess.run(["adb", "devices", "-l"], capture_output=True, text=True, check=True)
            
            devices = []
            lines = result.stdout.strip().split("\n")[1:]  # Skip header line
            
            for line in lines:
                if not line.strip():
                    continue
                
                parts = line.split()
                if len(parts) >= 2:
                    device_id = parts[0]
                    status = parts[1]
                    
                    # Extract model info
                    model = "Unknown"
                    model_match = re.search(r'model:(\S+)', line)
                    if model_match:
                        model = model_match.group(1)
                    
                    # Get battery level
                    try:
                        battery_cmd = ["adb", "-s", device_id, "shell", "dumpsys", "battery", "|", "grep", "level"]
                        battery_result = subprocess.run(" ".join(battery_cmd), shell=True, capture_output=True, text=True)
                        battery = "Unknown"
                        if battery_result.returncode == 0:
                            battery_match = re.search(r'level: (\d+)', battery_result.stdout)
                            if battery_match:
                                battery = f"{battery_match.group(1)}%"
                    except Exception as e:
                        print(f"Warning: Failed to get battery for device {device_id}: {e}")
                        battery = "Unknown"
                    
                    devices.append({
                        'id': device_id,
                        'model': model,
                        'status': 'online' if status == 'device' else 'offline',
                        'battery': battery
                    })
            
            print(f"Found {len(devices)} connected devices")
            return devices
        except subprocess.SubprocessError as e:
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
            print(f"{i}. {device['id']} - {device['model']} ({device['status']}) - Battery: {device['battery']}")
        
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
    
    def build_command(self, command: str, parameters: Dict[str, Any]) -> List[str]:
        """Build the drono_control.sh command with parameters"""
        cmd = [self.script_path]
        
        # Special handling for 'start' command
        if command == "start":
            # Add -settings flag for settings before start
            cmd.append("-settings")
            
            # Add dismiss_restore if specified
            if parameters.get("dismiss_restore"):
                cmd.append("dismiss_restore")
            
            # Add URL parameter if specified
            if "url" in parameters:
                cmd.extend(["url", parameters["url"]])
            
            # Add iterations parameter if specified
            if "iterations" in parameters:
                cmd.extend(["iterations", str(parameters["iterations"])])
            
            # Add min_interval parameter if specified
            if "min_interval" in parameters:
                cmd.extend(["min_interval", str(parameters["min_interval"])])
            
            # Add max_interval parameter if specified
            if "max_interval" in parameters:
                cmd.extend(["max_interval", str(parameters["max_interval"])])
            
            # Add toggle parameters in the format: toggle feature true/false
            for toggle_feature in ["webview_mode", "rotate_ip", "random_devices", "aggressive_clearing"]:
                if toggle_feature in parameters:
                    cmd.extend(["toggle", toggle_feature, str(parameters[toggle_feature]).lower()])
            
            # Add the command at the end
            cmd.append(command)
        else:
            # For other commands, just add the command
            cmd.append(command)
        
        return cmd
    
    def execute_command(self, device_id: str, command: List[str], dry_run: bool = False) -> Dict[str, Any]:
        """Execute a command for a specific device using ADB"""
        # Set ADB_DEVICE_ID environment variable for the script to use
        env = os.environ.copy()
        env["ADB_DEVICE_ID"] = device_id
        
        print(f"Executing: {' '.join(command)}")
        print(f"Device ID: {device_id}")
        
        if dry_run:
            print("Dry run - skipping actual execution")
            return {"success": True, "message": "Dry run completed", "device_id": device_id}
        
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                print("Command executed successfully")
                return {"success": True, "message": "Command executed successfully", "device_id": device_id}
            else:
                print(f"Command failed with exit code {result.returncode}")
                print(f"Error: {result.stderr}")
                return {
                    "success": False, 
                    "message": f"Command failed with exit code {result.returncode}",
                    "error": result.stderr,
                    "device_id": device_id
                }
        except Exception as e:
            print(f"Error executing command: {e}")
            return {"success": False, "message": str(e), "device_id": device_id}
    
    def execute_for_multiple_devices(self, command: str, parameters: Dict[str, Any], 
                                    selected_devices: List[Dict[str, Any]], dry_run: bool = False) -> Dict[str, Any]:
        """Execute the command for multiple devices in sequence"""
        results = {}
        cmd = self.build_command(command, parameters)
        
        for device in selected_devices:
            device_id = device['id']
            print(f"\n{'=' * 60}")
            print(f"Processing device: {device_id} ({device['model']})")
            print(f"{'=' * 60}")
            
            result = self.execute_command(device_id, cmd, dry_run)
            results[device_id] = result
            
            print(f"\nResult: {'Success' if result.get('success', False) else 'Failed'}")
            
            # Add a delay between devices
            if device != selected_devices[-1]:  # Don't delay after the last device
                print("\nWaiting 3 seconds before processing next device...")
                time.sleep(3)
        
        return results

def parse_arguments():
    parser = argparse.ArgumentParser(description='Send commands to multiple Android devices using drono_control.sh')
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
    
    # Initialize the multi-drono control tool
    tool = MultiDronoControl()
    
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
        confirm = input("\nExecute this command on all selected devices? (y/n): ")
        if confirm.lower() != 'y':
            print("Aborted by user. Exiting.")
            sys.exit(0)
    
    # Execute commands on all selected devices
    results = tool.execute_for_multiple_devices(args.command, parameters, selected_devices, args.dry_run)
    
    # Print summary
    success_count = sum(1 for r in results.values() if r.get('success', False))
    print(f"\n{'=' * 60}")
    print(f"SUMMARY: Command executed on {len(results)} devices, {success_count} successful, {len(results) - success_count} failed")
    print(f"{'=' * 60}")
    
    return results

if __name__ == "__main__":
    main() 
"""
Multi-Device Drono Control Script

This script directly uses ADB to identify connected devices and runs the drono_control.sh
script for each selected device, one at a time.

This approach bypasses the server API completely, which can be useful when the server is
having issues or when you need maximum reliability.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from typing import List, Dict, Any, Optional

# Path to the drono_control.sh script
DRONO_SCRIPT = "../../android-app/drono_control.sh"

class MultiDronoControl:
    def __init__(self, script_path: str = DRONO_SCRIPT):
        self.script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), script_path))
        if not os.path.exists(self.script_path):
            print(f"Error: drono_control.sh script not found at {self.script_path}")
            sys.exit(1)
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get a list of all connected Android devices using ADB"""
        try:
            # Run ADB devices command
            result = subprocess.run(["adb", "devices", "-l"], capture_output=True, text=True, check=True)
            
            devices = []
            lines = result.stdout.strip().split("\n")[1:]  # Skip header line
            
            for line in lines:
                if not line.strip():
                    continue
                
                parts = line.split()
                if len(parts) >= 2:
                    device_id = parts[0]
                    status = parts[1]
                    
                    # Extract model info
                    model = "Unknown"
                    model_match = re.search(r'model:(\S+)', line)
                    if model_match:
                        model = model_match.group(1)
                    
                    # Get battery level
                    try:
                        battery_cmd = ["adb", "-s", device_id, "shell", "dumpsys", "battery", "|", "grep", "level"]
                        battery_result = subprocess.run(" ".join(battery_cmd), shell=True, capture_output=True, text=True)
                        battery = "Unknown"
                        if battery_result.returncode == 0:
                            battery_match = re.search(r'level: (\d+)', battery_result.stdout)
                            if battery_match:
                                battery = f"{battery_match.group(1)}%"
                    except Exception as e:
                        print(f"Warning: Failed to get battery for device {device_id}: {e}")
                        battery = "Unknown"
                    
                    devices.append({
                        'id': device_id,
                        'model': model,
                        'status': 'online' if status == 'device' else 'offline',
                        'battery': battery
                    })
            
            print(f"Found {len(devices)} connected devices")
            return devices
        except subprocess.SubprocessError as e:
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
            print(f"{i}. {device['id']} - {device['model']} ({device['status']}) - Battery: {device['battery']}")
        
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
    
    def build_command(self, command: str, parameters: Dict[str, Any]) -> List[str]:
        """Build the drono_control.sh command with parameters"""
        cmd = [self.script_path]
        
        # Special handling for 'start' command
        if command == "start":
            # Add -settings flag for settings before start
            cmd.append("-settings")
            
            # Add dismiss_restore if specified
            if parameters.get("dismiss_restore"):
                cmd.append("dismiss_restore")
            
            # Add URL parameter if specified
            if "url" in parameters:
                cmd.extend(["url", parameters["url"]])
            
            # Add iterations parameter if specified
            if "iterations" in parameters:
                cmd.extend(["iterations", str(parameters["iterations"])])
            
            # Add min_interval parameter if specified
            if "min_interval" in parameters:
                cmd.extend(["min_interval", str(parameters["min_interval"])])
            
            # Add max_interval parameter if specified
            if "max_interval" in parameters:
                cmd.extend(["max_interval", str(parameters["max_interval"])])
            
            # Add toggle parameters in the format: toggle feature true/false
            for toggle_feature in ["webview_mode", "rotate_ip", "random_devices", "aggressive_clearing"]:
                if toggle_feature in parameters:
                    cmd.extend(["toggle", toggle_feature, str(parameters[toggle_feature]).lower()])
            
            # Add the command at the end
            cmd.append(command)
        else:
            # For other commands, just add the command
            cmd.append(command)
        
        return cmd
    
    def execute_command(self, device_id: str, command: List[str], dry_run: bool = False) -> Dict[str, Any]:
        """Execute a command for a specific device using ADB"""
        # Set ADB_DEVICE_ID environment variable for the script to use
        env = os.environ.copy()
        env["ADB_DEVICE_ID"] = device_id
        
        print(f"Executing: {' '.join(command)}")
        print(f"Device ID: {device_id}")
        
        if dry_run:
            print("Dry run - skipping actual execution")
            return {"success": True, "message": "Dry run completed", "device_id": device_id}
        
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            
            if result.returncode == 0:
                print("Command executed successfully")
                return {"success": True, "message": "Command executed successfully", "device_id": device_id}
            else:
                print(f"Command failed with exit code {result.returncode}")
                print(f"Error: {result.stderr}")
                return {
                    "success": False, 
                    "message": f"Command failed with exit code {result.returncode}",
                    "error": result.stderr,
                    "device_id": device_id
                }
        except Exception as e:
            print(f"Error executing command: {e}")
            return {"success": False, "message": str(e), "device_id": device_id}
    
    def execute_for_multiple_devices(self, command: str, parameters: Dict[str, Any], 
                                    selected_devices: List[Dict[str, Any]], dry_run: bool = False) -> Dict[str, Any]:
        """Execute the command for multiple devices in sequence"""
        results = {}
        cmd = self.build_command(command, parameters)
        
        for device in selected_devices:
            device_id = device['id']
            print(f"\n{'=' * 60}")
            print(f"Processing device: {device_id} ({device['model']})")
            print(f"{'=' * 60}")
            
            result = self.execute_command(device_id, cmd, dry_run)
            results[device_id] = result
            
            print(f"\nResult: {'Success' if result.get('success', False) else 'Failed'}")
            
            # Add a delay between devices
            if device != selected_devices[-1]:  # Don't delay after the last device
                print("\nWaiting 3 seconds before processing next device...")
                time.sleep(3)
        
        return results

def parse_arguments():
    parser = argparse.ArgumentParser(description='Send commands to multiple Android devices using drono_control.sh')
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
    
    # Initialize the multi-drono control tool
    tool = MultiDronoControl()
    
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
        confirm = input("\nExecute this command on all selected devices? (y/n): ")
        if confirm.lower() != 'y':
            print("Aborted by user. Exiting.")
            sys.exit(0)
    
    # Execute commands on all selected devices
    results = tool.execute_for_multiple_devices(args.command, parameters, selected_devices, args.dry_run)
    
    # Print summary
    success_count = sum(1 for r in results.values() if r.get('success', False))
    print(f"\n{'=' * 60}")
    print(f"SUMMARY: Command executed on {len(results)} devices, {success_count} successful, {len(results) - success_count} failed")
    print(f"{'=' * 60}")
    
    return results

if __name__ == "__main__":
    main() 