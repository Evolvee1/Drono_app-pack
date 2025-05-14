# Drono Lite API Reference

This document provides a comprehensive reference for the Drono Lite API endpoints and commands for controlling Android devices running the IMadeThatBitchFamous app.

## REST API Endpoints

### Device Management

#### List All Devices

```
GET /devices
```

**Response:**
```json
[
  {
    "id": "R9WR310F4GJ",
    "model": "Pixel 4",
    "status": "online",
    "battery": "85%",
    "has_write_access": true,
    "has_root_access": true
  },
  {
    "id": "R38M20492LK",
    "model": "Galaxy S20",
    "status": "online",
    "battery": "72%",
    "has_write_access": true,
    "has_root_access": true
  }
]
```

#### Scan for Devices

```
POST /devices/scan
```

**Response:**
```json
{
  "device_count": 2,
  "devices": [
    {
      "id": "R9WR310F4GJ",
      "model": "Pixel 4",
      "status": "online",
      "battery": "85%",
      "has_write_access": true,
      "has_root_access": true
    },
    {
      "id": "R38M20492LK",
      "model": "Galaxy S20",
      "status": "online",
      "battery": "72%",
      "has_write_access": true,
      "has_root_access": true
    }
  ]
}
```

### Device Status

#### Get Status for All Devices

```
GET /devices/status
```

**Response:**
```json
{
  "devices_status": {
    "R9WR310F4GJ": {
      "device_id": "R9WR310F4GJ",
      "is_running": true,
      "current_iteration": 45,
      "total_iterations": 100,
      "percentage": 45,
      "url": "https://example.com",
      "min_interval": 1,
      "max_interval": 2,
      "delay_min": 1,
      "delay_max": 2,
      "elapsed_time": 120,
      "estimated_remaining": 180,
      "status": "running",
      "last_update": "2023-05-01T12:34:56.789Z"
    },
    "R38M20492LK": {
      "device_id": "R38M20492LK",
      "is_running": false,
      "current_iteration": 0,
      "total_iterations": 0,
      "percentage": 0,
      "url": "",
      "min_interval": 0,
      "max_interval": 0,
      "delay_min": 0,
      "delay_max": 0,
      "elapsed_time": 0,
      "estimated_remaining": 0,
      "status": "stopped",
      "last_update": "2023-05-01T12:34:56.789Z"
    }
  },
  "timestamp": "2023-05-01T12:34:56.789Z"
}
```

#### Get Status for Specific Device

```
GET /devices/{device_id}/status
```

**Response:**
```json
{
  "device_id": "R9WR310F4GJ",
  "is_running": true,
  "current_iteration": 45,
  "total_iterations": 100,
  "percentage": 45,
  "url": "https://example.com",
  "min_interval": 1,
  "max_interval": 2,
  "delay_min": 1,
  "delay_max": 2,
  "elapsed_time": 120,
  "estimated_remaining": 180,
  "status": "running",
  "last_update": "2023-05-01T12:34:56.789Z",
  "timestamp": "2023-05-01T12:34:56.789Z"
}
```

#### Get Timing for Specific Device

```
GET /devices/{device_id}/timing
```

**Response:**
```json
{
  "device_id": "R9WR310F4GJ",
  "timing_info": {
    "device_id": "R9WR310F4GJ",
    "actual_elapsed_ms": 120000,
    "remaining_time_ms": 180000,
    "current_iteration": 45,
    "total_iterations": 100,
    "success": true
  },
  "timestamp": "2023-05-01T12:34:56.789Z"
}
```

### URL Distribution

#### Distribute URL to Devices

```
POST /distribute-url
```

**Request Body:**
```json
{
  "device_ids": ["R9WR310F4GJ", "R38M20492LK"],
  "url": "https://example.com",
  "iterations": 100,
  "min_interval": 1,
  "max_interval": 2,
  "use_webview": true,
  "rotate_ip": true
}
```

**Response:**
```json
{
  "R9WR310F4GJ": {
    "success": true,
    "settings_method": "root",
    "message": "App is running with PID: 12345",
    "url": "https://example.com",
    "current_url": "https://example.com",
    "iterations": 100
  },
  "R38M20492LK": {
    "success": true,
    "settings_method": "root",
    "message": "App is running with PID: 23456",
    "url": "https://example.com",
    "current_url": "https://example.com",
    "iterations": 100
  }
}
```

### Device Commands

#### Execute Command on Device

```
POST /devices/{device_id}/command
```

**Request Body:**
```json
{
  "command": "start",
  "parameters": {
    "url": "https://example.com",
    "iterations": 100,
    "min_interval": 1,
    "max_interval": 2,
    "use_webview": true,
    "rotate_ip": true
  }
}
```

**Response:**
```json
{
  "success": true,
  "command": "start",
  "device_id": "R9WR310F4GJ",
  "result": {
    "success": true,
    "settings_method": "root",
    "message": "App is running with PID: 12345",
    "url": "https://example.com",
    "current_url": "https://example.com",
    "iterations": 100
  }
}
```

#### Batch Command Execution

```
POST /devices/batch/command
```

**Request Body:**
```json
{
  "device_ids": ["R9WR310F4GJ", "R38M20492LK"],
  "command": "stop"
}
```

**Response:**
```json
{
  "R9WR310F4GJ": {
    "success": true,
    "command": "stop",
    "device_id": "R9WR310F4GJ",
    "stdout": "",
    "stderr": ""
  },
  "R38M20492LK": {
    "success": true,
    "command": "stop",
    "device_id": "R38M20492LK",
    "stdout": "",
    "stderr": ""
  }
}
```

