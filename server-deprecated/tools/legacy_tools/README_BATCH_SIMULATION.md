# Batch Simulation Tools

This directory contains tools for batch execution of simulations on multiple Android devices.

## Overview

The batch simulation system consists of:

1. `pre_start_settings.sh` - A shell script that reliably applies settings to the app before starting it
2. `batch_simulation.py` - A Python script that manages running simulations on multiple devices
3. `run_batch_simulation.sh` - A helper script that makes it easy to run common configurations
4. `insta_sim.sh` - A specialized script for Instagram URLs that avoids quoting issues
5. `batch_instagram.py` - A Python wrapper specifically for Instagram simulations
6. `run_instagram.sh` - A helper script for running Instagram simulations
7. Configuration files - JSON files that define simulation parameters

## Requirements

- Python 3.6+
- ADB (Android Debug Bridge)
- Rooted Android devices (for reliable settings application)

## How It Works

The system follows these steps:

1. Stops any running app instances
2. Removes existing preferences file
3. Creates a new preferences file with desired settings
4. Injects this file into the app's data directory
5. Starts the app
6. Starts the simulation via broadcast

This approach ensures settings are correctly applied before the app has a chance to overwrite them.

## Usage

### General Simulations

For general URLs, use the batch_simulation.py script:

```bash
./run_batch_simulation.sh [options]
```

Options:
- `--instagram` - Run Instagram simulation with predefined settings
- `--veewoy` - Run Veewoy simulation with predefined settings
- `--all-devices` - Run on all connected devices
- `--devices <ids>` - Run on specific devices (space-separated IDs)
- `--parallel` - Run in parallel mode (default: sequential)
- `--url <url>` - Use a custom URL (without config file)
- `--config <file>` - Use a custom config file

### Instagram Simulations

For Instagram URLs with special characters, use the specialized Instagram tools:

```bash
./run_instagram.sh [options]
```

Options:
- `--all-devices` - Run on all connected devices
- `--devices <ids>` - Run on specific devices (space-separated IDs)
- `--parallel` - Run in parallel mode (default: sequential)

### Using the Python Scripts Directly

For more control, you can use the Python scripts directly:

```bash
# For general URLs:
./batch_simulation.py [options]

# For Instagram URLs:
./batch_instagram.py [options]
```

Run with `--help` for full documentation of options.

### Using the Shell Scripts Directly

For single device execution:

```bash
# For general URLs:
./pre_start_settings.sh <device_id> <url> [options]

# For Instagram URLs:
./insta_sim.sh <device_id>
```

## Configuration Files

Configuration is specified in JSON format. Example:

```json
{
    "url": "https://example.com",
    "iterations": 900,
    "min_interval": 1,
    "max_interval": 2,
    "delay": 3000,
    "use_webview_mode": true,
    "rotate_ip": true,
    "use_random_device_profile": true,
    "new_webview_per_request": true
}
```

## Specialized Instagram URL Handling

The Instagram URL tools handle the complex URLs by:
1. Storing the URL in a separate file (`instagram_url.txt`)
2. Reading the URL directly from the file, avoiding shell quoting issues
3. Using a simplified approach that focuses only on the Instagram use case
4. Providing fallback methods if settings are not applied correctly

This specialized approach ensures reliability when dealing with URLs containing special characters like `&`, `=`, and `%` which are common in Instagram URLs.

## Troubleshooting

### Cannot Access Preferences File

This usually means the device is not properly rooted. Make sure root access is granted to ADB shell.

### Settings Not Applied

If settings still aren't applied correctly:

1. Check the app's log to see if it's overwriting settings at startup
2. Try using the Instagram-specific tools for complex URLs
3. Check device permissions for the app's data directory

### ADB Not Found

Make sure ADB is in your PATH. You can install it with Android SDK Platform Tools.

### Script Not Executable

Run `chmod +x filename.sh` to make scripts executable.

## Logs

Logs are written to the `logs` directory:
- `batch_simulation.log` - Main log for the general simulation script
- `batch_instagram.log` - Log for the Instagram-specific script

## Advanced Usage

### Custom Configuration Files

You can create your own configuration files for different simulation scenarios. Example:

```bash
# Create a custom config
echo '{
    "url": "https://custom-url.com",
    "iterations": 500,
    "min_interval": 2,
    "max_interval": 5,
    "delay": 2000,
    "use_webview_mode": true,
    "rotate_ip": true,
    "use_random_device_profile": true,
    "new_webview_per_request": true
}' > my_config.json

# Run with custom config
./run_batch_simulation.sh --config my_config.json --all-devices
```

### Direct Method Execution

If you need more control, you can execute the methods directly in Python:

```python
# For general URLs:
import batch_simulation

devices = batch_simulation.get_connected_devices()
settings = batch_simulation.load_config("my_config.json")
results = batch_simulation.batch_run_parallel(devices, settings["url"], settings)

# For Instagram URLs:
import batch_instagram

devices = batch_instagram.get_connected_devices()
results = batch_instagram.run_parallel(devices)
```

## Contributors

- Veewoy Team

## License

This software is proprietary and confidential. 
 