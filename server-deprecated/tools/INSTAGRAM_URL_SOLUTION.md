# Instagram URL Setting Solution

This document explains the solution implemented for reliably setting complex Instagram URLs on Android devices.

## The Problem

Setting complex Instagram URLs was failing because:

1. The URL contains special characters that need proper escaping
2. The app was overriding the settings on restart
3. Different mechanisms were needed to ensure the URL was properly set and loaded

## Our Solution

We created a comprehensive tool (`instagram_url_setter.py`) that uses multiple approaches simultaneously to ensure the URL is correctly set:

### 1. Multi-layered Approach

Our solution employs multiple techniques:

- **Force-stopping the app** before making changes
- **Directly modifying the config files** on the device
- **Using broadcast intents** to set the URL and WebView settings
- **Starting the app with direct intent** to load the URL

### 2. URL Configuration File

The app looks for a dedicated file (`url_config.xml`) for loading URLs. We:

- Create this file locally with proper XML structure
- Push it to both devices
- Ensure it has the correct permissions and ownership

### 3. Enhanced Broadcast Commands

We improved the broadcast intent mechanism by:

- Properly escaping the URL value
- Ensuring the PACKAGE_NAME parameter is correctly positioned
- Sending separate intents for WebView-related settings

### 4. Direct Intent Launch

We launch the app with a direct_url intent parameter, ensuring the URL is loaded immediately upon app start.

## How To Use

### Command-line Tool

To set a complex Instagram URL using the command-line tool:

```bash
python3 instagram_url_setter.py --url "your_complex_instagram_url" --webview-mode --new-webview-per-request
```

Additional options:
- `--device ID`: Target a specific device
- `--iterations N`: Set number of iterations
- `--min-interval N`: Set minimum interval (seconds)
- `--max-interval N`: Set maximum interval (seconds)
- `--rotate-ip`: Enable IP rotation
- `--random-devices`: Use random device profiles
- `--delay N`: Set airplane mode delay (milliseconds)

### Shell Script

We've also created a convenient shell script that calls the API:

```bash
./set_instagram_url.sh --url "your_complex_instagram_url"
```

The script supports all the same options as the Python tool, plus:
- `--api-host HOST:PORT`: Specify a different API server

### Server API Integration

The solution is now fully integrated with the server through a dedicated API. You can:

1. Use the dedicated Instagram API endpoints:

```
GET  /instagram/devices        - List connected devices
POST /instagram/set-url        - Set URL in background
POST /instagram/set-instagram-url-sync - Set URL synchronously
POST /instagram/restart-app    - Restart the app
```

2. Use curl to call the API:

```bash
curl -X POST "http://localhost:8000/instagram/set-url" \
  -H "Content-Type: application/json" \
  -d '{"url": "your_url", "webview_mode": true, "new_webview_per_request": true}'
```

3. Import the functionality in your own Python code:

```python
from tools.instagram_url_setter import set_instagram_url

result = await set_instagram_url(
    device_id="your_device_id",
    url="your_url",
    webview_mode=True,
    new_webview_per_request=True
)
```

## Verification

To verify the URL has been set:

1. Check the URL config file:
   ```bash
   adb -s DEVICE_ID shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml"
   ```

2. Check the main preferences:
   ```bash
   adb -s DEVICE_ID shell "run-as com.example.imtbf.debug cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml"
   ```

3. Check that WebView is being used:
   ```bash
   adb -s DEVICE_ID logcat -d | grep -i webview | tail -20
   ```

## Troubleshooting

If the URL isn't being loaded:

1. Force-stop the app and try again:
   ```bash
   adb -s DEVICE_ID shell am force-stop com.example.imtbf.debug
   ```

2. Check if you have proper access to the device:
   ```bash
   adb -s DEVICE_ID shell "run-as com.example.imtbf.debug ls" 
   # Or for root
   adb -s DEVICE_ID shell "su -c 'ls /data/data/com.example.imtbf.debug'"
   ```

3. Try directly setting the URL with the simplified method:
   ```bash
   adb -s DEVICE_ID shell am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity -e direct_url "YOUR_URL"
   ```

## Additional Resources

For more information, please refer to:

- [COMPREHENSIVE_API_GUIDE.md](./COMPREHENSIVE_API_GUIDE.md): Detailed guide for the improved API
- [PRACTICAL_EXAMPLES.md](./PRACTICAL_EXAMPLES.md): Real-world examples for various scenarios
- [INSTAGRAM_URL_GUIDE.md](./INSTAGRAM_URL_GUIDE.md): Specialized guide for Instagram URLs
- [COMPLEX_URL_TROUBLESHOOTING.md](./COMPLEX_URL_TROUBLESHOOTING.md): Troubleshooting guide for complex URLs 