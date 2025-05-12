# Instagram Manager - Unified Solution

This document explains the new unified Instagram URL Manager solution, designed to provide a more reliable, direct approach to setting Instagram URLs on Android devices.

## Key Features

1. **Unified Architecture**
   - Centralized `instagram_manager` module in the core directory
   - Direct integration with the server, no separate API server needed
   - Consistent API for all Instagram URL operations

2. **Multiple Access Methods**
   - Robust device detection and management
   - Support for both run-as and root access methods
   - Fallback to broadcast-only mode when direct file access isn't available

3. **Comprehensive URL Setting**
   - XML configuration file generation and deployment
   - Broadcast intent commands for runtime configuration
   - Direct URL loading via intent
   - Verification of URL loading

4. **Flexible Usage Options**
   - Direct API routes in the main server
   - Command-line interface through `instagram_cli.py`
   - Shell script wrapper for easy usage

## Components

### Core Module

`server/core/instagram_manager.py` - The central component that handles all Instagram URL functionality:

- Device detection and management
- URL configuration creation and deployment
- Broadcast commands for feature toggles
- App restart functionality
- URL loading verification

### API Integration

`server/api/instagram_routes.py` - FastAPI routes that directly interface with the Instagram manager:

- `/instagram/devices` - List connected devices
- `/instagram/set-url` - Set URL asynchronously (background task)
- `/instagram/set-url-sync` - Set URL synchronously
- `/instagram/restart-app` - Restart the app
- `/instagram/device/{device_id}/status` - Get device status
- `/instagram/device/{device_id}/set-url` - Set URL on a specific device

### Command-Line Tools

1. `server/tools/instagram_cli.py` - Python CLI tool with commands:
   - `list` - List connected devices
   - `set-url` - Set Instagram URL with various options
   - `restart` - Restart the app

2. `server/tools/set_instagram_url.sh` - Shell script wrapper around the CLI tool

## Usage Examples

### API Usage

```python
# Using the API directly
from fastapi import FastAPI
from api.instagram_routes import router as instagram_router

app = FastAPI()
app.include_router(instagram_router)
```

### Direct Module Usage

```python
# Using the Instagram manager directly
import asyncio
from core.instagram_manager import instagram_manager

async def set_url_example():
    # Get connected devices
    devices = await instagram_manager.get_connected_devices()
    
    # Set URL on first device
    if devices:
        result = await instagram_manager.set_instagram_url(
            device_id=devices[0].id,
            url="https://www.instagram.com/p/your-url",
            webview_mode=True,
            iterations=100
        )
        print(result)

# Run the example
asyncio.run(set_url_example())
```

### Command-Line Usage

```bash
# List connected devices
python3 server/tools/instagram_cli.py list

# Set URL on all devices
python3 server/tools/instagram_cli.py set-url --url "https://www.instagram.com/p/your-url"

# Set URL on specific device
python3 server/tools/instagram_cli.py set-url --url "https://www.instagram.com/p/your-url" --device R38N9014KDM

# With additional options
python3 server/tools/instagram_cli.py set-url --url "https://www.instagram.com/p/your-url" --iterations 50 --min-interval 2 --max-interval 4

# Using the shell script
bash server/tools/set_instagram_url.sh --url "https://www.instagram.com/p/your-url" --device R38N9014KDM
```

## Testing

To test the functionality:

```bash
python3 server/tools/test_instagram_manager.py
```

This will:
1. Detect connected devices
2. Try to set a test URL
3. Restart the app
4. Report the results of each step

## Implementation Details

### URL Configuration

The URL is set through multiple methods to ensure reliable operation:

1. **XML Configuration Files**
   - `url_config.xml` - Contains the Instagram URL
   - `instagram_traffic_simulator_prefs.xml` - Contains settings like iterations and intervals

2. **Broadcast Intents**
   - `set_url` command to set the URL
   - `toggle_feature` commands to set WebView mode, etc.

3. **Direct URL Intent**
   - Starts the app with a direct URL parameter

### Verification

After setting the URL, the system verifies it was loaded by:

1. Checking logcat for URL loading messages
2. Checking for running WebView processes

## Advantages Over Previous Solution

1. **Simplicity**: One unified module rather than separate components
2. **Reliability**: Direct integration rather than separate processes
3. **Performance**: No HTTP overhead between components
4. **Maintainability**: Centralized code is easier to update and debug
5. **Flexibility**: Multiple usage methods for different scenarios (API, CLI, direct) 