#!/usr/bin/env python3
import argparse
import requests
import json
import time
import sys
import logging
from typing import Optional, Dict, Any, List

# Setup logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("CommandClient")

# Default settings
DEFAULT_SERVER = "localhost"
DEFAULT_PORT = 8000
DEFAULT_URL = "https://veewoy.com/ip-text"
DEFAULT_ITERATIONS = 500

class DronoApiClient:
    def __init__(self, server: str, port: int, token: Optional[str] = None):
        self.server = server
        self.port = port
        self.base_url = f"http://{server}:{port}"
        self.token = token
        self.session = requests.Session()
        
        # Setup auth header if token provided
        if token:
            self.session.headers.update({"Authorization": f"Bearer {token}"})
    
    def _get_headers(self) -> Dict[str, str]:
        """Get headers for API requests"""
        headers = {"Content-Type": "application/json"}
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers
    
    def get_devices(self) -> List[Dict[str, Any]]:
        """Get list of available devices"""
        try:
            response = self.session.get(f"{self.base_url}/devices")
            response.raise_for_status()
            data = response.json()
            return data.get("devices", [])
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching devices: {e}")
            return []
    
    def scan_devices(self) -> List[Dict[str, Any]]:
        """Scan for new devices"""
        try:
            response = self.session.get(f"{self.base_url}/devices/scan")
            response.raise_for_status()
            data = response.json()
            return data.get("devices", [])
        except requests.exceptions.RequestException as e:
            logger.error(f"Error scanning devices: {e}")
            return []
    
    def get_device_status(self, device_id: str) -> Dict[str, Any]:
        """Get status for a specific device"""
        try:
            response = self.session.get(f"{self.base_url}/devices/{device_id}/status")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error getting device status: {e}")
            return {}
    
    def start_simulation(self, device_id: str, url: str, iterations: int, 
                         min_interval: int = 1, max_interval: int = 2, webview_mode: bool = True) -> Dict[str, Any]:
        """Start simulation on a device"""
        try:
            payload = {
                "device_id": device_id,
                "url": url,
                "iterations": iterations,
                "min_interval": min_interval,
                "max_interval": max_interval,
                "webview_mode": webview_mode
            }
            
            response = self.session.post(
                f"{self.base_url}/commands/start", 
                json=payload
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error starting simulation: {e}")
            return {"success": False, "error": str(e)}
    
    def stop_simulation(self, device_id: str) -> Dict[str, Any]:
        """Stop simulation on a device"""
        try:
            payload = {"device_id": device_id}
            
            response = self.session.post(
                f"{self.base_url}/commands/stop", 
                json=payload
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error stopping simulation: {e}")
            return {"success": False, "error": str(e)}
    
    def login(self, username: str, password: str) -> bool:
        """Login to get authentication token"""
        try:
            payload = {
                "username": username,
                "password": password
            }
            
            response = self.session.post(
                f"{self.base_url}/auth/token", 
                data=payload
            )
            response.raise_for_status()
            
            data = response.json()
            self.token = data.get("access_token")
            
            if self.token:
                self.session.headers.update({"Authorization": f"Bearer {self.token}"})
                logger.info("Successfully authenticated")
                return True
            else:
                logger.error("Authentication failed: No token received")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Authentication error: {e}")
            return False

def get_device_selection(client: DronoApiClient) -> Optional[str]:
    """Interactive device selection"""
    devices = client.get_devices()
    
    if not devices:
        logger.error("No devices found. Try scanning for devices first.")
        return None
    
    print("\nAvailable devices:")
    for i, device in enumerate(devices):
        status = "RUNNING" if device.get("running", False) else "STOPPED"
        print(f"{i+1}. {device.get('model', 'Unknown')} ({device.get('id')}) - {status}")
    
    try:
        selection = input("\nSelect device number (or press Enter to cancel): ")
        if not selection:
            return None
            
        device_index = int(selection) - 1
        if 0 <= device_index < len(devices):
            return devices[device_index]["id"]
        else:
            logger.error("Invalid selection")
            return None
    except ValueError:
        logger.error("Please enter a valid number")
        return None
    except KeyboardInterrupt:
        return None

def interactive_mode(client: DronoApiClient):
    """Run interactive commands"""
    print("\nDrono Command Client")
    print("===================")
    print("Commands:")
    print("  devices         - List connected devices")
    print("  scan            - Scan for new devices")
    print("  status <id>     - Get status for a device")
    print("  start           - Start simulation (interactive)")
    print("  stop            - Stop simulation (interactive)")
    print("  quit/exit       - Exit the client")
    print()
    
    while True:
        try:
            command = input("> ").strip()
            
            if command.lower() in ("quit", "exit"):
                print("Exiting...")
                return
            
            elif command.lower() == "devices":
                devices = client.get_devices()
                if not devices:
                    print("No devices found")
                else:
                    print(f"Found {len(devices)} device(s):")
                    for device in devices:
                        status = "RUNNING" if device.get("running", False) else "STOPPED"
                        print(f"• {device.get('model', 'Unknown')} ({device.get('id')}) - {status}")
            
            elif command.lower() == "scan":
                print("Scanning for devices...")
                devices = client.scan_devices()
                print(f"Found {len(devices)} device(s)")
            
            elif command.lower().startswith("status"):
                parts = command.split(maxsplit=1)
                if len(parts) < 2:
                    # Interactive selection
                    device_id = get_device_selection(client)
                    if not device_id:
                        continue
                else:
                    device_id = parts[1].strip()
                
                print(f"Getting status for device {device_id}...")
                status = client.get_device_status(device_id)
                
                if status:
                    device_info = status.get("device", {})
                    sim_info = status.get("simulation", {})
                    
                    print(f"\nDevice: {device_info.get('model', 'Unknown')} ({device_info.get('id')})")
                    print(f"Status: {device_info.get('status', 'Unknown')}")
                    print(f"Running: {'Yes' if sim_info.get('is_running', False) else 'No'}")
                    
                    if "url" in sim_info:
                        print(f"URL: {sim_info.get('url')}")
                    if "iterations" in sim_info:
                        print(f"Iterations: {sim_info.get('iterations')}")
                    
                    # Display progress if available
                    if "current_iteration" in sim_info and "iterations" in sim_info:
                        current = sim_info.get("current_iteration")
                        total = sim_info.get("iterations")
                        if total > 0:
                            percentage = round((current / total) * 100, 1)
                            # Create a simple ASCII progress bar
                            bar_length = 30
                            filled_length = int(bar_length * current // total)
                            bar = '█' * filled_length + '░' * (bar_length - filled_length)
                            print(f"Progress: {current}/{total} ({percentage}%)")
                            print(f"[{bar}]")
                else:
                    print("Failed to get status or device not found")
            
            elif command.lower() == "start":
                device_id = get_device_selection(client)
                if not device_id:
                    continue
                
                # Get parameters
                try:
                    url = input(f"URL to test [{DEFAULT_URL}]: ").strip() or DEFAULT_URL
                    iterations_str = input(f"Number of iterations [{DEFAULT_ITERATIONS}]: ").strip() or str(DEFAULT_ITERATIONS)
                    iterations = int(iterations_str)
                    
                    min_interval_str = input("Min interval in seconds [1]: ").strip() or "1"
                    min_interval = int(min_interval_str)
                    
                    max_interval_str = input("Max interval in seconds [2]: ").strip() or "2"
                    max_interval = int(max_interval_str)
                    
                    webview_mode = input("Use WebView mode? (y/n) [y]: ").strip().lower() != "n"
                    
                    print(f"\nStarting simulation on device {device_id}...")
                    result = client.start_simulation(
                        device_id, url, iterations, 
                        min_interval, max_interval, webview_mode
                    )
                    
                    if result.get("success", False):
                        print("Simulation started successfully")
                    else:
                        print(f"Failed to start simulation: {result.get('error', 'Unknown error')}")
                        
                except ValueError:
                    print("Please enter valid numbers for numeric fields")
                except KeyboardInterrupt:
                    print("\nOperation cancelled")
            
            elif command.lower() == "stop":
                device_id = get_device_selection(client)
                if not device_id:
                    continue
                
                print(f"Stopping simulation on device {device_id}...")
                result = client.stop_simulation(device_id)
                
                if result.get("success", False):
                    print("Simulation stopped successfully")
                else:
                    print(f"Failed to stop simulation: {result.get('error', 'Unknown error')}")
            
            else:
                print("Unknown command. Type 'quit' to exit.")
                
        except KeyboardInterrupt:
            print("\nExiting...")
            return
        except Exception as e:
            print(f"Error: {e}")

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Command Client for Drono App")
    parser.add_argument("--server", default=DEFAULT_SERVER, help=f"Server hostname (default: {DEFAULT_SERVER})")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Server port (default: {DEFAULT_PORT})")
    parser.add_argument("--token", help="Authentication token")
    parser.add_argument("--username", help="Username for authentication")
    parser.add_argument("--password", help="Password for authentication")
    
    # Action commands
    action_group = parser.add_argument_group("Actions")
    action_group.add_argument("--list", action="store_true", help="List connected devices")
    action_group.add_argument("--scan", action="store_true", help="Scan for new devices")
    action_group.add_argument("--status", metavar="DEVICE_ID", help="Get status for a device")
    action_group.add_argument("--start", metavar="DEVICE_ID", help="Start simulation on a device")
    action_group.add_argument("--stop", metavar="DEVICE_ID", help="Stop simulation on a device")
    
    # Simulation parameters
    sim_group = parser.add_argument_group("Simulation Parameters")
    sim_group.add_argument("--url", default=DEFAULT_URL, help=f"URL to test (default: {DEFAULT_URL})")
    sim_group.add_argument("--iterations", type=int, default=DEFAULT_ITERATIONS, 
                          help=f"Number of iterations (default: {DEFAULT_ITERATIONS})")
    sim_group.add_argument("--min-interval", type=int, default=1, help="Min interval in seconds (default: 1)")
    sim_group.add_argument("--max-interval", type=int, default=2, help="Max interval in seconds (default: 2)")
    sim_group.add_argument("--no-webview", action="store_true", help="Don't use WebView mode")
    
    return parser.parse_args()

def main():
    """Main entry point"""
    args = parse_args()
    
    # Create API client
    client = DronoApiClient(args.server, args.port, args.token)
    
    # Authenticate if credentials provided
    if not args.token and args.username and args.password:
        if not client.login(args.username, args.password):
            logger.error("Authentication failed. Exiting.")
            return 1
    
    # Check if any action was specified
    has_action = any([args.list, args.scan, args.status, args.start, args.stop])
    
    if not has_action:
        # Run interactive mode if no action specified
        interactive_mode(client)
        return 0
    
    # Execute requested actions
    if args.list:
        devices = client.get_devices()
        print(f"Found {len(devices)} device(s):")
        for device in devices:
            status = "RUNNING" if device.get("running", False) else "STOPPED"
            print(f"• {device.get('model', 'Unknown')} ({device.get('id')}) - {status}")
    
    if args.scan:
        print("Scanning for devices...")
        devices = client.scan_devices()
        print(f"Found {len(devices)} device(s)")
    
    if args.status:
        status = client.get_device_status(args.status)
        if status:
            device_info = status.get("device", {})
            sim_info = status.get("simulation", {})
            
            print(f"\nDevice: {device_info.get('model', 'Unknown')} ({device_info.get('id')})")
            print(f"Status: {device_info.get('status', 'Unknown')}")
            print(f"Running: {'Yes' if sim_info.get('is_running', False) else 'No'}")
            
            if "url" in sim_info:
                print(f"URL: {sim_info.get('url')}")
            if "iterations" in sim_info:
                print(f"Iterations: {sim_info.get('iterations')}")
            
            # Display progress if available
            if "current_iteration" in sim_info and "iterations" in sim_info:
                current = sim_info.get("current_iteration")
                total = sim_info.get("iterations")
                if total > 0:
                    percentage = round((current / total) * 100, 1)
                    # Create a simple ASCII progress bar
                    bar_length = 30
                    filled_length = int(bar_length * current // total)
                    bar = '█' * filled_length + '░' * (bar_length - filled_length)
                    print(f"Progress: {current}/{total} ({percentage}%)")
                    print(f"[{bar}]")
        else:
            print("Failed to get status or device not found")
    
    if args.start:
        # Get simulation parameters
        webview_mode = not args.no_webview
        
        # Start simulation
        result = client.start_simulation(
            args.start, args.url, args.iterations, 
            args.min_interval, args.max_interval, webview_mode
        )
        
        if result.get("success", False):
            print(f"Simulation started successfully on device {args.start}")
        else:
            print(f"Failed to start simulation: {result.get('error', 'Unknown error')}")
    
    if args.stop:
        result = client.stop_simulation(args.stop)
        
        if result.get("success", False):
            print(f"Simulation stopped successfully on device {args.stop}")
        else:
            print(f"Failed to stop simulation: {result.get('error', 'Unknown error')}")
    
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
        sys.exit(0) 