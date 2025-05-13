#!/bin/bash
# Run Instagram URL Persistence Tests
# This script runs comprehensive tests for Instagram URL persistence across app restarts

# Change to the server directory
cd "$(dirname "$0")/.." || exit 1

# Check if Python environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Activating Python virtual environment..."
    if [ -d "venv" ]; then
        source venv/bin/activate
    else
        echo "Warning: No virtual environment found. Using system Python."
    fi
fi

# Check for connected devices
devices=$(adb devices | grep -v "List" | grep "device$" | cut -f1)
if [ -z "$devices" ]; then
    echo "Error: No devices connected. Please connect an Android device."
    exit 1
fi

echo "Available devices:"
i=1
for device in $devices; do
    model=$(adb -s "$device" shell getprop ro.product.model | tr -d '\r\n')
    echo "$i. $device ($model)"
    i=$((i+1))
done

# Check if a specific device was provided
if [ -n "$1" ]; then
    device_id="$1"
    if ! echo "$devices" | grep -q "$device_id"; then
        echo "Error: Device $device_id not found."
        exit 1
    fi
    echo "Using specified device: $device_id"
    python3 tools/instagram_url_test.py "$device_id"
else
    # If no device specified and only one connected, use it automatically
    if [ "$(echo "$devices" | wc -l)" -eq 1 ]; then
        device_id=$(echo "$devices" | tr -d '\r\n')
        echo "Automatically using the only connected device: $device_id"
        python3 tools/instagram_url_test.py "$device_id"
    else
        # Ask user to select a device
        echo "Multiple devices found. Please specify a device ID as argument."
        echo "Usage: $0 [device_id]"
        exit 1
    fi
fi 