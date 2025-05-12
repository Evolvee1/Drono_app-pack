# Device Settings API

This API allows frontend dashboards to easily manage settings for Android devices via ADB. It provides endpoints to:

1. List all connected devices
2. Apply general settings to devices
3. Apply Instagram-specific settings (handles complex URLs)
4. Set URLs directly with maximum compatibility (recommended for complex URLs)

## Quick Start

1. Install required packages:
   ```bash
   pip install fastapi uvicorn pydantic requests
   ```

2. Start the API server:
   ```bash
   ./settings_api_server.py
   ```

3. The server will start at http://localhost:8000

## Command Line Usage

The `test_settings_api.py` script provides an easy way to interact with the API:

### Recommended Usage:

```bash
# For the most reliable URL setting (recommended for complex URLs):
python3 test_settings_api.py cmd --url "https://l.instagram.com/?u=https%3A%2F%2Fexample.com" --devices DEVICE_ID

# For simpler URLs or regular settings:
python3 test_settings_api.py apply --url "https://example.com" --devices DEVICE_ID

# To list connected devices:
python3 test_settings_api.py list

# For built-in help guide:
python3 test_settings_api.py help
```

Add `--verbose` or `-v` for more detailed output.
Use `--all-devices` to target all connected devices instead of specifying individual ones.

## API Endpoints

### GET /devices
Lists all connected devices with their status.

**Response:**
```json
{
  "devices": [
    {
      "id": "emulator-5554",
      "status": "connected",
      "model": "Pixel 4"
    }
  ],
  "count": 1
}
```

### POST /apply-settings
Apply general settings to devices.

**Request:**
```json
{
  "settings": {
    "url": "https://example.com",
    "iterations": 900,
    "min_interval": 1,
    "max_interval": 2,
    "delay": 3000,
    "webview_mode": true,
    "rotate_ip": true,
    "random_devices": true,
    "new_webview_per_request": true
  },
  "devices": ["emulator-5554"],
  "all_devices": false,
  "parallel": true
}
```

### POST /instagram-settings
Apply Instagram-specific settings (better handling of complex URLs).

**Request:**
```json
{
  "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com",
  "devices": ["emulator-5554"],
  "all_devices": false,
  "parallel": true
}
```

### POST /direct-url
Set URL directly with maximum compatibility (recommended for complex URLs).

**Request:**
```json
{
  "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com",
  "devices": ["emulator-5554"],
  "all_devices": false,
  "parallel": true
}
```

## Frontend Integration

To integrate with your frontend dashboard:

1. Make API calls to the appropriate endpoints
2. Use the `/direct-url` endpoint for the most reliable URL setting
3. Check the response for success status and details

Example JavaScript code:
```javascript
async function setUrlOnDevices(url, deviceIds) {
  const response = await fetch('http://localhost:8000/direct-url', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      url: url,
      devices: deviceIds,
      parallel: true
    }),
  });
  
  const data = await response.json();
  return data;
}
```

## Troubleshooting

If URL setting fails:

1. Make sure the devices are properly connected and authorized
2. Check that the app is installed on the devices
3. Try the `cmd` command which uses the most direct approach
4. Examine logs in `server/tools/logs/` for detailed error information

## Support

For advanced usage or troubleshooting, see the full documentation in the `docs` directory. 