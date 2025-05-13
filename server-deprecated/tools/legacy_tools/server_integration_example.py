#!/usr/bin/env python3
"""
Example of integrating robust_batch_drono into a server application
"""
import os
import sys
import asyncio
import logging
from typing import List, Dict, Any
import json

# Add the parent directory to path to import the robust_batch_drono module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.robust_batch_drono import (
    get_connected_devices,
    prepare_command_args,
    execute_batch_command_parallel,
    execute_batch_command_sequential
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join('logs', 'server_integration.log'))
    ]
)
logger = logging.getLogger('server_integration')

# Sample settings for demonstration
SAMPLE_SETTINGS = {
    "url": "https://veewoy.com/ip-text",
    "iterations": 900,
    "min_interval": 1,
    "max_interval": 2,
    "airplane_mode_delay": 3000,
    "webview_mode": True,
    "rotate_ip": True,
    "random_devices": True,
    "new_webview_per_request": True
}

INSTAGRAM_SETTINGS = {
    "url": "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA",
    "iterations": 900,
    "min_interval": 1,
    "max_interval": 2,
    "airplane_mode_delay": 3000,
    "webview_mode": True,
    "rotate_ip": True,
    "random_devices": True,
    "new_webview_per_request": True
}

async def run_batch_command(devices: List[str], settings: Dict[str, Any], parallel: bool = True) -> Dict[str, Any]:
    """
    Run a batch command on the specified devices with the given settings.
    This function is designed to be called from an async server.
    """
    logger.info(f"Starting batch command for {len(devices)} devices with settings: {settings}")
    
    # Prepare the command arguments
    command_args = prepare_command_args(settings)
    
    # Execute in a separate thread to avoid blocking the event loop
    if parallel:
        # For parallel execution
        results = await asyncio.to_thread(execute_batch_command_parallel, devices, command_args)
    else:
        # For sequential execution
        results = await asyncio.to_thread(execute_batch_command_sequential, devices, command_args)
    
    # Process the results
    success_count = 0
    result_summary = {}
    
    for device, (return_code, stdout, stderr) in results.items():
        status = "success" if return_code == 0 else "failure"
        success_count += 1 if return_code == 0 else 0
        
        result_summary[device] = {
            "status": status,
            "return_code": return_code,
            "success": return_code == 0,
            "simulation_started": "Simulation started successfully" in stdout
        }
        
        if return_code != 0:
            result_summary[device]["error"] = stderr or "Unknown error"
    
    # Add summary stats
    result_summary["summary"] = {
        "total_devices": len(devices),
        "success_count": success_count,
        "failure_count": len(devices) - success_count,
        "success_rate": f"{(success_count / len(devices) * 100):.1f}%"
    }
    
    logger.info(f"Batch command completed. Success rate: {result_summary['summary']['success_rate']}")
    return result_summary

# Example FastAPI endpoint that could be integrated into a real server application
"""
@app.post("/api/devices/batch/command")
async def batch_command(request: BatchCommandRequest):
    # Get the list of devices to target
    if request.all_devices:
        devices = get_connected_devices()
    else:
        devices = request.devices
    
    if not devices:
        return {"error": "No devices specified or found"}
    
    # Execute the batch command
    results = await run_batch_command(devices, request.settings, parallel=request.parallel)
    
    return results
"""

# Example function that could be called from command-line script
async def main():
    """Example of using the run_batch_command function"""
    # Get all connected devices
    devices = get_connected_devices()
    if not devices:
        logger.error("No devices found connected")
        return 1
    
    logger.info(f"Found {len(devices)} devices: {devices}")
    
    # Run a batch command with sample settings
    results = await run_batch_command(devices, SAMPLE_SETTINGS, parallel=True)
    
    # Print the results in a nice format
    print(json.dumps(results, indent=2))
    
    return 0

# Main entry point for the example
if __name__ == "__main__":
    # Create logs directory if it doesn't exist
    os.makedirs(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'logs'), exist_ok=True)
    
    # Run the async main function
    asyncio.run(main()) 