#!/usr/bin/env python3
import subprocess
import sys
import os
import argparse
import threading
import time
import logging
import json
import concurrent.futures
from typing import List, Dict, Any, Tuple, Optional
from pathlib import Path
import shlex

# Configure logging
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'batch_simulation.log'))
    ]
)
logger = logging.getLogger('batch_simulation')

# Get the absolute path to the pre_start_settings.sh script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PRE_START_SCRIPT = os.path.join(SCRIPT_DIR, 'pre_start_settings.sh')

def get_connected_devices() -> List[str]:
    """Get a list of connected device IDs using ADB."""
    try:
        result = subprocess.run(['adb', 'devices'], 
                               capture_output=True, 
                               text=True, 
                               check=True)
        
        # Parse the output to extract device IDs
        lines = result.stdout.strip().split('\n')[1:]  # Skip the first line (header)
        devices = []
        for line in lines:
            if line.strip() and '\tdevice' in line:
                device_id = line.split('\t')[0].strip()
                if device_id:
                    devices.append(device_id)
        
        logger.info(f"Found {len(devices)} connected devices: {', '.join(devices)}")
        return devices
    except subprocess.CalledProcessError as e:
        logger.error(f"Error getting connected devices: {e}")
        return []

def verify_pre_start_script() -> bool:
    """Verify that the pre_start_settings.sh script exists and is executable."""
    if not os.path.isfile(PRE_START_SCRIPT):
        logger.error(f"Script not found at {PRE_START_SCRIPT}")
        return False
    
    if not os.access(PRE_START_SCRIPT, os.X_OK):
        logger.warning(f"Script is not executable. Attempting to make it executable.")
        try:
            os.chmod(PRE_START_SCRIPT, 0o755)
            logger.info("Successfully made pre_start_settings.sh executable")
        except Exception as e:
            logger.error(f"Failed to make pre_start_settings.sh executable: {e}")
            return False
    
    return True

def run_simulation_on_device(device_id: str, url: str, settings: Dict[str, Any]) -> Tuple[bool, str]:
    """
    Run simulation on a specific device using pre_start_settings.sh
    
    Args:
        device_id: The device ID to target
        url: The URL to use for the simulation
        settings: Dictionary of settings to apply
        
    Returns:
        Tuple of (success, message)
    """
    # Properly quote the URL to preserve special characters
    cmd = [PRE_START_SCRIPT, device_id, url]
    
    # Add options based on settings
    if 'iterations' in settings:
        cmd.extend(['--iterations', str(settings['iterations'])])
    if 'min_interval' in settings:
        cmd.extend(['--min-interval', str(settings['min_interval'])])
    if 'max_interval' in settings:
        cmd.extend(['--max-interval', str(settings['max_interval'])])
    if 'delay' in settings:
        cmd.extend(['--delay', str(settings['delay'])])
    if 'use_webview_mode' in settings:
        cmd.extend(['--webview', str(settings['use_webview_mode']).lower()])
    if 'rotate_ip' in settings:
        cmd.extend(['--rotate-ip', str(settings['rotate_ip']).lower()])
    if 'use_random_device_profile' in settings:
        cmd.extend(['--random-devices', str(settings['use_random_device_profile']).lower()])
    if 'new_webview_per_request' in settings:
        cmd.extend(['--new-webview', str(settings['new_webview_per_request']).lower()])
    
    try:
        logger.info(f"Running simulation on device {device_id} with URL: {url}")
        
        # Use subprocess.Popen with shell=False to avoid shell interpretation of special characters
        process = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False
        )
        
        if process.returncode == 0:
            logger.info(f"Successfully started simulation on device {device_id}")
            return True, process.stdout
        else:
            logger.error(f"Failed to start simulation on device {device_id}: {process.stderr}")
            return False, process.stderr
    except Exception as e:
        logger.error(f"Error starting simulation on device {device_id}: {e}")
        return False, str(e)

def batch_run_sequential(devices: List[str], url: str, settings: Dict[str, Any]) -> Dict[str, Tuple[bool, str]]:
    """Run simulations on multiple devices sequentially."""
    results = {}
    for device_id in devices:
        success, message = run_simulation_on_device(device_id, url, settings)
        results[device_id] = (success, message)
    return results

