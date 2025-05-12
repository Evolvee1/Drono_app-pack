# Drono Control Script

The `drono_control.sh` script is a comprehensive tool for controlling the Drono app from the command line. It provides the most reliable methods for changing settings and controlling the app, addressing UI update issues and ensuring settings changes are properly applied.

## Features

- **Direct Preferences Editing**: The most reliable way to change app settings
- **UI Refreshing**: Properly restarts the app to ensure UI updates
- **Simulation Control**: Start, stop, pause, and resume simulations
- **Settings Management**: Change URL, iterations, intervals, delays, and toggle features
- **Preset Configurations**: Apply predefined configurations with a single command
- **Status Reporting**: View current app settings and status

## Getting Started

```bash
# Make the script executable
chmod +x drono_control.sh

# Show help information
./drono_control.sh help
```

## Running the App

To run the app from the terminal:

```bash
# Start with default settings
./drono_control.sh start

# Apply a preset configuration and start
./drono_control.sh preset veewoy start

# Apply custom settings and start
./drono_control.sh url https://veewoy.com/ip-text iterations 500 min_interval 1 max_interval 2 start
```

## Best Practices for Reliable Operation

For the most reliable results, follow these steps:

```bash
# Method 1: Step by step (most reliable)
# 1. Stop the app completely
./drono_control.sh stop
adb shell am force-stop com.example.imtbf.debug

# 2. Apply your settings
./drono_control.sh iterations 1000 min_interval 1 max_interval 5 delay 3000

# 3. Start the simulation
./drono_control.sh start

# 4. Check status
./drono_control.sh status

# Method 2: Using the -settings flag (convenient one-liner)
./drono_control.sh -settings url https://veewoy.com/ip-text iterations 500 min_interval 1 max_interval 2 start
```

## Available Commands

### Simulation Control

```bash
# Start the simulation
./drono_control.sh start

# Stop the simulation
./drono_control.sh stop

# Pause the simulation
./drono_control.sh pause

# Resume the simulation
./drono_control.sh resume

# Restart the app
./drono_control.sh restart
```

### Setting Commands

```bash
# Set target URL
./drono_control.sh url https://veewoy.com/ip-text

# Set iterations
./drono_control.sh iterations 500

# Set min/max intervals
./drono_control.sh min_interval 1 max_interval 5

# Set airplane mode delay
./drono_control.sh delay 3000

# Toggle features
./drono_control.sh toggle rotate_ip true
./drono_control.sh toggle webview_mode false
```

### Preset Configurations

```bash
# Apply the veewoy preset
./drono_control.sh preset veewoy

# Apply performance preset
./drono_control.sh preset performance

# Apply stealth preset
./drono_control.sh preset stealth

# Apply balanced preset
./drono_control.sh preset balanced

./drono_control.sh -settings url https://veewoy.com/ip-text iterations 500 min_interval 1 max_interval 2 toggle webview_mode false start

```

### Status Command

```bash
# Show current status and settings
./drono_control.sh status
```

## Preset Configurations

The script includes several predefined configuration presets:

### Veewoy Preset

```
URL: https://veewoy.com/ip-text
Iterations: 500
Min Interval: 1s, Max Interval: 2s
Airplane Mode Delay: 3000ms
IP Rotation: enabled
Random Devices: enabled
WebView Mode: enabled
```

### Performance Preset

```
URL: https://instagram.com
Iterations: 50
Min Interval: 3s, Max Interval: 10s
Airplane Mode Delay: 3000ms
IP Rotation: enabled
Random Devices: enabled
WebView Mode: disabled
```

### Stealth Preset

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

### Balanced Preset

```
URL: https://instagram.com
Iterations: 40
Min Interval: 5s, Max Interval: 15s
Airplane Mode Delay: 4000ms
IP Rotation: enabled
Random Devices: enabled
WebView Mode: enabled
```

## Features that can be toggled

You can toggle the following features on or off:

- `rotate_ip` - Toggle IP rotation
- `random_devices` - Toggle random device profiles
- `webview_mode` - Toggle WebView mode
- `aggressive_clearing` - Toggle aggressive session clearing
- `new_webview_per_request` - Toggle new WebView per request
- `handle_redirects` - Toggle handling of marketing redirects

## Example Usage Scenarios

### Basic Workflow

```bash
# Stop the app completely
adb shell am force-stop com.example.imtbf.debug

# Apply the veewoy preset and start simulation
./drono_control.sh preset veewoy start

# Check status after a while
./drono_control.sh status
```

### Custom Settings Workflow

```bash
# Stop app
adb shell am force-stop com.example.imtbf.debug

# Apply custom settings and start
./drono_control.sh url https://veewoy.com/ip-text iterations 1000 min_interval 2 max_interval 8 delay 4000 start

# Pause the simulation after a while
./drono_control.sh pause

# Change settings while paused
./drono_control.sh min_interval 1 max_interval 5

# Resume the simulation
./drono_control.sh resume
```

### Advanced Workflow

