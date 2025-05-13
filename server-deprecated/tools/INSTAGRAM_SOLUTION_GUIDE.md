# Instagram URL Manager - User Guide

This guide explains how to use the new unified Instagram URL Manager solution to set complex Instagram URLs on Android devices.

## Quick Start

### Setting URLs via API

```bash
# Start the server
cd server
python main.py
```

Then make an API request:

```bash
curl -X POST "http://localhost:8000/instagram/set-url" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.instagram.com/p/your-complex-url",
    "iterations": 100,
    "min_interval": 3,
    "max_interval": 5,
    "webview_mode": true,
    "new_webview_per_request": true,
    "rotate_ip": true,
    "random_devices": true
  }'
```

### Setting URLs via Command Line

Use the shell script:

```bash
cd server/tools
./set_instagram_url.sh --url "https://www.instagram.com/p/your-complex-url"
```

Or use the Python CLI directly:

```bash
cd server/tools
./instagram_cli.py set-url --url "https://www.instagram.com/p/your-complex-url"
```

## Detailed Usage Guide

### Core Features

The Instagram URL Manager provides these key features:

1. **URL Setting**: Set any Instagram URL, including complex URLs with special parameters
2. **Multi-Device Support**: Set URLs on multiple devices simultaneously
3. **Customizable Settings**: Control iterations, intervals, and features
4. **Verification**: Automatically verify that URLs are properly loaded
5. **Multiple Access Options**: API integration, command-line tools, and direct module usage

### API Endpoints

The server provides these endpoints:

#### 1. Get Connected Devices

```
GET /instagram/devices
```

Returns a list of connected devices.

#### 2. Set Instagram URL (Async)

```
POST /instagram/set-url
```

Sets the Instagram URL asynchronously (background task).

**Parameters:**
```json
{
  "url": "https://www.instagram.com/p/your-url",
  "iterations": 100,
  "min_interval": 3,
  "max_interval": 5,
  "webview_mode": true,
  "new_webview_per_request": true,
  "rotate_ip": true,
  "random_devices": true,
  "delay": 3000,
  "devices": ["device1", "device2"],
  "all_devices": false
}
```

All parameters except `url` are optional.

#### 3. Set Instagram URL (Sync)

```
POST /instagram/set-url-sync
```

Sets the Instagram URL synchronously. Takes the same parameters as the async endpoint.

#### 4. Restart App

```
POST /instagram/restart-app
```

Restarts the app on the specified device(s).

**Parameters:**
```json
{
  "devices": ["device1", "device2"],
  "all_devices": false
}
```

#### 5. Get Device Status

```
GET /instagram/device/{device_id}/status
```

Returns the status of a specific device.

#### 6. Set URL on Specific Device

```
POST /instagram/device/{device_id}/set-url
```

Sets the Instagram URL on a specific device. Takes the same parameters as the main set-url endpoint except for `devices` and `all_devices`.

### Command-Line Tools

#### Shell Script

The `set_instagram_url.sh` script provides a simple way to set URLs from the command line:

```bash
./set_instagram_url.sh --url "https://www.instagram.com/p/your-url" [options]
```

**Options:**
- `--device <id>`: Target a specific device
- `--iterations <num>`: Number of iterations
- `--min-interval <sec>`: Minimum interval between requests
- `--max-interval <sec>`: Maximum interval between requests
- `--webview-mode <true|false>`: Enable/disable WebView mode
- `--new-webview-per-request <true|false>`: Create new WebView per request
- `--rotate-ip <true|false>`: Rotate IP between requests
- `--random-devices <true|false>`: Use random device profiles
- `--delay <ms>`: Airplane mode delay in milliseconds

#### Python CLI

The `instagram_cli.py` provides more commands:

1. **List Devices**:
   ```bash
   ./instagram_cli.py list
   ```

2. **Set URL**:
   ```bash
   ./instagram_cli.py set-url --url "https://www.instagram.com/p/your-url" [options]
   ```
   
   Options:
   - `--device <id>`: Target a specific device
   - `--iterations <num>`: Number of iterations
   - `--min-interval <sec>`: Minimum interval between requests
   - `--max-interval <sec>`: Maximum interval between requests
   - `--[no-]webview-mode`: Enable/disable WebView mode
   - `--[no-]new-webview-per-request`: Enable/disable new WebView per request
   - `--[no-]rotate-ip`: Enable/disable IP rotation
   - `--[no-]random-devices`: Enable/disable random device profiles
   - `--delay <ms>`: Airplane mode delay in milliseconds

3. **Restart App**:
   ```bash
   ./instagram_cli.py restart [--device <id>]
   ```

### Direct Module Usage

For more advanced use cases, you can use the Instagram manager directly in your code:

```python
import asyncio
from core.instagram_manager import instagram_manager

async def example():
    # Get devices
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

asyncio.run(example())
```

## Configuration Details

### URL Setting Process

The system uses three methods simultaneously to ensure the URL is set:

1. **Configuration Files**: Creates and pushes XML configurations
2. **Broadcast Commands**: Sends intents to set URL and features
3. **Direct Intent**: Launches the app with the URL as a parameter

### Settings Explained

- **url**: The Instagram URL to set
- **iterations**: Number of times to load the URL
- **min_interval/max_interval**: Interval between requests (seconds)
- **webview_mode**: Use WebView to load URLs
- **new_webview_per_request**: Create a new WebView for each request
- **rotate_ip**: Rotate IP between requests
- **random_devices**: Use random device profiles
- **delay**: Delay in milliseconds

## Troubleshooting

### Common Issues

1. **Device Not Found**: Make sure the device is connected and listed in `adb devices`
2. **URL Not Loading**: Try increasing the delay, or try setting with different parameters
3. **App Crashes**: Make sure the app is properly installed and has proper permissions

### Debugging

1. To see more detailed logs:
   ```bash
   adb -s <device_id> logcat | grep -E "WebView|instagram|example.imtbf"
   ```

2. Check the configuration file:
   ```bash
   adb -s <device_id> shell run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml
   ```

3. Run the test script to check overall functionality:
   ```bash
   ./test_instagram_solution.sh
   ```

## Conclusion

This unified Instagram URL Manager solution provides a reliable, flexible way to set complex Instagram URLs on Android devices. By using multiple approaches simultaneously and providing multiple interfaces, it ensures that the URL is set correctly and is accessible in the way that best fits your workflow. 