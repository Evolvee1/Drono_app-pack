#!/usr/bin/env python3
import subprocess
import sys
import os
import argparse
import logging
import concurrent.futures
from typing import List, Dict, Tuple

# Configure logging
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'batch_instagram.log'))
    ]
)
logger = logging.getLogger('batch_instagram')

# Get the absolute path to the insta_sim.sh script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INSTA_SIM_SCRIPT = os.path.join(SCRIPT_DIR, 'insta_sim.sh')
INSTAGRAM_URL_FILE = os.path.join(SCRIPT_DIR, 'instagram_url.txt')

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

def verify_script() -> bool:
    """Verify that the insta_sim.sh script exists and is executable."""
    if not os.path.isfile(INSTA_SIM_SCRIPT):
        logger.error(f"Script not found at {INSTA_SIM_SCRIPT}")
        return False
    
    if not os.access(INSTA_SIM_SCRIPT, os.X_OK):
        logger.warning(f"Script is not executable. Attempting to make it executable.")
        try:
            os.chmod(INSTA_SIM_SCRIPT, 0o755)
            logger.info("Successfully made insta_sim.sh executable")
        except Exception as e:
            logger.error(f"Failed to make insta_sim.sh executable: {e}")
            return False
    
    return True

def set_instagram_url(url: str) -> bool:
    """
    Set the Instagram URL to use in the simulations by writing it to the instagram_url.txt file.
    
    Args:
        url: The Instagram URL to set
        
    Returns:
        True if successful, False otherwise
    """
    try:
        logger.info(f"Setting Instagram URL: {url}")
        with open(INSTAGRAM_URL_FILE, 'w') as f:
            f.write(url)
        logger.info(f"Successfully wrote URL to {INSTAGRAM_URL_FILE}")
        return True
    except Exception as e:
        logger.error(f"Error setting Instagram URL: {e}")
        return False

def run_instagram_simulation(device_id: str) -> Tuple[bool, str]:
    """
    Run Instagram simulation on a specific device
    
    Args:
        device_id: The device ID to target
        
    Returns:
        Tuple of (success, message)
    """
    try:
        logger.info(f"Running Instagram simulation on device {device_id}")
        process = subprocess.run(
            [INSTA_SIM_SCRIPT, device_id],
            capture_output=True,
            text=True,
            check=False
        )
        
        stdout = process.stdout
        stderr = process.stderr
        
        # Check for success based on output
        if process.returncode == 0 and 'SUCCESS' in stdout and 'ERROR' not in stdout:
            logger.info(f"Successfully started Instagram simulation on device {device_id}")
            return True, stdout
        else:
            error_message = stderr if stderr else stdout
            logger.error(f"Failed to start Instagram simulation on device {device_id}: {error_message}")
            return False, error_message
    except Exception as e:
        logger.error(f"Error starting Instagram simulation on device {device_id}: {e}")
        return False, str(e)

def run_sequential(devices: List[str]) -> Dict[str, Tuple[bool, str]]:
    """Run simulations on multiple devices sequentially."""
    results = {}
    for device_id in devices:
        success, message = run_instagram_simulation(device_id)
        results[device_id] = (success, message)
    return results

def run_parallel(devices: List[str]) -> Dict[str, Tuple[bool, str]]:
    """Run simulations on multiple devices in parallel."""
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(devices)) as executor:
        future_to_device = {
            executor.submit(run_instagram_simulation, device_id): device_id
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

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Run Instagram simulations on multiple Android devices')
    
    # Device selection
    device_group = parser.add_mutually_exclusive_group()
    device_group.add_argument('--all-devices', action='store_true', help='Run on all connected devices')
    device_group.add_argument('--devices', nargs='+', help='Specific device IDs to use')
    
    # URL setting
    parser.add_argument('--url', help='Instagram URL to set (if not provided, will use existing URL in instagram_url.txt)')
    
    # Execution mode
    parser.add_argument('--parallel', action='store_true', help='Run simulations in parallel (default: sequential)')
    
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Verify the script exists and is executable
    if not verify_script():
        sys.exit(1)
    
    # Set Instagram URL if provided
    if args.url:
        if not set_instagram_url(args.url):
            logger.error("Failed to set Instagram URL. Exiting.")
            sys.exit(1)
    else:
        # Make sure the Instagram URL file exists
        if not os.path.isfile(INSTAGRAM_URL_FILE):
            logger.error(f"Instagram URL file not found at {INSTAGRAM_URL_FILE} and no URL provided.")
            logger.error("Please provide a URL with --url or create an instagram_url.txt file.")
            sys.exit(1)
        
        # Read the URL to log it
        try:
            with open(INSTAGRAM_URL_FILE, 'r') as f:
                url = f.read().strip()
            logger.info(f"Using existing Instagram URL: {url}")
        except Exception as e:
            logger.error(f"Error reading existing Instagram URL: {e}")
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
    
    logger.info(f"Starting Instagram simulations on devices: {devices}")
    logger.info(f"Execution mode: {'Parallel' if args.parallel else 'Sequential'}")
    
    # Run the simulations
    import time
    start_time = time.time()
    if args.parallel:
        results = run_parallel(devices)
    else:
        results = run_sequential(devices)
    
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