def batch_run_parallel(devices: List[str], url: str, settings: Dict[str, Any]) -> Dict[str, Tuple[bool, str]]:
    """Run simulations on multiple devices in parallel."""
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(devices)) as executor:
        future_to_device = {
            executor.submit(run_simulation_on_device, device_id, url, settings): device_id
            for device_id in devices
        }
        
        for future in concurrent.futures.as_completed(future_to_device):
            device_id = future_to_device[future]
            try:
                success, message = future.result()
                results[device_id] = (success, message)
            except Exception as e:
                logger.error(f"Exception for device {device_id}: {e}")
                results[device_id] = (False, str(e))
    
    return results

def load_config(config_file: str) -> Dict[str, Any]:
    """Load configuration from a JSON file."""
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        
        # Validate required fields
        required_fields = ['url']
        for field in required_fields:
            if field not in config:
                logger.error(f"Missing required field '{field}' in config file")
                sys.exit(1)
        
        return config
    except Exception as e:
        logger.error(f"Error loading config file: {e}")
        sys.exit(1)

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Run simulations on multiple Android devices')
    
    # Device selection
    device_group = parser.add_mutually_exclusive_group()
    device_group.add_argument('--all-devices', action='store_true', help='Run on all connected devices')
    device_group.add_argument('--devices', nargs='+', help='Specific device IDs to use')
    
    # Configuration
    config_group = parser.add_mutually_exclusive_group(required=True)
    config_group.add_argument('--config', help='Path to JSON configuration file')
    config_group.add_argument('--url', help='URL to use for the simulation')
    
    # Additional settings (when not using config file)
    parser.add_argument('--iterations', type=int, default=900, help='Number of iterations')
    parser.add_argument('--min-interval', type=int, default=1, help='Minimum interval between requests (seconds)')
    parser.add_argument('--max-interval', type=int, default=2, help='Maximum interval between requests (seconds)')
    parser.add_argument('--delay', type=int, default=3000, help='Delay after toggling airplane mode (milliseconds)')
    parser.add_argument('--no-webview', action='store_true', help='Disable WebView mode')
    parser.add_argument('--no-rotate-ip', action='store_true', help='Disable IP rotation')
    parser.add_argument('--no-random-devices', action='store_true', help='Disable random device profiles')
    parser.add_argument('--no-new-webview', action='store_true', help='Disable new WebView per request')
    
    # Execution mode
    parser.add_argument('--parallel', action='store_true', help='Run simulations in parallel (default: sequential)')
    
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Verify the script exists and is executable
    if not verify_pre_start_script():
        sys.exit(1)
    
    # Get the list of devices to use
    all_devices = get_connected_devices()
    if not all_devices:
        logger.error("No devices connected. Please connect at least one device.")
        sys.exit(1)
    
    if args.all_devices:
        devices = all_devices
    elif args.devices:
        devices = [d for d in args.devices if d in all_devices]
        if not devices:
            logger.error("None of the specified devices are connected.")
            sys.exit(1)
    else:
        logger.info("No devices specified, using the first connected device.")
        devices = [all_devices[0]]
    
    # Get configuration
    if args.config:
        config = load_config(args.config)
        url = config['url']
        settings = {k: v for k, v in config.items() if k != 'url'}
    else:
        url = args.url
        settings = {
            'iterations': args.iterations,
            'min_interval': args.min_interval,
            'max_interval': args.max_interval,
            'delay': args.delay,
            'use_webview_mode': not args.no_webview,
            'rotate_ip': not args.no_rotate_ip,
            'use_random_device_profile': not args.no_random_devices,
            'new_webview_per_request': not args.no_new_webview
        }
    
    logger.info(f"Starting simulations with URL: {url}")
    logger.info(f"Settings: {settings}")
    logger.info(f"Devices: {devices}")
    logger.info(f"Execution mode: {'Parallel' if args.parallel else 'Sequential'}")
    
    # Run the simulations
    start_time = time.time()
    if args.parallel:
        results = batch_run_parallel(devices, url, settings)
    else:
        results = batch_run_sequential(devices, url, settings)
    
    # Output results
    logger.info(f"Completed in {time.time() - start_time:.2f} seconds")
    
    success_count = sum(1 for success, _ in results.values() if success)
    logger.info(f"Results: {success_count}/{len(devices)} successful")
    
    for device_id, (success, message) in results.items():
        status = "SUCCESS" if success else "FAILED"
        logger.info(f"{device_id}: {status}")
    
    return 0 if success_count == len(devices) else 1

if __name__ == "__main__":
    sys.exit(main()) 
 