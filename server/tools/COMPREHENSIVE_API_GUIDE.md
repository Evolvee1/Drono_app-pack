# Comprehensive Device Settings API Guide

## Overview

The Improved Device Settings API provides a reliable and efficient way to manage settings on Android devices, particularly for URL configuration and webview settings. This document provides comprehensive instructions on how to use the API system.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Command-Line Usage](#command-line-usage)
5. [REST API Reference](#rest-api-reference)
6. [Working with Complex URLs](#working-with-complex-urls)
7. [Troubleshooting](#troubleshooting)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Migration from Legacy API](#migration-from-legacy-api)

## System Architecture

The improved API consists of three main components:

1. **Unified Command API (`unified_command_api.py`)** - Core library that handles device communication with maximum reliability using a hybrid approach combining:
   - Direct preference file modification
   - Intent broadcasting
   - Deep link activation

2. **Settings API Server (`improved_settings_api.py`)** - FastAPI-based REST server providing HTTP endpoints for device configuration.

3. **Command-Line Interface (`improved_test_api.py`)** - User-friendly CLI tool for interacting with the API.

## Installation

### Prerequisites

- Python 3.7 or higher
- Connected Android devices with ADB access
- Required Python packages: `fastapi`, `uvicorn`, `pydantic`, `requests`

### Installation Steps

1. Use the provided installation script:

```bash
bash install_improved_api.sh
```

Or install manually:

```bash
# Install required packages
pip install fastapi uvicorn pydantic requests

# Make scripts executable
chmod +x unified_command_api.py improved_settings_api.py improved_test_api.py
```

## Getting Started

### Starting the API Server

```bash
python3 improved_settings_api.py
```

The server will start on port 8000 by default.

### Listing Connected Devices

```bash
python3 improved_test_api.py list
```

## Command-Line Usage

### Basic URL Setting

```bash
python3 improved_test_api.py set-url --url "https://example.com" --devices DEVICE_ID
```

### Setting URL on All Devices

```bash
python3 improved_test_api.py set-url --url "https://example.com" --all-devices
```

### Setting URL with Custom Parameters

```bash
python3 improved_test_api.py set-url --url "https://example.com" \
  --devices DEVICE_ID \
  --iterations 500 \
  --min-interval 2 \
  --max-interval 5 \
  --webview-mode \
  --new-webview-per-request \
  --rotate-ip
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--url` | Target URL to load | (Required) |
| `--devices` | Specific device IDs (space-separated) | None |
| `--all-devices` | Target all connected devices | False |
| `--iterations` | Number of iterations to run | 1000 |
| `--min-interval` | Minimum interval between requests (seconds) | 1 |
| `--max-interval` | Maximum interval between requests (seconds) | 2 |
| `--webview-mode` | Use webview mode | True |
| `--no-webview-mode` | Disable webview mode | False |
| `--rotate-ip` | Rotate IP between requests | True |
| `--no-rotate-ip` | Disable IP rotation | False |
| `--random-devices` | Use random device profiles | True |
| `--no-random-devices` | Disable random device profiles | False |
| `--new-webview-per-request` | Create new webview for each request | True |
| `--no-new-webview-per-request` | Disable new webview per request | False |
| `--restore-on-exit` | Restore IP on exit | False |
| `--use-proxy` | Use proxy for connections | False |
| `--proxy-address` | Proxy server address | "" |
| `--proxy-port` | Proxy server port | 0 |
| `--parallel` | Process devices in parallel | True |
| `--sequential` | Process devices sequentially | False |

## REST API Reference

### Base URL

```
http://localhost:8000
```

### Endpoints

#### GET /devices
Lists all connected devices.

**Response:**
```json
{
  "devices": [
    {
      "id": "DEVICE_ID",
      "status": "connected",
      "model": "Device Model"
    }
  ],
  "count": 1
}
```

#### POST /set-url
Sets URL on specified devices with maximum reliability.

**Request Body:**
```json
{
  "url": "https://example.com",
  "devices": ["DEVICE_ID"],  // Optional - use either devices or all_devices
  "all_devices": false,      // Optional
  "iterations": 1000,        // Optional
  "min_interval": 1,         // Optional
  "max_interval": 2,         // Optional
  "webview_mode": true,      // Optional
  "rotate_ip": true,         // Optional
  "random_devices": true,    // Optional
  "new_webview_per_request": true, // Optional
  "parallel": true           // Optional
}
```

**Response:**
```json
{
  "status": "success",
  "devices": ["DEVICE_ID"],
  "count": 1,
  "success_count": 1,
  "results": {
    "DEVICE_ID": {
      "status": "success",
      "message": "URL set successfully",
      "details": {
        "app_running": true
      }
    }
  }
}
```

#### POST /apply-settings
Comprehensive endpoint for applying all settings to devices.

**Request Body:**
```json
{
  "settings": {
    "url": "https://example.com",
    "iterations": 1000,
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
  "devices": ["DEVICE_ID"],
  "all_devices": false,
  "parallel": true
}
```

**Response:**
Same format as `/set-url`

#### POST /instagram-settings
Backward compatibility endpoint for Instagram-specific URLs.

**Request Body:**
```json
{
  "url": "https://instagram.com/profile/example",
  "devices": ["DEVICE_ID"],
  "all_devices": false,
  "parallel": true
}
```

**Response:**
Same format as `/set-url`

## Working with Complex URLs

The API is designed to handle complex URLs reliably, especially Instagram redirect URLs that contain tracking parameters. For complex URLs:

1. Always use the full URL, including all parameters
2. The API automatically handles URL encoding where needed
3. For best results with very complex URLs, use the preference file modification method which has been optimized for complex strings

### Example of Setting a Complex Instagram URL

Using the command-line tool:

```bash
python3 improved_test_api.py set-url --url "https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fpath%3Fparam1%3Dvalue1&e=AT0abcdef123456789" --all-devices
```

Using curl with the REST API:

```bash
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://l.instagram.com/?u=https%3A%2F%2Fexample.com%2Fpath%3Fparam1%3Dvalue1&e=AT0abcdef123456789",
    "all_devices": true,
    "webview_mode": true,
    "new_webview_per_request": true
  }'
```

## Troubleshooting

### Common Issues

#### Device Not Found

**Problem:** Device is not showing up in the device list.

**Solution:**
- Ensure the device is connected via USB
- Check that USB debugging is enabled on the device
- Run `adb devices -l` to verify ADB recognizes the device
- Restart ADB server: `adb kill-server && adb start-server`

#### URL Setting Fails

**Problem:** URL is not being set properly on the device.

**Solutions:**
- Check device logs: `adb -s DEVICE_ID logcat | grep com.example.imtbf`
- Verify the app is installed: `adb -s DEVICE_ID shell pm list packages | grep com.example.imtbf`
- Manually stop the app before trying again: `adb -s DEVICE_ID shell am force-stop com.example.imtbf.debug`
- For very complex URLs, try URL encoding any special characters

#### Server Fails to Start

**Problem:** The API server doesn't start.

**Solutions:**
- Check if another service is using port 8000
- Verify Python version is 3.7+
- Install required packages: `pip install fastapi uvicorn pydantic requests`

### Verification Status

The API verifies URL setting was successful by checking:
1. App is running
2. URL is correctly set in preferences
3. App status via broadcast command

If verification fails but the URL was set, the API will report "URL set but verification failed". This typically means the URL is set correctly but the verification couldn't be completed, often due to:
- Complex URLs being truncated in logs
- Missing permissions for direct preference access
- App not responding to status broadcasts within timeout

## Monitoring and Logging

### Log Files

All logs are stored in the `logs` directory:

- `unified_command.log` - Detailed logs from the command API
- `improved_settings_api.log` - API server logs

### Viewing Logs

To view the latest logs:

```bash
tail -f logs/unified_command.log
```

### Log Structure

Logs include:
- Timestamp
- Log level
- Component name
- Detailed message
- Error information when applicable

## Migration from Legacy API

See the `MIGRATION_GUIDE.md` document for detailed instructions on migrating from the legacy API to the improved API.

Key points:
- The improved API maintains backward compatibility with existing endpoints
- New features are available through enhanced endpoints
- Original script parameters are still supported
- The same response format is maintained where possible 