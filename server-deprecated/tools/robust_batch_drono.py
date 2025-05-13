#!/usr/bin/env python3
import subprocess
import shlex
import sys
import os
import argparse
import threading
import time
import logging
import json
import re
from typing import List, Dict, Any, Tuple, Optional
from pathlib import Path
import concurrent.futures

# Configure logging
LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.join(LOG_DIR, 'batch_drono.log'))
    ]
)
logger = logging.getLogger('robust_batch_drono')

# Get the absolute path to the drono_control.sh script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
DRONO_CONTROL_SCRIPT = os.path.join(PROJECT_ROOT, 'android-app', 'drono_control.sh')

def ensure_dir_exists(path):
    """Ensure the directory exists, creating it if necessary."""
    os.makedirs(path, exist_ok=True)

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

def verify_drono_control_script() -> bool:
    """Verify that the drono_control.sh script exists and is executable."""
    if not os.path.isfile(DRONO_CONTROL_SCRIPT):
        logger.error(f"Drono control script not found at {DRONO_CONTROL_SCRIPT}")
        return False
    
    if not os.access(DRONO_CONTROL_SCRIPT, os.X_OK):
        logger.warning(f"Drono control script is not executable. Attempting to make it executable.")
        try:
            os.chmod(DRONO_CONTROL_SCRIPT, 0o755)
            logger.info("Successfully made drono_control.sh executable")
        except Exception as e:
            logger.error(f"Failed to make drono_control.sh executable: {e}")
            return False
    
    return True

