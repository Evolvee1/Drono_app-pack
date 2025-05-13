#!/usr/bin/env python3
"""
URL Distribution Script for Drono Server

This script distributes URLs to multiple connected Android devices
using the drono_control.sh script. It's designed to be used as part
of a REST API server to receive commands from the frontend.
"""

import os
import sys
import json
import logging
import argparse
import subprocess
import time
from typing import List, Dict, Any, Optional
from pathlib import Path

# Configure logging
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "distribute_url.log")
    ]
)
logger = logging.getLogger("distribute_url")

# Path to the drono_control.sh script
SCRIPT_DIR = Path(__file__).parent.parent
DRONO_CONTROL_SCRIPT = SCRIPT_DIR / "android-app" / "drono_control.sh"

def get_connected_devices() -> List[str]:
    """Get a list of connected device IDs."""
    try:
        result = subprocess.run(
            ["adb", "devices"], 
            capture_output=True,
            text=True,
            check=True
        )
        
        # Parse the output to extract device IDs
        lines = result.stdout.strip().split("\n")[1:]  # Skip the first line (header)
        devices = []
        for line in lines:
            if line.strip() and "\tdevice" in line:
                device_id = line.split("\t")[0].strip()
                if device_id:
                    devices.append(device_id)
        
        logger.info(f"Found {len(devices)} connected devices: {', '.join(devices)}")
        return devices
    except subprocess.CalledProcessError as e:
        logger.error(f"Error getting connected devices: {e}")
        return []

def verify_drono_control_script() -> bool:
    """Verify that the drono_control.sh script exists and is executable."""
    script_path = DRONO_CONTROL_SCRIPT
    
    if not script_path.exists():
        logger.error(f"Drono control script not found at {script_path}")
        return False
    
    # Make sure it's executable
    try:
        script_path.chmod(0o755)
        logger.info(f"Ensured {script_path} is executable")
    except Exception as e:
        logger.error(f"Failed to make script executable: {e}")
        return False
    
    return True

def run_on_device(device_id: str, url: str, iterations: int = 100, 
                  min_interval: int = 1, max_interval: int = 2,
                  start: bool = True, use_webview: bool = True,
                  rotate_ip: bool = True) -> Dict[str, Any]:
    """
    Run the drono_control.sh script on a specific device with the given parameters.
    
    Args:
        device_id: The device ID to target
        url: The URL to set
        iterations: Number of iterations
        min_interval: Minimum interval between requests
        max_interval: Maximum interval between requests
        start: Whether to start the simulation after setting parameters
        use_webview: Whether to use webview mode
        rotate_ip: Whether to rotate IP
        
    Returns:
        Dictionary with status and details
    """
    # Construct the command
    cmd = [str(DRONO_CONTROL_SCRIPT), "-settings"]
    
    # Add URL
    cmd.extend(["url", url])
    
    # Add iterations
    cmd.extend(["iterations", str(iterations)])
    
    # Add intervals
    cmd.extend(["min_interval", str(min_interval)])
    cmd.extend(["max_interval", str(max_interval)])
    
    # Add toggle parameters
    cmd.extend(["toggle", "webview_mode", "true" if use_webview else "false"])
    cmd.extend(["toggle", "rotate_ip", "true" if rotate_ip else "false"])
    
    # Add start command if needed
    if start:
        cmd.append("start")
    
    # Set environment variables
    env = os.environ.copy()
    env["ADB_DEVICE_ID"] = device_id
    
    # Run the command
    logger.info(f"Running command for device {device_id}: {' '.join(cmd)}")
    try:
        process = subprocess.run(
            cmd,
            env=env,
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )
        
        success = process.returncode == 0
        
        result = {
            "device_id": device_id,
            "success": success,
            "return_code": process.returncode,
            "stdout": process.stdout,
            "stderr": process.stderr,
            "command": " ".join(cmd)
        }
        
        if success:
            logger.info(f"Successfully ran command on device {device_id}")
        else:
            logger.error(f"Command failed for device {device_id}: {process.stderr}")
        
        return result
    except subprocess.TimeoutExpired as e:
        logger.error(f"Command timed out for device {device_id}")
        return {
            "device_id": device_id,
            "success": False,
            "error": "Command timed out",
            "command": " ".join(cmd)
        }
    except Exception as e:
        logger.error(f"Error running command for device {device_id}: {e}")
        return {
            "device_id": device_id,
            "success": False,
            "error": str(e),
            "command": " ".join(cmd)
        }

