#!/usr/bin/env python3
"""
Demo Control Script for Drono Server
This script demonstrates how to authenticate with the server and control devices
"""

import argparse
import json
import requests
import time
import sys
from datetime import datetime

class DronoClient:
    """Client for interacting with the Drono server"""
    
    def __init__(self, server, port, username=None, password=None, token=None):
        self.base_url = f"http://{server}:{port}"
        self.token = token
        self.username = username
        self.password = password
        
        # If token not provided but credentials are, authenticate immediately
        if not token and username and password:
            self.authenticate()
    
    def authenticate(self):
        """Authenticate with the server and get a JWT token"""
        print(f"Authenticating as {self.username}...")
        
        auth_url = f"{self.base_url}/auth/token"
        data = {"username": self.username, "password": self.password}
        
        try:
            response = requests.post(auth_url, data=data)
            if response.status_code == 200:
                result = response.json()
                self.token = result.get("access_token")
                print("Authentication successful!")
                return True
            else:
                print(f"Authentication failed: HTTP {response.status_code}")
                if response.status_code == 401:
                    print("Invalid username or password")
                return False
        except Exception as e:
            print(f"Authentication error: {e}")
            return False
    
    def get_headers(self):
        """Get HTTP headers with authentication token"""
        if not self.token:
            raise ValueError("Not authenticated. Call authenticate() first.")
        return {"Authorization": f"Bearer {self.token}"}
    
    def get_devices(self):
        """Get a list of connected devices"""
        try:
            response = requests.get(
                f"{self.base_url}/devices",
                headers=self.get_headers()
            )
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Failed to get devices: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"Error getting devices: {e}")
            return None
    
    def get_device_status(self, device_id):
        """Get detailed status for a specific device"""
        try:
            response = requests.get(
                f"{self.base_url}/devices/{device_id}/status",
                headers=self.get_headers()
            )
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Failed to get device status: HTTP {response.status_code}")
                return None
        except Exception as e:
            print(f"Error getting device status: {e}")
            return None
    
    def start_simulation(self, device_id, url, iterations, min_interval, max_interval, webview_mode=True):
        """Start a simulation on a device"""
        try:
            data = {
                "device_id": device_id,
                "url": url,
                "iterations": iterations,
                "min_interval": min_interval,
                "max_interval": max_interval,
                "webview_mode": webview_mode
            }
            
            response = requests.post(
                f"{self.base_url}/commands/start",
                headers=self.get_headers(),
                json=data
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Failed to start simulation: HTTP {response.status_code}")
                if response.text:
                    print(f"Error: {response.text}")
                return {"success": False, "error": f"HTTP {response.status_code}"}
        except Exception as e:
            print(f"Error starting simulation: {e}")
            return {"success": False, "error": str(e)}
    
    def stop_simulation(self, device_id):
        """Stop a simulation on a device"""
        try:
            data = {"device_id": device_id}
            
            response = requests.post(
                f"{self.base_url}/commands/stop",
                headers=self.get_headers(),
                json=data
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                print(f"Failed to stop simulation: HTTP {response.status_code}")
                return {"success": False, "error": f"HTTP {response.status_code}"}
        except Exception as e:
            print(f"Error stopping simulation: {e}")
            return {"success": False, "error": str(e)}
    
    def monitor_progress(self, device_id, delay=2, max_iterations=None):
        """Monitor progress of a simulation with updates"""
        iteration = 0
        start_time = time.time()
        last_iteration = 0
        
        try:
            while True:
                status = self.get_device_status(device_id)
                if not status:
                    print("Failed to get status update")
                    time.sleep(delay)
                    continue
                
                device_info = status.get("device", {})
                sim_info = status.get("simulation", {})
                
                is_running = sim_info.get("is_running", False)
                if not is_running:
                    print("\nSimulation is not running")
                    break
                
                current = sim_info.get("current_iteration", 0)
                total = sim_info.get("iterations", 0)
                
                if total > 0:
                    # Only show update if the iteration has changed
                    if current != last_iteration:
                        last_iteration = current
                        percentage = round((current / total) * 100, 1)
                        
                        # Calculate estimated time remaining
                        elapsed = time.time() - start_time
                        if current > 1:  # Avoid division by zero
                            time_per_iteration = elapsed / (current - 1)
                            remaining_iterations = total - current
                            remaining_seconds = time_per_iteration * remaining_iterations
                            
                            # Format time remaining
                            remaining_str = ""
                            if remaining_seconds > 3600:
                                hours = int(remaining_seconds // 3600)
                                minutes = int((remaining_seconds % 3600) // 60)
                                remaining_str = f"{hours}h {minutes}m"
                            elif remaining_seconds > 60:
                                minutes = int(remaining_seconds // 60)
                                seconds = int(remaining_seconds % 60)
                                remaining_str = f"{minutes}m {seconds}s"
                            else:
                                remaining_str = f"{int(remaining_seconds)}s"
                            
                            # Print progress with percentage and time remaining
                            print(f"\rProgress: {current}/{total} ({percentage}%) - Est. remaining: {remaining_str}", end="")
                        else:
                            # Not enough data to calculate time remaining
                            print(f"\rProgress: {current}/{total} ({percentage}%)", end="")
                        
                        sys.stdout.flush()
                        
                        # If max_iterations is set and we've reached it, stop
                        if max_iterations and current >= max_iterations:
                            print("\nReached maximum iterations to monitor")
                            break
                
                time.sleep(delay)
                iteration += 1
                
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user")
        
        print("\nDone monitoring progress")


def main():
    """Main entry point for the demo script"""
    parser = argparse.ArgumentParser(description="Drono Server Demo Control Script")
    
    # Server connection
    parser.add_argument("--server", type=str, default="localhost", help="Server hostname")
    parser.add_argument("--port", type=int, default=8000, help="Server port")
    
    # Authentication
    parser.add_argument("--token", type=str, help="Authentication token")
    parser.add_argument("--username", type=str, default="admin", help="Username for authentication")
    parser.add_argument("--password", type=str, default="adminpassword", help="Password for authentication")
    
    # Actions
    parser.add_argument("--list", action="store_true", help="List connected devices")
    parser.add_argument("--status", type=str, help="Get status for a device (device ID)")
    parser.add_argument("--start", type=str, help="Start simulation on a device (device ID)")
    parser.add_argument("--stop", type=str, help="Stop simulation on a device (device ID)")
    parser.add_argument("--monitor", type=str, help="Monitor progress of a device (device ID)")
    
    # Simulation parameters
    parser.add_argument("--url", type=str, default="https://veewoy.com/ip-text", help="URL to test")
    parser.add_argument("--iterations", type=int, default=50, help="Number of iterations")
    parser.add_argument("--min-interval", type=float, default=1, help="Minimum interval (seconds)")
    parser.add_argument("--max-interval", type=float, default=2, help="Maximum interval (seconds)")
    parser.add_argument("--no-webview", action="store_true", help="Disable WebView mode")
    
    args = parser.parse_args()
    
    # Create client and authenticate
    client = DronoClient(
        args.server, 
        args.port, 
        username=args.username,
        password=args.password,
        token=args.token
    )
    
    # If no token provided and no authentication occurred, exit
    if not client.token:
        print("No authentication token available. Exiting.")
        return
    
    # List devices
    if args.list:
        response = client.get_devices()
        if response:
            print(f"\nFound {response.get('count', 0)} devices:")
            for device in response.get("devices", []):
                status = "🟢 Running" if device.get("running", False) else "🔴 Stopped"
                print(f"- {device.get('id')}: {device.get('model', 'Unknown')} - {status}")
    
    # Get status
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
                    print(f"Progress: {current}/{total} ({percentage}%)")
    
    # Start simulation
    if args.start:
        webview_mode = not args.no_webview
        
        print(f"\nStarting simulation on device {args.start}:")
        print(f"URL: {args.url}")
        print(f"Iterations: {args.iterations}")
        print(f"Interval: {args.min_interval}-{args.max_interval} seconds")
        print(f"WebView Mode: {'Disabled' if args.no_webview else 'Enabled'}")
        
        result = client.start_simulation(
            args.start, args.url, args.iterations, 
            args.min_interval, args.max_interval, webview_mode
        )
        
        if result.get("success", False):
            print("Simulation started successfully")
            
            # Auto-monitor if requested
            if args.monitor and args.monitor.lower() == "auto":
                print("Auto-monitoring progress...")
                client.monitor_progress(args.start)
        else:
            print(f"Failed to start simulation: {result.get('error', 'Unknown error')}")
    
    # Stop simulation
    if args.stop:
        print(f"\nStopping simulation on device {args.stop}...")
        result = client.stop_simulation(args.stop)
        
        if result.get("success", False):
            print("Simulation stopped successfully")
        else:
            print(f"Failed to stop simulation: {result.get('error', 'Unknown error')}")
    
    # Monitor progress
    if args.monitor and args.monitor != "auto":
        print(f"\nMonitoring progress on device {args.monitor}...")
        client.monitor_progress(args.monitor)


if __name__ == "__main__":
    main() 