def run_on_device(device_id: str, command_args: List[str], timeout: int = 300) -> Tuple[int, str, str]:
    """
    Run the drono_control.sh script on a specific device with the given arguments.
    
    Args:
        device_id: The device ID to target
        command_args: The command line arguments to pass to drono_control.sh
        timeout: Timeout in seconds
        
    Returns:
        Tuple of (return_code, stdout, stderr)
    """
    # Construct the command
    script_path = DRONO_CONTROL_SCRIPT
    if not script_path:
        return 1, "", "Drono control script not found"
    
    # Full command with environment variables to target the specific device
    env = os.environ.copy()
    env["ADB_DEVICE_ID"] = device_id
    
    # For safety, ensure all arguments are properly quoted
    try:
        # Use run to execute the command and capture output
        process = subprocess.run(
            [script_path, "-settings"] + command_args,
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return process.returncode, process.stdout, process.stderr
    except subprocess.TimeoutExpired as e:
        logger.error(f"Command timed out after {timeout} seconds")
        return 1, "", f"Command timed out: {str(e)}"
    except Exception as e:
        logger.error(f"Command execution failed: {e}")
        return 1, "", f"Command execution failed: {str(e)}"

def run_drono_with_proper_chain(device_id: str, command_args: List[str], timeout: int = 300) -> Tuple[int, str, str]:
    """
    Run the drono app with the proper execution chain using direct file manipulation:
    1. Kill the app
    2. Create a properly formatted prefs XML file with the desired settings
    3. Push the file directly to the device's shared_prefs location
    4. Start the app explicitly
    5. Send the start command
    
    Args:
        device_id: The device ID to target
        command_args: The command line arguments for settings
        timeout: Timeout in seconds
        
    Returns:
        Tuple of (return_code, stdout, stderr)
    """
    # Parse the command args into a settings dictionary
    settings = {}
    skip_next = False
    for i, arg in enumerate(command_args):
        if skip_next:
            skip_next = False
            continue
            
        if i < len(command_args) - 1:
            if arg == "url":
                settings["target_url"] = command_args[i+1]
                skip_next = True
            elif arg == "iterations":
                settings["iterations"] = int(command_args[i+1])
                skip_next = True
            elif arg == "min_interval":
                settings["min_interval"] = int(command_args[i+1])
                skip_next = True
            elif arg == "max_interval":
                settings["max_interval"] = int(command_args[i+1])
                skip_next = True
            elif arg == "delay":
                settings["airplane_mode_delay"] = int(command_args[i+1])
                skip_next = True
            elif arg == "toggle" and i < len(command_args) - 2:
                feature = command_args[i+1]
                value = command_args[i+2].lower() == "true"
                
                if feature == "webview_mode":
                    settings["use_webview_mode"] = value
                elif feature == "rotate_ip":
                    settings["rotate_ip"] = value
                elif feature == "random_devices":
                    settings["use_random_device_profile"] = value
                elif feature == "new_webview_per_request":
                    settings["new_webview_per_request"] = value
                
                skip_next = True  # Skip feature name
                # Will skip value in next iteration
    
    logger.info(f"Parsed settings for device {device_id}: {settings}")
    
    # Step 1: Kill the app
    logger.info(f"Stopping app on device {device_id}")
    try:
        kill_process = subprocess.run(
            ["adb", "-s", device_id, "shell", "am", "force-stop", "com.example.imtbf.debug"],
            capture_output=True,
            text=True,
            timeout=timeout/4
        )
        if kill_process.returncode != 0:
            logger.warning(f"Failed to kill app on {device_id}: {kill_process.stderr}")
    except Exception as e:
        logger.warning(f"Error killing app: {e}")
    
    # Step 2: Create preferences XML file
    temp_file = f"temp_prefs_{device_id}.xml"
    xml_content = """<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="{use_webview_mode}" />
    <string name="device_id">{device_id}</string>
    <string name="current_session_id">{session_id}</string>
    <string name="target_url">{target_url}</string>
    <int name="delay_max" value="5" />
    <boolean name="is_first_run" value="false" />
    <int name="airplane_mode_delay" value="{airplane_mode_delay}" />
    <int name="iterations" value="{iterations}" />
    <boolean name="is_running" value="false" />
    <boolean name="config_expanded" value="true" />
    <int name="min_interval" value="{min_interval}" />
    <int name="delay_min" value="1" />
    <int name="max_interval" value="{max_interval}" />
    <boolean name="rotate_ip" value="{rotate_ip}" />
    <boolean name="use_random_device_profile" value="{use_random_device_profile}" />
    <boolean name="new_webview_per_request" value="{new_webview_per_request}" />
</map>""".format(
        use_webview_mode=str(settings.get("use_webview_mode", True)).lower(),
        device_id=f"{int(time.time())}-{device_id}",
        session_id=time.strftime("%Y%m%d_%H%M%S"),
        target_url=settings.get("target_url", "https://example.com"),
        airplane_mode_delay=settings.get("airplane_mode_delay", 3000),
        iterations=settings.get("iterations", 900),
        min_interval=settings.get("min_interval", 1),
        max_interval=settings.get("max_interval", 2),
        rotate_ip=str(settings.get("rotate_ip", True)).lower(),
        use_random_device_profile=str(settings.get("use_random_device_profile", True)).lower(),
        new_webview_per_request=str(settings.get("new_webview_per_request", True)).lower()
    )
    
    logger.info(f"Creating preferences file for device {device_id}")
    try:
        with open(temp_file, 'w') as f:
            f.write(xml_content)
        
        # Push file to device
        push_process = subprocess.run(
            ["adb", "-s", device_id, "push", temp_file, "/sdcard/temp_prefs.xml"],
            capture_output=True,
            text=True,
            timeout=timeout/4
        )
        
        # Copy to app's shared_prefs directory with proper permissions
        copy_command = (
            "su -c 'cp /sdcard/temp_prefs.xml "
            "/data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && "
            "chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && "
            "chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
        )
        
        perm_process = subprocess.run(
            ["adb", "-s", device_id, "shell", copy_command],
            capture_output=True,
            text=True,
            timeout=timeout/4
        )
        
        # Clean up temporary file
        try:
            os.remove(temp_file)
        except:
            pass
        
    except Exception as e:
        logger.error(f"Error creating preferences: {e}")
        return 1, "", f"Preferences creation failed: {str(e)}"
    
    # Step 3: Start app
    logger.info(f"Starting app on device {device_id}")
    start_app_process = subprocess.run(
        ["adb", "-s", device_id, "shell", "am", "start", "-n", "com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity"],
        capture_output=True,
        text=True,
        timeout=timeout/4
    )
    
    # Step 4: Wait for app to initialize
    time.sleep(2)
    
    # Step 5: Send start command
    logger.info(f"Starting simulation on device {device_id}")
    start_sim_process = subprocess.run(
        ["adb", "-s", device_id, "shell", "am", "broadcast", "-a", "com.example.imtbf.debug.COMMAND", "--es", "command", "start", "-p", "com.example.imtbf.debug"],
        capture_output=True,
        text=True,
        timeout=timeout/4
    )
    
    # Check preferences
    logger.info(f"Verifying settings on device {device_id}")
    verify_process = subprocess.run(
        ["adb", "-s", device_id, "shell", "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"],
        capture_output=True,
        text=True,
        timeout=timeout/4
    )
    
    combined_stdout = (
        f"PUSH RESULT:\n{push_process.stdout}\n\n"
        f"PERMISSIONS RESULT:\n{perm_process.stdout}\n\n"
        f"START APP RESULT:\n{start_app_process.stdout}\n\n"
        f"START SIMULATION RESULT:\n{start_sim_process.stdout}\n\n"
        f"VERIFICATION:\n{verify_process.stdout}"
    )
    
    combined_stderr = (
        f"PUSH ERRORS:\n{push_process.stderr}\n\n"
        f"PERMISSIONS ERRORS:\n{perm_process.stderr}\n\n"
        f"START APP ERRORS:\n{start_app_process.stderr}\n\n"
        f"START SIMULATION ERRORS:\n{start_sim_process.stderr}\n\n"
        f"VERIFICATION ERRORS:\n{verify_process.stderr}"
    )
    
    return start_sim_process.returncode, combined_stdout, combined_stderr

def execute_batch_command_sequential(devices: List[str], command_args: List[str]) -> Dict[str, Tuple[int, str, str]]:
    """
    Execute the drono_control.sh command sequentially on each device with proper execution chain.
    Returns a dictionary mapping device IDs to result tuples.
    """
    results = {}
    for device in devices:
        logger.info(f"Processing device: {device}")
        results[device] = run_drono_with_proper_chain(device, command_args)
    return results

def execute_batch_command_parallel(devices: List[str], command_args: List[str]) -> Dict[str, Tuple[int, str, str]]:
    """
    Execute the drono_control.sh command in parallel on all devices with proper execution chain.
    Returns a dictionary mapping device IDs to result tuples.
    """
    with concurrent.futures.ThreadPoolExecutor() as executor:
        # Define a worker function to run for each device
        def worker(device):
            logger.info(f"Processing device: {device}")
            return device, run_drono_with_proper_chain(device, command_args)
        
        # Submit all tasks and collect results
        futures = [executor.submit(worker, device) for device in devices]
        results = {}
        
        for future in concurrent.futures.as_completed(futures):
            try:
                device, result = future.result()
                results[device] = result
            except Exception as e:
                logger.error(f"Error in worker thread: {e}")
        
    return results

def prepare_command_args(args_dict: Dict[str, Any]) -> List[str]:
    """
    Prepare command arguments from the dictionary, handling special characters correctly.
    This ensures complex URLs and other arguments are properly escaped.
    """
    command_args = []
    
    # Use -settings flag for the reliable execution chain
    command_args.append("-settings")
    
    # Handle URL (if provided) - special handling for URLs with problematic characters
    if 'url' in args_dict and args_dict['url']:
        url = args_dict['url']
        # If URL contains problematic characters like &, we'll need to handle it carefully
        if '&' in url:
            # For URLs with &, we'll use proper quoting and escape it for shell execution
            logger.debug(f"URL contains special characters, will quote properly: {url}")
        # Just add the URL to the command args - it will be properly quoted by subprocess.run
        command_args.extend(["url", url])
    
    # Handle iterations
    if 'iterations' in args_dict and args_dict['iterations']:
        command_args.extend(["iterations", str(args_dict['iterations'])])
    
    # Handle intervals
    if 'min_interval' in args_dict and args_dict['min_interval'] is not None:
        command_args.extend(["min_interval", str(args_dict['min_interval'])])
    if 'max_interval' in args_dict and args_dict['max_interval'] is not None:
        command_args.extend(["max_interval", str(args_dict['max_interval'])])
    
    # Handle airplane_mode_delay - note that drono_control.sh expects 'delay' not 'airplane_mode_delay'
    if 'airplane_mode_delay' in args_dict and args_dict['airplane_mode_delay'] is not None:
        command_args.extend(["delay", str(args_dict['airplane_mode_delay'])])
    
    # Handle toggle features - Fix to ensure the proper settings chain
    for feature in ['webview_mode', 'rotate_ip', 'random_devices', 'new_webview_per_request']:
        # Check if feature exists in settings with either name format
        feature_key = feature if feature in args_dict else f"toggle_{feature}"
        if feature_key in args_dict and args_dict[feature_key] is not None:
            value = str(args_dict[feature_key]).lower()
            logger.debug(f"Setting feature toggle: {feature}={value}")
            # The drono_control.sh script expects: toggle feature_name true/false
            command_args.extend(["toggle", feature, value])
    
    # Remove "start" command - we want to follow the proper sequence:
    # 1. Kill app
    # 2. Set all settings 
    # 3. Launch the app explicitly (will read the settings)
    # 4. Send the start command separately

    return command_args

def validate_settings(settings: Dict[str, Any]) -> bool:
    """Validate the settings to ensure they're correct."""
    if 'url' in settings and not settings['url']:
        logger.error("URL cannot be empty if specified")
        return False
    
    int_fields = ['iterations', 'min_interval', 'max_interval', 'airplane_mode_delay']
    for field in int_fields:
        if field in settings and settings[field] is not None:
            try:
                int(settings[field])
            except ValueError:
                logger.error(f"{field} must be an integer")
                return False
    
    bool_fields = ['webview_mode', 'rotate_ip', 'random_devices', 'new_webview_per_request']
    for field in bool_fields:
        field_key = field if field in settings else f"toggle_{field}"
        if field_key in settings and settings[field_key] is not None:
            value = settings[field_key]
            if not isinstance(value, bool) and value.lower() not in ['true', 'false']:
                logger.error(f"{field} must be true or false")
                return False
    
    return True

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="Robust Batch Drono Control")
    
    # Device selection options
    device_group = parser.add_mutually_exclusive_group(required=True)
    device_group.add_argument("--all-devices", action="store_true", help="Target all connected devices")
    device_group.add_argument("--devices", nargs="+", help="Specific device IDs to target")
    
    # Execution options
    parser.add_argument("--parallel", action="store_true", help="Execute commands in parallel across devices")
    parser.add_argument("--timeout", type=int, default=300, help="Command timeout in seconds (default: 300)")
    
    # Configuration via command line or file
    config_group = parser.add_mutually_exclusive_group(required=True)
    config_group.add_argument("--config", type=str, help="Path to JSON config file with settings")
    config_group.add_argument("--args", nargs=argparse.REMAINDER, help="Direct arguments for drono_control.sh (quote as needed)")
    
    # Settings parameters (when not using --args or --config)
    parser.add_argument("--url", type=str, help="Target URL for the Drono app")
    parser.add_argument("--iterations", type=int, help="Number of iterations")
    parser.add_argument("--min-interval", type=int, help="Minimum interval in seconds")
    parser.add_argument("--max-interval", type=int, help="Maximum interval in seconds")
    parser.add_argument("--airplane-mode-delay", type=int, help="Airplane mode delay in milliseconds")
    parser.add_argument("--webview-mode", type=str, choices=["true", "false"], help="Toggle webview mode")
    parser.add_argument("--rotate-ip", type=str, choices=["true", "false"], help="Toggle IP rotation")
    parser.add_argument("--random-devices", type=str, choices=["true", "false"], help="Toggle random device profiles")
    
    return parser.parse_args()

