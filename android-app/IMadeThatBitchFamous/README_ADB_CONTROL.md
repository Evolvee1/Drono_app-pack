# Drono App - ADB Control Module

## IMPORTANT: New Improved Control Script Available

A new, more reliable control script has been developed called `drono_control.sh`. This script addresses UI update issues and provides more reliable methods for controlling the app and changing settings. We highly recommend using this script instead of the ones described below.

### How to Use the New Control Script

```bash
# Make the script executable
chmod +x drono_control.sh

# Show help information
./drono_control.sh help

# Apply settings and start simulation
./drono_control.sh preset veewoy start

# Check current status
./drono_control.sh status
```

### Recent Improvements to drono_control.sh

The script has been further improved with:

1. **Smart Start Mechanism** - Intelligently detects if the app is already running and avoids unnecessary force-stopping
2. **Enhanced Status Command** - Shows comprehensive information including process status, process ID, and detailed feature status
3. **More Reliable Settings Application** - Uses direct preferences file editing for maximum reliability
4. **New -settings Flag** - Ensures reliable application of multiple settings at once with a convenient one-liner:
   ```bash
   ./drono_control.sh -settings url https://veewoy.com/ip-text iterations 600 min_interval 1 max_interval 2 start
   ```
5. **Dry Run Mode** - Preview changes without applying them using the `-dryrun` flag:
   ```bash
   ./drono_control.sh -dryrun preset veewoy
   ```
6. **Enhanced App Launch Verification** - Waits for the app to fully launch and become responsive before proceeding with commands
7. **Clear Status Separation** - Shows distinct sections for settings application and simulation start
8. **Simulation Success Verification** - Verifies that the simulation has actually started by checking internal app state
9. **Advanced Status Reporting** - Shows app process status, simulation status, and recent log activity
10. **Session Management Commands** - Control session restoration directly from ADB:
    ```bash
    ./drono_control.sh restore_session     # Restore a previous session
    ./drono_control.sh dismiss_restore     # Dismiss restore dialog
    ./drono_control.sh check_session       # Check for saved session
    ```

For comprehensive documentation on the new script, please see the [README_DRONO_CONTROL.md](../README_DRONO_CONTROL.md) file.

---

The original implementation details follow below, but we recommend using the new script for better reliability.

## Features

- Start, pause, resume, and stop simulations remotely
- Configure app settings (URL, iterations, intervals, delays)
- Toggle features on/off (IP rotation, random devices, WebView mode, etc.)
- Export and import configurations
- Get app status information

## Implementation Details

The ADB control module consists of several components:

1. **AdbCommandReceiver**: A broadcast receiver that listens for ADB commands sent via intents
2. **CommandExecutor**: A class that relays commands to the MainActivity
3. **MainActivity integration**: Added capability to handle remote commands

## Using ADB Control

### Using the Shell Script

The included `adb_control.sh` script provides an easy way to interact with the app:

```bash
# Make the script executable
chmod +x adb_control.sh

# Show help menu
./adb_control.sh

# Start a simulation
./adb_control.sh start

# Pause a simulation
./adb_control.sh pause

# Resume a paused simulation
./adb_control.sh resume

# Stop a simulation
./adb_control.sh stop

# Set the target URL
./adb_control.sh set_url "https://example.com"

# Set number of iterations
./adb_control.sh set_iterations 100

# Set minimum interval (seconds)
./adb_control.sh set_min_int 5

# Set maximum interval (seconds)
./adb_control.sh set_max_int 20

# Set airplane mode delay (milliseconds)
./adb_control.sh set_delay 5000

# Toggle a feature on/off
./adb_control.sh toggle rotate_ip true
./adb_control.sh toggle webview_mode false

# Export a configuration
./adb_control.sh export "my_config" "My configuration description"

# Import a configuration
./adb_control.sh import "my_config.json"

# Get current status
./adb_control.sh status

# List saved configurations
./adb_control.sh list_configs
```

### Using Combo Control Script

For more advanced usage, we've created a `combo_control.sh` script that allows you to chain multiple commands together and use predefined configuration presets:

```bash
# Make the script executable
chmod +x combo_control.sh

# Show help menu
./combo_control.sh

# Use a preset configuration and start simulation
./combo_control.sh performance start

# Set custom parameters and start simulation
./combo_control.sh url=https://example.com iterations=50 min_interval=3 max_interval=10 start

# Pause the simulation
./combo_control.sh pause

# Resume the simulation
./combo_control.sh resume

# Configure everything with a single command
./combo_control.sh url=https://example.com iterations=30 min_interval=5 max_interval=15 delay=3000 rotate_ip=true webview_mode=false random_devices=true start
```

#### Available Presets

The combo script includes three predefined configuration presets:

1. **performance** - High iteration count, short intervals
   ```
   URL: https://instagram.com
   Iterations: 50
   Min Interval: 3s, Max Interval: 10s
   Airplane Mode Delay: 3000ms
   IP Rotation: enabled
   Random Devices: enabled
   WebView Mode: disabled
   ```

2. **stealth** - Lower iteration count, longer intervals
   ```
   URL: https://instagram.com
   Iterations: 30
   Min Interval: 10s, Max Interval: 20s
   Airplane Mode Delay: 5000ms
   IP Rotation: enabled
   Random Devices: enabled
   WebView Mode: enabled
   Aggressive Clearing: enabled
   ```

3. **balanced** - Medium iteration count, moderate intervals
   ```
   URL: https://instagram.com
   Iterations: 40
   Min Interval: 5s, Max Interval: 15s
   Airplane Mode Delay: 4000ms
   IP Rotation: enabled
   Random Devices: enabled
   WebView Mode: enabled
   ```

#### Individual Settings

You can configure individual settings using key=value pairs:

```
url=<url>                    - Set target URL
iterations=<n>               - Set number of iterations
min_interval=<n>             - Set minimum interval (seconds)
max_interval=<n>             - Set maximum interval (seconds)
delay=<n>                    - Set airplane mode delay (milliseconds)
rotate_ip=true|false         - Enable/disable IP rotation
webview_mode=true|false      - Enable/disable WebView mode
random_devices=true|false    - Enable/disable random device profiles
aggressive_clearing=true|false - Enable/disable aggressive session clearing
```

### Using ADB Directly

You can also use ADB commands directly:

```bash
# Start a simulation
adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command start

# Pause a simulation
adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command pause

# Set target URL
adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es value "https://example.com"

# Set iterations
adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command set_iterations --ei value 100

# Toggle a feature
adb shell am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_feature --es feature "rotate_ip" --ez value true
```

## Available Features for Toggling

You can toggle the following features:

- `rotate_ip` - Toggle IP rotation
- `random_devices` - Toggle random device profiles
- `webview_mode` - Toggle WebView mode
- `aggressive_clearing` - Toggle aggressive session clearing
- `new_webview_per_request` - Toggle new WebView per request
- `handle_redirects` - Toggle handling of marketing redirects

## Automating Workflows

You can create advanced automation scripts combining multiple commands:

```bash
#!/bin/bash
# Example workflow script for Drono

# Setup configuration
./adb_control.sh set_url "https://example.com"
./adb_control.sh set_iterations 50
./adb_control.sh set_min_int 3
./adb_control.sh set_max_int 10
./adb_control.sh set_delay 3000
./adb_control.sh toggle rotate_ip true
./adb_control.sh toggle random_devices true

# Export this configuration
./adb_control.sh export "default_setup" "Default setup with 50 iterations"

# Start the simulation
./adb_control.sh start

# Wait for some time
sleep 60

# Pause the simulation
./adb_control.sh pause

# Change settings
./adb_control.sh set_min_int 5
./adb_control.sh set_max_int 15

# Resume the simulation
./adb_control.sh resume
```

### Simplified Automation with Combo Control

With the combo control script, the above workflow can be simplified:

```bash
#!/bin/bash
# Example workflow using combo_control.sh

# Start with performance preset
./combo_control.sh performance start

# Wait for some time
sleep 60

# Pause, then adjust settings and resume
./combo_control.sh pause
sleep 5
./combo_control.sh min_interval=5 max_interval=15 resume
```

## Background vs Foreground Control

The app can be controlled in different ways:

1. **broadcast_control.sh** - Uses broadcast intents for background operation
2. **direct_intent_control.sh** - Uses direct activity intents 
3. **force_wake_control.sh** - First wakes the app, then sends commands
4. **focus_control.sh** - Focuses the app window first, then sends direct commands
5. **combo_control.sh** - Combines focusing and command chaining

For reliable background control, use the `combo_control.sh` script, which ensures the app is properly focused before sending commands and allows for chaining multiple operations.

## Technical Details

### Architecture

The ADB control module is designed to be modular and uses the following architecture:

1. **BroadcastReceiver**: Listens for ADB intents and processes commands
2. **Intent-based communication**: Uses Android's intent system to relay commands
3. **MainActivity integration**: Handles commands via the onNewIntent method
4. **Preferences-based configuration**: Updates settings through the PreferencesManager

### Command Flow

1. ADB command is sent via broadcast intent
2. AdbCommandReceiver receives the intent and processes the command
3. For simulation control, CommandExecutor sends an intent to MainActivity
4. MainActivity processes the command in the handleRemoteCommand method
5. For settings, PreferencesManager is updated directly

### Error Handling

The module includes error handling for:
- Invalid command parameters
- Commands that can't be executed due to simulation state
- Missing configuration files
- Invalid toggling of features 