## Supported Commands

The following commands can be sent to devices:

### start

Starts traffic simulation with the specified URL and parameters.

**Parameters:**
- `url`: Target URL (e.g., "https://example.com")
- `iterations`: Number of iterations to perform (default: 100)
- `min_interval`: Minimum interval between requests in seconds (default: 1)
- `max_interval`: Maximum interval between requests in seconds (default: 2)
- `use_webview`: Whether to use WebView mode (default: true)
- `rotate_ip`: Whether to rotate IP addresses (default: true)

### stop

Stops the application completely.

**Parameters:** None

### pause

Pauses the current traffic simulation without closing the app.

**Parameters:** None

### resume

Resumes a paused traffic simulation.

**Parameters:** None

### reload

Reloads the current URL configuration.

**Parameters:**
- `value`: New URL to load (optional)

## WebSocket API

The server provides WebSocket endpoints for real-time updates.

### Connection

```
WS /ws/{channel}
```

Where `{channel}` can be:
- `devices`: For device status updates
- `commands`: For command execution updates
- `logs`: For server log updates

## Status Updates Configuration

Drono Lite provides control over how often status updates are fetched from devices, which can impact device performance.

### Get Status Update Configuration

```
GET /settings/status-updates
```

**Response:**
```json
{
  "status": "success",
  "config": {
    "automatic": false,
    "interval": 3600
  }
}
```

### Configure Status Updates

```
POST /settings/status-updates
```

**Request Body:**
```json
{
  "automatic": false,
  "interval": 3600
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Automatic status updates disabled, interval set to 1 hour(s)",
  "config": {
    "automatic": false,
    "interval": 3600
  }
}
```

### Set Extended Update Interval

Use this endpoint to set a very long interval to reduce device lag.

```
POST /settings/extended-interval/{minutes}
```

Where `{minutes}` is the desired interval in minutes (between 1 and 1440).

**Response:**
```json
{
  "status": "success",
  "message": "Extended update interval set to 4 hour(s), automatic updates disabled",
  "config": {
    "automatic": false,
    "interval": 14400
  }
}
```

### Manual Status Update

To get updated status information without waiting for the automatic interval:

```
POST /devices/request-status
```

**Response:**
```json
{
  "status": "success",
  "message": "Status updated for 5 devices"
}
```

### Message Format

Messages are JSON objects with the following structure:

```json
{
  "type": "device_update",
  "data": {
    "device_id": "R9WR310F4GJ",
    "status": "online",
    "battery": "85%"
  }
}
```

Message types include:
- `device_update`: Device status changes
- `command_result`: Command execution results
- `log_message`: Server log entries

### Status Update Message

Status updates provide real-time information about device simulation progress:

```json
{
  "type": "status_update",
  "data": {
    "devices_status": {
      "R9WR310F4GJ": {
        "device_id": "R9WR310F4GJ",
        "is_running": true,
        "current_iteration": 45,
        "total_iterations": 100,
        "percentage": 45.0,
        "url": "https://example.com",
        "min_interval": 1,
        "max_interval": 2,
        "delay_min": 1,
        "delay_max": 2,
        "elapsed_time": 120,
        "estimated_remaining": 180,
        "status": "running",
        "last_update": "2023-05-01T12:34:56.789Z"
      }
    },
    "timestamp": "2023-05-01T12:34:56.789Z"
  }
}
```

You can also request status information for a specific device:

```json
// Send:
{
  "type": "get_device_status",
  "device_id": "R9WR310F4GJ"
}

// Receive:
{
  "type": "device_status",
  "data": {
    "device_id": "R9WR310F4GJ",
    "status": {
      "device_id": "R9WR310F4GJ",
      "is_running": true,
      "current_iteration": 45,
      "total_iterations": 100,
      "percentage": 45.0,
      "url": "https://example.com",
      "min_interval": 1,
      "max_interval": 2,
      "delay_min": 1,
      "delay_max": 2,
      "elapsed_time": 120,
      "estimated_remaining": 180,
      "status": "running",
      "last_update": "2023-05-01T12:34:56.789Z",
      "timestamp": "2023-05-01T12:34:56.789Z"
    },
    "timestamp": "2023-05-01T12:34:56.789Z"
  }
}
```

## Example Code

### Python Example (using requests)

```python
import requests

# Server URL
base_url = "http://localhost:8000"

# List all devices
response = requests.get(f"{base_url}/devices")
devices = response.json()
print(f"Connected devices: {len(devices)}")

# Distribute URL to all devices
payload = {
    "device_ids": [device["id"] for device in devices],
    "url": "https://example.com",
    "iterations": 100,
    "min_interval": 1,
    "max_interval": 2
}
response = requests.post(f"{base_url}/distribute-url", json=payload)
results = response.json()
print(f"URL distribution results: {results}")
```

### JavaScript Example (using fetch)

```javascript
// Server URL
const baseUrl = "http://localhost:8000";

// List all devices
fetch(`${baseUrl}/devices`)
  .then(response => response.json())
  .then(devices => {
    console.log(`Connected devices: ${devices.length}`);
    
    // Distribute URL to all devices
    const payload = {
      device_ids: devices.map(device => device.id),
      url: "https://example.com",
      iterations: 100,
      min_interval: 1,
      max_interval: 2
    };
    
    return fetch(`${baseUrl}/distribute-url`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });
  })
  .then(response => response.json())
  .then(results => {
    console.log("URL distribution results:", results);
  })
  .catch(error => {
    console.error("Error:", error);
  });
``` 