def main():
    """Main entry point for the script."""
    # Ensure logs directory exists
    ensure_dir_exists(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'logs'))
    
    # Parse command line arguments
    args = parse_args()
    
    # Verify drono_control.sh exists and is executable
    if not verify_drono_control_script():
        logger.error("Cannot proceed without a valid drono_control.sh script")
        return 1
    
    # Get the list of devices to target
    if args.all_devices:
        devices = get_connected_devices()
        if not devices:
            logger.error("No connected devices found")
            return 1
    else:
        devices = args.devices
    
    logger.info(f"Will target {len(devices)} devices: {', '.join(devices)}")
    
    # Prepare command arguments
    if args.args:
        # Direct passthrough of arguments
        command_args = args.args
    elif args.config:
        # Load settings from config file
        try:
            with open(args.config, 'r') as f:
                settings = json.load(f)
            
            if not validate_settings(settings):
                logger.error("Invalid settings in config file")
                return 1
                
            command_args = prepare_command_args(settings)
        except Exception as e:
            logger.error(f"Failed to load config file: {e}")
            return 1
    else:
        # Build settings from individual arguments
        settings = {
            'url': args.url,
            'iterations': args.iterations,
            'min_interval': args.min_interval,
            'max_interval': args.max_interval,
            'airplane_mode_delay': args.airplane_mode_delay,
            'webview_mode': args.webview_mode,
            'rotate_ip': args.rotate_ip,
            'random_devices': args.random_devices
        }
        
        # Filter out None values
        settings = {k: v for k, v in settings.items() if v is not None}
        
        if not settings:
            logger.error("No settings provided")
            return 1
            
        if not validate_settings(settings):
            logger.error("Invalid settings provided")
            return 1
        
        command_args = prepare_command_args(settings)
    
    logger.info(f"Command arguments: {' '.join(shlex.quote(arg) for arg in command_args)}")
    
    # Execute the commands
    start_time = time.time()
    
    if args.parallel:
        logger.info("Executing commands in parallel")
        results = execute_batch_command_parallel(devices, command_args)
    else:
        logger.info("Executing commands sequentially")
        results = execute_batch_command_sequential(devices, command_args)
    
    # Report the results
    logger.info(f"Batch execution completed in {time.time() - start_time:.2f} seconds")
    
    success_count = 0
    for device, (return_code, stdout, stderr) in results.items():
        status = "SUCCESS" if return_code == 0 else "FAILED"
        logger.info(f"Device {device}: {status} (return code: {return_code})")
        
        if return_code == 0:
            success_count += 1
            
            # Check for specific success indicators in the output
            if "Simulation started successfully" in stdout:
                logger.info(f"Device {device}: Simulation started successfully")
            else:
                logger.warning(f"Device {device}: Command completed but simulation status unclear")
    
    logger.info(f"Summary: {success_count}/{len(devices)} devices successfully processed")
    
    return 0 if success_count == len(devices) else 1

if __name__ == "__main__":
    sys.exit(main()) 