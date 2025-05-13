# Robust Batch Drono Control

A robust Python script for executing Drono commands across multiple connected devices simultaneously.

## Features

- **Reliable Execution Chain**: Follows the proven pattern of "kill app → set settings → start app" from drono_control.sh
- **Multiple Device Support**: Can target specific devices or all connected devices
- **Parallel or Sequential Execution**: Run commands on all devices at once or one after another
- **Multiple Configuration Methods**: Use command line arguments, JSON config files, or direct argument passthrough
- **Robust Error Handling**: Detailed logging, timeouts, and error reporting
- **URL Safety**: Properly handles URL escaping and special characters

## Prerequisites

- Python 3.6 or higher
- ADB installed and in PATH
- Connected Android devices

## Installation

1. Make sure the script is executable:
   ```bash
   chmod +x robust_batch_drono.py
   ```

## Usage

### Basic Usage with JSON Config

```bash
# Target all connected devices using a config file
python3 robust_batch_drono.py --all-devices --config sample_config.json

# Target specific devices
python3 robust_batch_drono.py --devices R9WR310F4GJ R38N9014KDM --config sample_config.json

# Execute in parallel
python3 robust_batch_drono.py --all-devices --parallel --config sample_config.json
```

### Using Command Line Arguments

```bash
# Specify individual settings via command line
python3 robust_batch_drono.py --all-devices \
  --url "https://veewoy.com/ip-text" \
  --iterations 900 \
  --min-interval 1 \
  --max-interval 2 \
  --airplane-mode-delay 3000 \
  --webview-mode true \
  --rotate-ip true \
  --random-devices true \
  --new-webview-per-request true
```

### Direct Argument Passthrough

For maximum flexibility, pass arguments directly to drono_control.sh:

```bash
# Pass arguments directly to drono_control.sh
python3 robust_batch_drono.py --all-devices --args -settings url "https://veewoy.com/ip-text" iterations 900 min_interval 1 max_interval 2 toggle webview_mode true toggle rotate_ip true toggle random_devices true toggle new_webview_per_request true delay 3000 start
```

## JSON Configuration Format

Create a JSON file with the following structure:

```json
{
  "url": "https://veewoy.com/ip-text",
  "iterations": 900,
  "min_interval": 1,
  "max_interval": 2,
  "airplane_mode_delay": 3000,
  "webview_mode": true,
  "rotate_ip": true,
  "random_devices": true,
  "new_webview_per_request": true
}
```

## Command Line Options

```
  --all-devices          Target all connected devices
  --devices DEVICES [DEVICES ...]
                        Specific device IDs to target
  --parallel             Execute commands in parallel across devices
  --timeout TIMEOUT      Command timeout in seconds (default: 300)
  --config CONFIG        Path to JSON config file with settings
  --args [ARGS ...]      Direct arguments for drono_control.sh (quote as needed)
  --url URL              Target URL for the Drono app
  --iterations ITERATIONS
                        Number of iterations
  --min-interval MIN_INTERVAL
                        Minimum interval in seconds
  --max-interval MAX_INTERVAL
                        Maximum interval in seconds
  --airplane-mode-delay AIRPLANE_MODE_DELAY
                        Airplane mode delay in milliseconds
  --webview-mode {true,false}
                        Toggle webview mode
  --rotate-ip {true,false}
                        Toggle IP rotation
  --random-devices {true,false}
                        Toggle random device profiles
  --new-webview-per-request {true,false}
                        Toggle new WebView per request
```

## Execution Flow

The script follows this execution flow for each device:

1. Sets the `ADB_DEVICE_ID` environment variable for the device
2. Executes drono_control.sh with the `-settings` flag to ensure:
   - The app is force-stopped first
   - All settings are applied before starting
   - The app is started only after all settings are verified
3. Verifies the success of the operation

## Logs

Logs are stored in:
- Console output (real-time)
- `server/logs/batch_drono.log` (persistent)

## Troubleshooting

### Invalid URL Format
If your URL contains special characters, ensure it's properly quoted:

```bash
# Correct
python3 robust_batch_drono.py --devices R9WR310F4GJ --args -settings url "https://l.instagram.com/?u=https%3A%2F%2Fexample.com" start
```

### Connection Issues
If device connections are failing:

1. Check that devices are connected and properly authorized:
   ```bash
   adb devices
   ```
   
2. Ensure ADB server is running:
   ```bash
   adb start-server
   ```

### Script Not Finding drono_control.sh
The script automatically looks for drono_control.sh based on the directory structure. If it's not finding it:

1. Verify the script exists at the expected path: `[project_root]/android-app/drono_control.sh`
2. Make sure the script is executable: `chmod +x [project_root]/android-app/drono_control.sh`

## Integration with Server

To integrate this script with a server application:

1. Import the script as a module:
   ```python
   from tools.robust_batch_drono import execute_batch_command_parallel, prepare_command_args
   ```

2. Call the functions directly:
   ```python
   devices = ["R9WR310F4GJ", "R38N9014KDM"]
   settings = {
       "url": "https://example.com",
       "iterations": 900,
       "webview_mode": True
   }
   
   command_args = prepare_command_args(settings)
   results = execute_batch_command_parallel(devices, command_args)
   
   # Process results
   for device, (return_code, stdout, stderr) in results.items():
       print(f"Device {device}: {'SUCCESS' if return_code == 0 else 'FAILED'}")
   ``` 