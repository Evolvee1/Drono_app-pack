# API Documentation

This document describes all the API endpoints available in the Settings API Server for managing Android device settings.

## Base URL

All endpoints are relative to the base URL:

```
http://localhost:8000
```

## Authentication

The API does not currently implement authentication. If deploying in a production environment, consider adding an authentication layer.

## Endpoints

### Get Server Status

```
GET /
```

Returns the server status.

**Example Response:**
```json
{
  "status": "online",
  "message": "Device Settings API is running"
}
```

### List Devices

```
GET /devices
```

Lists all connected Android devices.

**Example Response:**
```json
{
  "devices": [
    {
      "id": "R9WR310F4GJ",
      "status": "connected",
      "model": "Pixel 4"
    },
    {
      "id": "emulator-5554",
      "status": "connected",
      "model": "Android SDK built for x86_64"
    }
  ],
  "count": 2
}
```

### Apply Settings

```
POST /apply-settings
```

Applies general settings to devices.

**Request Body:**
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
    "new_webview_per_request": true,
    "restore_on_exit": false,
    "use_proxy": false,
    "proxy_address": "",
    "proxy_port": 0
  },
  "devices": ["R9WR310F4GJ"],
  "all_devices": false,
  "parallel": true
}
```

**Parameters:**
- `settings`: Device settings to apply
  - `url`: Target URL for the simulation
  - `iterations`: Number of iterations to run (default: 900)
  - `min_interval`: Minimum interval between requests in seconds (default: 1)
  - `max_interval`: Maximum interval between requests in seconds (default: 2)
  - `delay`: Delay in milliseconds (default: 3000)
  - `webview_mode`: Whether to use webview mode (default: true)
  - `rotate_ip`: Whether to rotate IP between requests (default: true)
  - `random_devices`: Whether to use random device profiles (default: true)
  - `new_webview_per_request`: Whether to create new webview for each request (default: true)
  - `restore_on_exit`: Whether to restore IP on exit (default: false)
  - `use_proxy`: Whether to use proxy for connections (default: false)
  - `proxy_address`: Proxy server address (default: "")
  - `proxy_port`: Proxy server port (default: 0)
- `devices`: List of device IDs to target (optional if all_devices is true)
- `all_devices`: Whether to target all connected devices (optional)
- `parallel`: Whether to run commands in parallel (default: true)

**Example Response:**
```json
{
  "results": {
    "R9WR310F4GJ": {
      "status": "success",
      "return_code": 0,
      "success": true,
      "details": "Success output..."
    }
  },
  "summary": {
    "total_devices": 1,
    "success_count": 1,
    "failure_count": 0,
    "success_rate": 100.0
  }
}
```

### Apply Instagram Settings

```
POST /instagram-settings
```

Applies Instagram-specific settings (handles complex URLs).

**Request Body:**
```json
{
  "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com",
  "devices": ["R9WR310F4GJ"],
  "all_devices": false,
  "parallel": true
}
```

**Parameters:**
- `url`: The Instagram URL (required)
- `devices`: List of device IDs to target (optional if all_devices is true)
- `all_devices`: Whether to target all connected devices (optional)
- `parallel`: Whether to run commands in parallel (default: true)

**Example Response:**
```json
{
  "status": "success",
  "devices": ["R9WR310F4GJ"],
  "count": 1,
  "success_count": 1,
  "results": {
    "R9WR310F4GJ": {
      "status": "success",
      "details": "Successfully set Instagram URL"
    }
  }
}
```

### Direct URL Setting

```
POST /direct-url
```

Sets URL directly with maximum compatibility. This is the recommended approach for complex URLs.

**Request Body:**
```json
{
  "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com",
  "devices": ["R9WR310F4GJ"],
  "all_devices": false,
  "iterations": 1000,
  "min_interval": 1,
  "max_interval": 2,
  "webview_mode": true,
  "rotate_ip": true,
  "random_devices": true,
  "new_webview_per_request": true,
  "restore_on_exit": false,
  "use_proxy": false,
  "proxy_address": "",
  "proxy_port": 0,
  "parallel": true
}
```

**Parameters:**
- `url`: The URL to set (required)
- `devices`: List of device IDs to target (optional if all_devices is true)
- `all_devices`: Whether to target all connected devices (optional)
- `iterations`: Number of iterations to run (default: 1000)
- `min_interval`: Minimum interval between requests in seconds (default: 1)
- `max_interval`: Maximum interval between requests in seconds (default: 2)
- `webview_mode`: Whether to use webview mode (default: true)
- `rotate_ip`: Whether to rotate IP between requests (default: true)
- `random_devices`: Whether to use random device profiles (default: true)
- `new_webview_per_request`: Whether to create new webview for each request (default: true)
- `restore_on_exit`: Whether to restore IP on exit (default: false)
- `use_proxy`: Whether to use proxy for connections (default: false)
- `proxy_address`: Proxy server address (default: "")
- `proxy_port`: Proxy server port (default: 0)
- `parallel`: Whether to run commands in parallel (default: true)

**Example Response:**
```json
{
  "status": "success",
  "devices": ["R9WR310F4GJ"],
  "count": 1,
  "success_count": 1,
  "results": {
    "R9WR310F4GJ": {
      "status": "success",
      "details": "Successfully set URL"
    }
  }
}
```

## Error Handling

### Common Error Codes

- `400 Bad Request`: Missing required parameters or invalid request format
- `404 Not Found`: No connected devices found
- `500 Internal Server Error`: Server error during command execution

**Example Error Response:**
```json
{
  "detail": "No connected devices found"
}
```

## Using the Test Client

The accompanying test_settings_api.py script can be used to interact with these API endpoints from the command line. See the [Setup Guide](setup.md) for details on using the test client.

## Best Practices

1. **Use /direct-url for Complex URLs**
   - The `/direct-url` endpoint provides the most reliable way to set complex URLs

2. **Check Device Connectivity**
   - Always use the `/devices` endpoint to check device connectivity before sending commands

3. **Error Handling**
   - Always check the response status to handle errors appropriately

4. **Parallel vs. Sequential**
   - Use parallel execution when working with multiple devices for faster operation
   - Use sequential execution when troubleshooting or when device performance is a concern
