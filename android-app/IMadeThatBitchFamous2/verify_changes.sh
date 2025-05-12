#!/bin/bash
# Verify Changes Script
# Checks if settings changes via ADB are being applied correctly

# Define package name
PACKAGE="com.example.imtbf2.debug"
BROADCAST_ACTION="com.example.imtbf2.debug.COMMAND"

echo "===== Settings Verification Test ====="
echo "This script will check if setting changes are being applied correctly,"
echo "regardless of whether the UI updates or not."
echo ""

# First check current status
echo "Getting current status..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "Current status shown above."
sleep 2

# Set iterations to a new value
NEW_ITERATIONS=175
echo "Setting iterations to $NEW_ITERATIONS..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_iterations --ei value $NEW_ITERATIONS
sleep 1

# Check if the change worked
echo "Checking if change was applied..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "New status shown above. Iterations should be $NEW_ITERATIONS."
sleep 2

# Set min interval to a new value
NEW_MIN_INTERVAL=7
echo "Setting min interval to $NEW_MIN_INTERVAL..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_min_interval --ei value $NEW_MIN_INTERVAL
sleep 1

# Check if the change worked
echo "Checking if change was applied..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "New status shown above. Min Interval should be $NEW_MIN_INTERVAL."
sleep 2

# Now test with config import/export
echo ""
echo "===== Testing with Config Import/Export ====="
TEMP_CONFIG="verify_test_config"

# Create a config with current settings
echo "Exporting current settings to a config..."
adb shell am broadcast -a $BROADCAST_ACTION --es command export_config --es name "$TEMP_CONFIG" --es desc "Verification Test Config"
sleep 1

# Change settings
echo "Changing settings to test values..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_iterations --ei value 250
adb shell am broadcast -a $BROADCAST_ACTION --es command set_min_interval --ei value 10
adb shell am broadcast -a $BROADCAST_ACTION --es command set_max_interval --ei value 30
sleep 1

# Check the changes
echo "Checking new values..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "Changed values shown above. Iterations should be 250, Min Interval 10, Max Interval 30."
sleep 2

# Import the original config
echo "Importing previous config to restore settings..."
adb shell am broadcast -a $BROADCAST_ACTION --es command import_config --es name "${TEMP_CONFIG}.json"
sleep 1

# Check if the import worked
echo "Checking if import restored original values..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "Restored values shown above. Iterations should be back to $NEW_ITERATIONS, Min Interval to $NEW_MIN_INTERVAL."
echo ""

echo "===== Test Summary ====="
echo "This test verifies that the settings are being changed correctly in the background,"
echo "even if you don't see them update on the UI."
echo ""
echo "If the values shown in the status match the expected values after each change,"
echo "then the settings are being applied correctly."
echo ""
echo "For UI updates:"
echo "1. Make sure your code changes have been properly built and installed in the app."
echo "2. Try restarting the app after making settings changes."
echo "3. The config import method should always refresh the UI reliably." 