# Migration Guide: Device Settings API

This document guides you through migrating from the original Settings API to the improved version.

## Overview

The improved Device Settings API offers better reliability, performance, and error handling. This guide will help you transition your codebase to use the new API with minimal disruption.

## Step 1: Install New Files

1. Copy the new files to your server/tools directory:
   - `unified_command_api.py`
   - `improved_settings_api.py`
   - `improved_test_api.py`

2. Ensure Python 3.7+ is installed (required for asyncio features)

3. Install required packages:
   ```bash
   pip install fastapi uvicorn pydantic requests
   ```

## Step 2: Update Your API Server

You have two options:

### Option A: Run Both APIs in Parallel (Recommended)

1. Start the original API server on the default port (8000):
   ```bash
   python settings_api_server.py
   ```

2. Start the improved API server on a different port (e.g., 8001):
   ```bash
   python -c "import improved_settings_api as api; api.app.run(host='0.0.0.0', port=8001)"
   ```

3. Gradually migrate your clients to use the new API

### Option B: Replace Original API

1. Rename the original files for backup:
   ```bash
   mv settings_api_server.py settings_api_server.py.bak
   mv test_settings_api.py test_settings_api.py.bak
   ```

2. Rename the improved files to match the original names:
   ```bash
   cp improved_settings_api.py settings_api_server.py
   cp improved_test_api.py test_settings_api.py
   ```

3. Start the API server as usual:
   ```bash
   python settings_api_server.py
   ```

## Step 3: Update API Clients

### If Using REST API

The improved API maintains compatibility with most of the original endpoints, but with some changes:

| Original Endpoint | New Endpoint | Notes |
|-------------------|--------------|-------|
| `/devices` | `/devices` | Unchanged |
| `/apply-settings` | `/apply-settings` | Enhanced reliability |
| `/instagram-settings` | `/set-url` | Redirected internally for compatibility |
| `/direct-url` | `/set-url` | New unified endpoint |

Example of updated API call:

```javascript
// Original API call
fetch('http://localhost:8000/direct-url', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    url: 'https://example.com',
    devices: deviceIds,
    parallel: true
  })
})

// New API call
fetch('http://localhost:8001/set-url', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    url: 'https://example.com',
    devices: deviceIds,
    parallel: true
  })
})
```

### If Using Command Line Tool

Update your scripts to use the improved test API:

```bash
# Original command
python test_settings_api.py cmd --url "https://example.com" --devices DEVICE_ID

# New command
python improved_test_api.py set-url --url "https://example.com" --devices DEVICE_ID
```

## Step 4: Test and Verify

1. Test the new API with your existing URLs and devices
2. Verify that commands are being executed correctly
3. Check for any issues in the logs

## Response Format Changes

The improved API response format has some minor changes:

```javascript
// Original response
{
  "status": "success",
  "devices": ["emulator-5554"],
  "count": 1,
  "success_count": 1,
  "results": {
    "emulator-5554": {
      "status": "success",
      "details": "Command output text..."
    }
  }
}

// New response
{
  "status": "success",
  "devices": ["emulator-5554"],
  "count": 1,
  "success_count": 1,
  "results": {
    "emulator-5554": {
      "status": "success",
      "message": "URL set successfully",
      "details": {
        "app_running": true
        // Additional details available with verbose mode
      }
    }
  }
}
```

## Troubleshooting

If you encounter issues during migration:

1. Check logs in `server/tools/logs/`
2. Ensure ADB is properly installed and working
3. Verify device connections with `adb devices`
4. Try the commands manually to isolate any problems

For persistent issues, you can always fall back to the original API temporarily while troubleshooting.

## Advanced Features

The new API includes several advanced features:

1. **Direct Preference Modification**: Enhanced reliability for setting complex URLs
2. **Comprehensive Verification**: Verifies settings were applied correctly
3. **Improved Error Reporting**: Detailed error messages
4. **Hybrid Approach**: Combines multiple techniques for maximum reliability 