def distribute_url(url: str, devices: Optional[List[str]] = None, 
                  iterations: int = 100, min_interval: int = 1, 
                  max_interval: int = 2, parallel: bool = True,
                  start: bool = True, use_webview: bool = True,
                  rotate_ip: bool = True) -> Dict[str, Any]:
    """
    Distribute a URL to multiple devices.
    
    Args:
        url: The URL to distribute
        devices: List of device IDs (None for all connected devices)
        iterations: Number of iterations
        min_interval: Minimum interval between requests
        max_interval: Maximum interval between requests
        parallel: Whether to run commands in parallel
        start: Whether to start the simulation
        use_webview: Whether to use webview mode
        rotate_ip: Whether to rotate IP
        
    Returns:
        Dictionary with results for each device
    """
    # Verify the script exists
    if not verify_drono_control_script():
        return {"success": False, "error": "Drono control script not found or not executable"}
    
    # Get the devices to target
    if devices is None:
        devices = get_connected_devices()
    
    if not devices:
        return {"success": False, "error": "No devices connected"}
    
    results = {}
    
    # Run commands on each device
    if parallel:
        import concurrent.futures
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(devices)) as executor:
            future_to_device = {
                executor.submit(
                    run_on_device, 
                    device_id, 
                    url, 
                    iterations, 
                    min_interval, 
                    max_interval,
                    start,
                    use_webview,
                    rotate_ip
                ): device_id for device_id in devices
            }
            
            for future in concurrent.futures.as_completed(future_to_device):
                device_id = future_to_device[future]
                try:
                    results[device_id] = future.result()
                except Exception as e:
                    logger.error(f"Error processing device {device_id}: {e}")
                    results[device_id] = {
                        "device_id": device_id,
                        "success": False,
                        "error": str(e)
                    }
    else:
        # Sequential execution
        for device_id in devices:
            results[device_id] = run_on_device(
                device_id, 
                url, 
                iterations, 
                min_interval, 
                max_interval,
                start,
                use_webview,
                rotate_ip
            )
    
    # Create summary
    success_count = sum(1 for result in results.values() if result.get("success", False))
    
    summary = {
        "total_devices": len(devices),
        "success_count": success_count,
        "failure_count": len(devices) - success_count,
        "success_rate": round((success_count / len(devices)) * 100, 1) if devices else 0
    }
    
    return {
        "success": success_count > 0,
        "results": results,
        "summary": summary
    }

def main():
    """Main entry point when run as a script."""
    parser = argparse.ArgumentParser(description="Distribute URL to Android devices")
    parser.add_argument("--url", required=True, help="URL to distribute")
    parser.add_argument("--devices", help="Comma-separated list of device IDs (default: all connected)")
    parser.add_argument("--iterations", type=int, default=100, help="Number of iterations (default: 100)")
    parser.add_argument("--min-interval", type=int, default=1, help="Minimum interval in seconds (default: 1)")
    parser.add_argument("--max-interval", type=int, default=2, help="Maximum interval in seconds (default: 2)")
    parser.add_argument("--sequential", action="store_true", help="Run commands sequentially (default: parallel)")
    parser.add_argument("--no-start", action="store_true", help="Don't start the simulation (default: start)")
    parser.add_argument("--no-webview", action="store_true", help="Don't use webview mode (default: use)")
    parser.add_argument("--no-rotate-ip", action="store_true", help="Don't rotate IP (default: rotate)")
    parser.add_argument("--output", help="Output file for results (default: stdout)")
    
    args = parser.parse_args()
    
    # Parse devices
    devices = None
    if args.devices:
        devices = [d.strip() for d in args.devices.split(",") if d.strip()]
    
    # Run the distribution
    result = distribute_url(
        url=args.url,
        devices=devices,
        iterations=args.iterations,
        min_interval=args.min_interval,
        max_interval=args.max_interval,
        parallel=not args.sequential,
        start=not args.no_start,
        use_webview=not args.no_webview,
        rotate_ip=not args.no_rotate_ip
    )
    
    # Output results
    if args.output:
        with open(args.output, "w") as f:
            json.dump(result, f, indent=2)
        print(f"Results written to {args.output}")
    else:
        print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main() 