```bash
#!/bin/bash
# Example automation script

# Stop the app
adb shell am force-stop com.example.imtbf.debug
sleep 1

# Apply settings
./drono_control.sh preset veewoy

# Toggle features
./drono_control.sh toggle webview_mode false
./drono_control.sh toggle aggressive_clearing true

# Start the simulation
./drono_control.sh start

# Run for 30 minutes
echo "Running simulation for 30 minutes..."
sleep 1800

# Update settings
./drono_control.sh stop
./drono_control.sh min_interval 3 max_interval 10
./drono_control.sh start

# Run for another 30 minutes
echo "Running simulation with new settings for 30 minutes..."
sleep 1800

# Stop the simulation
./drono_control.sh stop
```

## Troubleshooting

If you encounter issues with settings not being applied correctly:

1. **Stop the App Completely**: Always use `adb shell am force-stop com.example.imtbf.debug` before changing settings
2. **Verify Settings**: Use `./drono_control.sh status` to verify settings were applied
3. **Check Access**: The script requires either root access or a debug build of the app
4. **Restart After Changes**: Always restart the app after changing settings for them to take effect in the UI

## Recent Improvements

### Session Management

The script now provides full control over session restoration and dismissal:

```bash
# Check if a saved session exists
./drono_control.sh check_session

# Restore a previously saved session
./drono_control.sh restore_session

# Dismiss the restore session dialog (start fresh)
./drono_control.sh dismiss_restore

# Dismiss the dialog and start a new session in one command
./drono_control.sh dismiss_restore start
```

These commands allow you to:
- Automatically dismiss the "Restore Session" dialog that appears when reopening the app
- Restore a previously saved session via ADB without manual interaction
- Check if there's a saved session available to restore
- Combine session management with other commands

The status command now also shows information about saved sessions:
```
------------ SAVED SESSION ------------
✅ Found saved session data available for restoration
Progress: 23/500
Paused: true
Commands: ./drono_control.sh restore_session   # To restore
          ./drono_control.sh dismiss_restore   # To dismiss
--------------------------------------
```

### Settings Application Mode

The new `-settings` flag provides a reliable way to apply multiple settings at once before starting the app:

```bash
./drono_control.sh -settings url https://veewoy.com/ip-text iterations 600 min_interval 1 max_interval 2 delay 3000 start
```

This flag ensures:
- The app is force-stopped before applying any settings
- All settings are applied in sequence
- The app is only started after all settings have been successfully applied
- UI correctly reflects all the changed settings

This solves issues where settings weren't being properly applied when using multiple commands followed by `start` in a single line.

### Enhanced App Launch Verification

The script now intelligently:
- Waits for the app to be fully launched and responsive before proceeding
- Verifies that the UI activity is in foreground 
- Shows clear status messages between settings application and simulation start
- Confirms that the simulation has actually started by checking preferences

Example of the improved output:
```
============================================================
✅ SETTINGS: All settings have been successfully applied
============================================================

============================================================
🚀 STARTING SIMULATION: Launching app and starting simulation
============================================================
Starting simulation...
App is not running, launching app...
Starting app...
Waiting for app to start...
  Still waiting... (1 seconds)
  Still waiting... (2 seconds)
✅ App is running and activity is responsive
Setting is_running preference to true...
Updating is_running to true...
✅ Verified: is_running is now set to true
Sending start command to app...
Sending activity command: start
✅ SUCCESS: Simulation started successfully
Simulation start sequence completed

============================================================
🏁 OPERATION COMPLETE
============================================================
```

### Comprehensive Status Reporting

The `status` command now provides detailed information about:
- Whether the app process is running
- If the app activity is in the foreground
- Whether the simulation is actually running
- Recent log activity related to the simulation

Example output:
```
Checking app status...
✅ App process is running
   Process ID: 12345
✅ App activity is in foreground
------------ SIMULATION STATUS ------------
✅ SIMULATION IS RUNNING

------------ CURRENT SETTINGS ------------
URL: https://veewoy.com/ip-text
Iterations: 500
Min interval: 1 seconds
Max interval: 2 seconds
Airplane mode delay: 3000 ms
--------------- FEATURES ----------------
IP Rotation: true
WebView Mode: true
Random Device Profiles: true
----------------------------------------

------------ RECENT LOG ACTIVITY ------------
TrafficManager: Starting iteration 1/500
TrafficManager: Request completed successfully
---------------------------------------------
```

### Dry Run Mode

The new `-dryrun` flag allows you to preview what changes would be made without actually applying them:

```bash
./drono_control.sh -dryrun preset veewoy
./drono_control.sh -dryrun -settings url https://veewoy.com iterations 600 start
```

This is useful for:
- Learning what settings a specific preset contains
- Testing complex command chains before executing them
- Verifying the settings you're about to apply
- Understanding what the script will do without affecting the app

The output clearly labels each action with `[DRY RUN]` to indicate that no changes are being made.

## Technical Details

The script uses multiple approaches to ensure settings changes are reliably applied:

1. **Direct Preferences Editing**: Directly modifies the shared preferences XML file
2. **Verification**: Verifies that changes were successfully applied
3. **Multiple Access Methods**: Supports both root and run-as access methods
4. **ADB Broadcast Fallback**: Falls back to ADB broadcasts if direct access isn't available 