# Practical Examples - Device Settings API

This document provides practical examples of common usage scenarios for the improved Device Settings API, with a focus on handling complex URLs and Instagram redirect links.

## Table of Contents

1. [Basic URL Examples](#basic-url-examples)
2. [Instagram URL Examples](#instagram-url-examples)
3. [Complex URL Handling](#complex-url-handling)
4. [Batch Processing Examples](#batch-processing-examples)
5. [Scheduled Operations](#scheduled-operations)
6. [Logging and Monitoring Examples](#logging-and-monitoring-examples)

## Basic URL Examples

### Setting a Simple URL on a Specific Device

```bash
# Command line interface
python3 improved_test_api.py set-url --url "https://example.com" --devices R38N9014KDM

# REST API via curl
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "devices": ["R38N9014KDM"]
  }'
```

### Setting a URL on All Connected Devices

```bash
# Command line interface
python3 improved_test_api.py set-url --url "https://example.com" --all-devices

# REST API via curl
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "all_devices": true
  }'
```

### Setting a URL with Custom Intervals

```bash
# Command line interface
python3 improved_test_api.py set-url --url "https://example.com" \
  --devices R38N9014KDM \
  --iterations 200 \
  --min-interval 3 \
  --max-interval 7

# REST API via curl
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "devices": ["R38N9014KDM"],
    "iterations": 200,
    "min_interval": 3,
    "max_interval": 7
  }'
```

## Instagram URL Examples

### Setting an Instagram Profile URL

```bash
# Command line interface
python3 improved_test_api.py set-url --url "https://instagram.com/profile/username" --all-devices

# Using the backward-compatible endpoint
curl -X POST http://localhost:8000/instagram-settings \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://instagram.com/profile/username",
    "all_devices": true
  }'
```

### Setting an Instagram Post URL

```bash
python3 improved_test_api.py set-url --url "https://www.instagram.com/p/Cxyz123456/" --devices R38N9014KDM
```

### Setting an Instagram Story URL

```bash
python3 improved_test_api.py set-url --url "https://www.instagram.com/stories/username/1234567890/" --devices R38N9014KDM
```

## Complex URL Handling

### Instagram Redirect URL (Example from Real-World Usage)

```bash
# The extremely long URL with tracking parameters - command line interface
python3 improved_test_api.py set-url --url "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA" \
  --all-devices \
  --webview-mode \
  --new-webview-per-request

# Using REST API with curl (same complex URL)
curl -X POST http://localhost:8000/set-url \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA",
    "all_devices": true,
    "webview_mode": true,
    "new_webview_per_request": true
  }'
```

### URL with Special Characters and Parameters

```bash
# URL with special characters that need encoding
python3 improved_test_api.py set-url --url "https://example.com/search?q=term+with spaces&category=test&special=!@#$%" --devices R38N9014KDM

# Note: The API handles URL encoding automatically
```

### URL with Authentication

```bash
# URL with authentication credentials
python3 improved_test_api.py set-url --url "https://username:password@example.com/secure" --devices R38N9014KDM
```

## Batch Processing Examples

### Processing Multiple Devices Sequentially

```bash
# Process devices one at a time (may be more reliable for some operations)
python3 improved_test_api.py set-url --url "https://example.com" \
  --devices R38N9014KDM R9WR310F4GJ \
  --sequential
```

### Parallel Processing with Custom Settings

```bash
# Process all devices in parallel with custom settings
python3 improved_test_api.py set-url --url "https://example.com" \
  --all-devices \
  --iterations 100 \
  --min-interval 5 \
  --max-interval 10 \
  --webview-mode \
  --new-webview-per-request \
  --random-devices \
  --parallel
```

## Scheduled Operations

### Using Cron to Schedule URL Updates

Create a shell script for the operation:

```bash
#!/bin/bash
# File: update_urls.sh

# Set the path to your API directory
API_DIR="/Users/username/path/to/server/tools"
cd "$API_DIR"

# Set URL on all devices
python3 improved_test_api.py set-url --url "https://example.com/$(date +%Y-%m-%d)" --all-devices
```

Make it executable:

```bash
chmod +x update_urls.sh
```

Add to crontab to run daily at 8 AM:

```bash
0 8 * * * /path/to/update_urls.sh >> /path/to/cron.log 2>&1
```

### Running with Different URLs on a Schedule

Create a script with multiple URLs:

```bash
#!/bin/bash
# File: rotate_urls.sh

API_DIR="/Users/username/path/to/server/tools"
cd "$API_DIR"

# Array of URLs to rotate through
URLS=(
  "https://example.com/page1"
  "https://example.com/page2"
  "https://example.com/page3"
)

# Get the URL based on the day of the week (0-6)
DAY_OF_WEEK=$(date +%u)
INDEX=$((DAY_OF_WEEK % ${#URLS[@]}))
URL=${URLS[$INDEX]}

# Set the URL on all devices
python3 improved_test_api.py set-url --url "$URL" --all-devices
```

## Logging and Monitoring Examples

### Setting Up Extended Logging

```bash
# Monitor the command API logs in real-time
tail -f logs/unified_command.log | grep "R38N9014KDM"

# Monitor the server API logs
tail -f logs/improved_settings_api.log
```

### Creating a Device Status Report

```bash
#!/bin/bash
# File: device_status_report.sh

API_DIR="/Users/username/path/to/server/tools"
cd "$API_DIR"

# Get current date and time
DATE=$(date +"%Y-%m-%d %H:%M:%S")
REPORT_FILE="device_status_report_$(date +%Y%m%d).txt"

echo "Device Status Report - $DATE" > "$REPORT_FILE"
echo "===============================" >> "$REPORT_FILE"

# Get list of devices
DEVICES_JSON=$(curl -s http://localhost:8000/devices)
echo "Connected Devices:" >> "$REPORT_FILE"
echo "$DEVICES_JSON" | python3 -m json.tool >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"
echo "Current Settings:" >> "$REPORT_FILE"

# For each device, check status
for DEVICE_ID in $(echo "$DEVICES_JSON" | python3 -c "import json,sys; print('\n'.join([d['id'] for d in json.load(sys.stdin)['devices']]))"); do
  echo "Device: $DEVICE_ID" >> "$REPORT_FILE"
  
  # Use ADB to get running state
  RUNNING=$(adb -s "$DEVICE_ID" shell pidof com.example.imtbf.debug)
  if [ -n "$RUNNING" ]; then
    echo "  App Status: Running (PID: $RUNNING)" >> "$REPORT_FILE"
  else
    echo "  App Status: Not running" >> "$REPORT_FILE"
  fi
  
  # Additional device info
  echo "  Model: $(adb -s "$DEVICE_ID" shell getprop ro.product.model)" >> "$REPORT_FILE"
  echo "  Android Version: $(adb -s "$DEVICE_ID" shell getprop ro.build.version.release)" >> "$REPORT_FILE"
  
  echo "" >> "$REPORT_FILE"
done

echo "Report generated: $REPORT_FILE"
```

## Best Practices for Complex URLs

When working with complex URLs, especially Instagram redirect links:

1. **Preferences Method is Most Reliable**:
   - The direct preferences modification method is the most reliable for complex URLs
   - The API automatically uses this method first

2. **Verify URL Setting**:
   - Check the app logs to confirm the URL was correctly set
   - Use `adb -s DEVICE_ID logcat | grep "com.example.imtbf"` to view app logs

3. **Handling Verification Failures**:
   - If you see "URL set but verification failed", the URL may still be correctly set
   - This can happen with very long URLs where verification is difficult
   - Check the app manually to confirm

4. **URL Encoding**:
   - The API handles URL encoding automatically
   - Pre-encoded URLs (with %xx characters) will be preserved
   - Non-encoded URLs will be encoded as needed

5. **Special Characters**:
   - When using URLs with special characters in shell commands, use proper quoting:
   ```bash
   python3 improved_test_api.py set-url --url "https://example.com/path?param=value&other=test" --all-devices
   ``` 