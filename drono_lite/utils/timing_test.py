#!/usr/bin/env python3
"""
Timing Test Script for Drono Lite

This script demonstrates how to use the new timing information API
to get detailed timing information from Android devices.
"""

import requests
import json
import time
import sys
import argparse
from datetime import datetime, timedelta

# Default API URL
DEFAULT_API_URL = "http://localhost:8000"

def format_time_ms(ms):
    """Format milliseconds as HH:MM:SS.mmm"""
    seconds = ms / 1000
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    seconds = seconds % 60
    return f"{hours:02d}:{minutes:02d}:{seconds:06.3f}"

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Test Drono Lite timing information API')
    parser.add_argument('--api-url', type=str, default=DEFAULT_API_URL,
                       help=f'API URL (default: {DEFAULT_API_URL})')
    parser.add_argument('--device-id', type=str,
                       help='Specific device ID to monitor (default: monitor all devices)')
    parser.add_argument('--interval', type=int, default=5,
                       help='Polling interval in seconds (default: 5)')
    parser.add_argument('--count', type=int, default=0,
                       help='Number of polls (0 for infinite, default: 0)')
    args = parser.parse_args()
    
    # Validate API URL
    api_url = args.api_url.rstrip('/')
    
    # Get device ID or list all devices
    device_id = args.device_id
    if not device_id:
        try:
            # Get list of devices
            response = requests.get(f"{api_url}/devices")
            if response.status_code != 200:
                print(f"Error getting devices: {response.status_code} - {response.text}")
                return 1
            
            devices = response.json().get("devices", [])
            if not devices:
                print("No devices found.")
                return 1
            
            # Print devices and let user select one
            print("Available devices:")
            for i, device in enumerate(devices):
                print(f"{i+1}. {device['id']} - {device.get('model', 'Unknown')} ({device.get('status', 'Unknown')})")
            
            selection = input("Enter device number (or 'all' to monitor all): ")
            if selection.lower() == 'all':
                device_id = None
            else:
                try:
                    idx = int(selection) - 1
                    if idx < 0 or idx >= len(devices):
                        print("Invalid selection.")
                        return 1
                    device_id = devices[idx]['id']
                except (ValueError, IndexError):
                    print("Invalid selection.")
                    return 1
        except Exception as e:
            print(f"Error: {e}")
            return 1
    
    # Monitor timing information
    count = 0
    try:
        while args.count == 0 or count < args.count:
            count += 1
            print(f"\n--- Poll #{count} at {datetime.now().strftime('%H:%M:%S')} ---")
            
            if device_id:
                # Get timing for specific device
                try:
                    response = requests.get(f"{api_url}/devices/{device_id}/timing")
                    if response.status_code != 200:
                        print(f"Error getting timing: {response.status_code} - {response.text}")
                        continue
                    
                    data = response.json()
                    timing_info = data.get("timing_info", {})
                    
                    if timing_info.get("success", False):
                        actual_elapsed = timing_info.get("actual_elapsed_ms", 0)
                        remaining = timing_info.get("remaining_time_ms", 0)
                        current = timing_info.get("current_iteration", 0)
                        total = timing_info.get("total_iterations", 0)
                        
                        # Format times
                        elapsed_formatted = format_time_ms(actual_elapsed)
                        remaining_formatted = format_time_ms(remaining)
                        
                        # Calculate estimated completion time
                        completion_time = datetime.now() + timedelta(milliseconds=remaining)
                        
                        # Calculate progress percentage
                        percentage = (current / total * 100) if total > 0 else 0
                        
                        print(f"Device: {device_id}")
                        print(f"Progress: {current}/{total} ({percentage:.1f}%)")
                        print(f"Elapsed Time: {elapsed_formatted}")
                        print(f"Remaining Time: {remaining_formatted}")
                        print(f"Estimated Completion: {completion_time.strftime('%H:%M:%S')}")
                    else:
                        print(f"Device {device_id}: No timing information available")
                except Exception as e:
                    print(f"Error: {e}")
            else:
                # Get status for all devices
                try:
                    response = requests.get(f"{api_url}/devices/status")
                    if response.status_code != 200:
                        print(f"Error getting status: {response.status_code} - {response.text}")
                        continue
                    
                    devices_status = response.json().get("devices_status", {})
                    
                    if not devices_status:
                        print("No devices status available")
                        continue
                    
                    for dev_id, status in devices_status.items():
                        if status.get("is_running", False):
                            current = status.get("current_iteration", 0)
                            total = status.get("total_iterations", 0)
                            elapsed = status.get("elapsed_time", 0) * 1000  # Convert to ms
                            remaining = status.get("estimated_remaining", 0) * 1000  # Convert to ms
                            
                            # Format times
                            elapsed_formatted = format_time_ms(elapsed)
                            remaining_formatted = format_time_ms(remaining)
                            
                            # Calculate estimated completion time
                            completion_time = datetime.now() + timedelta(milliseconds=remaining)
                            
                            # Calculate progress percentage
                            percentage = (current / total * 100) if total > 0 else 0
                            
                            print(f"Device: {dev_id}")
                            print(f"Progress: {current}/{total} ({percentage:.1f}%)")
                            print(f"Elapsed Time: {elapsed_formatted}")
                            print(f"Remaining Time: {remaining_formatted}")
                            print(f"Estimated Completion: {completion_time.strftime('%H:%M:%S')}")
                            print("---")
                except Exception as e:
                    print(f"Error: {e}")
            
            # Wait for next poll
            if args.count == 0 or count < args.count:
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 