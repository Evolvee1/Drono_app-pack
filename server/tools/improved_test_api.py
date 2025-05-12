#!/usr/bin/env python3
"""
Improved Test Client for Device Settings API
A simplified and more reliable client for interacting with the Settings API
"""
import argparse
import requests
import json
import sys
import os
from typing import Dict, Any, List, Optional

API_BASE_URL = "http://localhost:8000"  # Default API URL

class ApiClient:
    """Client for interacting with the Device Settings API"""
    
    def __init__(self, base_url: str = API_BASE_URL):
        self.base_url = base_url
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get a list of connected devices"""
        response = self._make_request("GET", "/devices")
        return response.get("devices", [])
    
    def set_url(self, url: str, devices: Optional[List[str]] = None, all_devices: bool = False, 
               **kwargs) -> Dict[str, Any]:
        """Set URL on devices using the improved API"""
        payload = {
            "url": url,
            "devices": devices,
            "all_devices": all_devices
        }
        
        # Add any additional parameters
        for key, value in kwargs.items():
            payload[key] = value
        
        return self._make_request("POST", "/set-url", payload)
    
    def apply_settings(self, settings: Dict[str, Any], devices: Optional[List[str]] = None, 
                      all_devices: bool = False, parallel: bool = True) -> Dict[str, Any]:
        """Apply general settings to devices"""
        payload = {
            "settings": settings,
            "devices": devices,
            "all_devices": all_devices,
            "parallel": parallel
        }
        return self._make_request("POST", "/apply-settings", payload)
    
    def _make_request(self, method: str, endpoint: str, data: Any = None) -> Dict[str, Any]:
        """Make a request to the API"""
        url = f"{self.base_url}{endpoint}"
        
        try:
            if method.upper() == "GET":
                response = requests.get(url)
            elif method.upper() == "POST":
                response = requests.post(url, json=data)
            else:
                raise ValueError(f"Unsupported HTTP method: {method}")
            
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error making request to {url}: {e}")
            if hasattr(e.response, 'text'):
                print(f"Response: {e.response.text}")
            sys.exit(1)
        except Exception as e:
            print(f"Unexpected error: {e}")
            sys.exit(1)

def print_device_table(devices: List[Dict[str, Any]]):
    """Print a formatted table of devices"""
    if not devices:
        print("No devices found")
        return
    
    # Get max lengths for formatting
    id_len = max(len(device["id"]) for device in devices)
    model_len = max(len(str(device.get("model", "Unknown"))) for device in devices)
    
    # Print header
    print(f"{'ID':<{id_len+2}} {'Model':<{model_len+2}} Status")
    print("-" * (id_len + model_len + 15))
    
    # Print each device
    for device in devices:
        print(f"{device['id']:<{id_len+2}} {str(device.get('model', 'Unknown')):<{model_len+2}} {device['status']}")

def print_result_summary(result: Dict[str, Any], verbose: bool = False):
    """Print a summary of the operation result"""
    print(f"\nOperation status: {result['status']}")
    print(f"Devices: {result['count']} total, {result.get('success_count', 0)} successful")
    
    if 'results' in result and result['results']:
        print("\nDevice results:")
        
        for device_id, device_result in result['results'].items():
            status_icon = "✅" if device_result['status'] == "success" else "❌"
            print(f"{status_icon} {device_id}: {device_result['message']}")
            
            if verbose and 'details' in device_result:
                details = device_result['details']
                print(f"  Details:")
                for key, value in details.items():
                    print(f"    {key}: {value}")

def command_list_devices(client: ApiClient, args: argparse.Namespace):
    """List all connected devices"""
    print("Getting connected devices...\n")
    devices = client.get_devices()
    print_device_table(devices)
    print(f"\nTotal devices: {len(devices)}")

def command_set_url(client: ApiClient, args: argparse.Namespace):
    """Set URL on devices"""
    if not args.url:
        print("Error: URL is required")
        sys.exit(1)
    
    if not args.devices and not args.all_devices:
        print("Error: Either specify devices with --devices or use --all-devices")
        sys.exit(1)
    
    # Get target devices for display purposes
    if args.all_devices:
        print("Getting all connected devices...")
        devices = client.get_devices()
        target_devices = [device["id"] for device in devices]
    else:
        target_devices = args.devices
    
    print(f"Setting URL on {len(target_devices)} device(s):")
    for device_id in target_devices:
        print(f"  - {device_id}")
    
    print(f"\nURL: {args.url}")
    
    # Create additional parameters dictionary
    params = {
        "iterations": args.iterations,
        "min_interval": args.min_interval,
        "max_interval": args.max_interval,
        "webview_mode": args.webview_mode,
        "rotate_ip": args.rotate_ip,
        "random_devices": args.random_devices,
        "new_webview_per_request": args.new_webview_per_request,
        "restore_on_exit": args.restore_on_exit,
        "parallel": args.parallel
    }
    
    if args.use_proxy:
        params["use_proxy"] = True
        params["proxy_address"] = args.proxy_address
        params["proxy_port"] = args.proxy_port
    
    print("Sending command...")
    result = client.set_url(
        url=args.url,
        devices=None if args.all_devices else args.devices,
        all_devices=args.all_devices,
        **params
    )
    
    print_result_summary(result, args.verbose)

def command_help(client: ApiClient, args: argparse.Namespace):
    """Show help guide"""
    print("Device Settings API Test Client Help")
    print("===================================")
    print("\nThis utility helps you interact with the Device Settings API to manage settings on Android devices.\n")
    
    print("Main Commands:")
    print("  list                    List all connected devices")
    print("  set-url                 Set URL on specific devices (with maximum reliability)")
    print("  help                    Show this help message\n")
    
    print("Usage Examples:")
    print("  # List connected devices:")
    print("  python improved_test_api.py list\n")
    
    print("  # Set URL on specific devices:")
    print("  python improved_test_api.py set-url --url \"https://example.com\" --devices emulator-5554\n")
    
    print("  # Set URL on all devices:")
    print("  python improved_test_api.py set-url --url \"https://example.com\" --all-devices\n")
    
    print("  # Set URL with additional parameters:")
    print("  python improved_test_api.py set-url --url \"https://example.com\" --devices emulator-5554 --iterations 500 --min-interval 2 --max-interval 5 --no-webview-mode\n")

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Improved Test Client for Device Settings API")
    
    # Add global options
    parser.add_argument("--api-url", help="API base URL", default=API_BASE_URL)
    parser.add_argument("--verbose", "-v", action="store_true", help="Show verbose output")
    
    # Create subparsers for different commands
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # List devices command
    list_parser = subparsers.add_parser("list", help="List all connected devices")
    
    # Set URL command
    url_parser = subparsers.add_parser("set-url", help="Set URL on devices with maximum reliability")
    url_parser.add_argument("--url", required=True, help="Target URL")
    device_group = url_parser.add_mutually_exclusive_group(required=True)
    device_group.add_argument("--all-devices", action="store_true", help="Target all connected devices")
    device_group.add_argument("--devices", nargs="+", help="Specific device IDs to target")
    
    # URL parameters
    url_parser.add_argument("--iterations", type=int, default=1000, help="Number of iterations to run")
    url_parser.add_argument("--min-interval", type=int, default=1, help="Minimum interval between requests (seconds)")
    url_parser.add_argument("--max-interval", type=int, default=2, help="Maximum interval between requests (seconds)")
    
    # Feature flags
    url_parser.add_argument("--webview-mode", action="store_true", default=True, help="Use webview mode")
    url_parser.add_argument("--no-webview-mode", dest="webview_mode", action="store_false", help="Disable webview mode")
    url_parser.add_argument("--rotate-ip", action="store_true", default=True, help="Rotate IP between requests")
    url_parser.add_argument("--no-rotate-ip", dest="rotate_ip", action="store_false", help="Disable IP rotation")
    url_parser.add_argument("--random-devices", action="store_true", default=True, help="Use random device profiles")
    url_parser.add_argument("--no-random-devices", dest="random_devices", action="store_false", help="Disable random device profiles")
    url_parser.add_argument("--new-webview-per-request", action="store_true", default=True, help="Create new webview for each request")
    url_parser.add_argument("--no-new-webview-per-request", dest="new_webview_per_request", action="store_false", help="Disable new webview per request")
    url_parser.add_argument("--restore-on-exit", action="store_true", default=False, help="Restore IP on exit")
    url_parser.add_argument("--no-restore-on-exit", dest="restore_on_exit", action="store_false", help="Do not restore IP on exit")
    
    # Proxy settings
    url_parser.add_argument("--use-proxy", action="store_true", default=False, help="Use proxy for connections")
    url_parser.add_argument("--proxy-address", type=str, default="", help="Proxy server address")
    url_parser.add_argument("--proxy-port", type=int, default=0, help="Proxy server port")
    
    # Execution mode
    url_parser.add_argument("--parallel", action="store_true", default=True, help="Process devices in parallel")
    url_parser.add_argument("--sequential", dest="parallel", action="store_false", help="Process devices sequentially")
    
    # Help command
    help_parser = subparsers.add_parser("help", help="Show help guide")
    
    return parser.parse_args()

def main():
    """Main entry point"""
    args = parse_args()
    
    # Create API client
    client = ApiClient(args.api_url)
    
    # Execute the selected command
    if args.command == "list":
        command_list_devices(client, args)
    elif args.command == "set-url":
        command_set_url(client, args)
    elif args.command == "help" or args.command is None:
        command_help(client, args)
    else:
        print(f"Unknown command: {args.command}")
        command_help(client, args)

if __name__ == "__main__":
    main() 