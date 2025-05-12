#!/bin/bash
# Test UI Updates Script
# Tests if UI updates from ADB commands are working

# Define package name
PACKAGE="com.example.imtbf2.debug"
BROADCAST_ACTION="com.example.imtbf2.debug.COMMAND"

echo "===== UI Update Test ====="
echo "1. Make sure your app is visible on the device."
echo "2. Watch the iterations, min_interval, and max_interval fields."
echo "3. The script will change these values and you should see the UI update."
echo ""
echo "Press Enter to start the test..."
read

# First check current status
echo "Getting current status..."
adb shell am broadcast -a $BROADCAST_ACTION --es command get_status
echo ""
echo "Current status should be shown in the app toast or log."
sleep 2

# Set iterations to a new value
NEW_ITERATIONS=175
echo "Setting iterations to $NEW_ITERATIONS..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_iterations --ei value $NEW_ITERATIONS
echo "Did the iterations field in the UI update to $NEW_ITERATIONS? (y/n)"
read iterations_updated

# Set min interval to a new value
NEW_MIN_INTERVAL=7
echo "Setting min interval to $NEW_MIN_INTERVAL..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_min_interval --ei value $NEW_MIN_INTERVAL
echo "Did the min interval field in the UI update to $NEW_MIN_INTERVAL? (y/n)"
read min_interval_updated

# Set max interval to a new value
NEW_MAX_INTERVAL=25
echo "Setting max interval to $NEW_MAX_INTERVAL..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_max_interval --ei value $NEW_MAX_INTERVAL
echo "Did the max interval field in the UI update to $NEW_MAX_INTERVAL? (y/n)"
read max_interval_updated

# Toggle a feature
echo "Toggling rotate_ip feature to OFF..."
adb shell am broadcast -a $BROADCAST_ACTION --es command toggle_feature --es feature "rotate_ip" --ez value false
echo "Did the rotate_ip switch in the UI update to OFF? (y/n)"
read rotate_ip_updated

# Toggle it back
echo "Toggling rotate_ip feature to ON..."
adb shell am broadcast -a $BROADCAST_ACTION --es command toggle_feature --es feature "rotate_ip" --ez value true
echo "Did the rotate_ip switch in the UI update to ON? (y/n)"
read rotate_ip_updated_again

# Now test with config import/export
echo ""
echo "===== Testing with Config Import/Export ====="
TEMP_CONFIG="ui_test_config"

# Create a config with current settings
echo "Exporting current settings to a config..."
adb shell am broadcast -a $BROADCAST_ACTION --es command export_config --es name "$TEMP_CONFIG" --es desc "UI Test Config"
sleep 1

# Change settings
echo "Changing settings to test values..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_iterations --ei value 250
adb shell am broadcast -a $BROADCAST_ACTION --es command set_min_interval --ei value 10
adb shell am broadcast -a $BROADCAST_ACTION --es command set_max_interval --ei value 30
sleep 1

# Import the original config
echo "Importing previous config to restore settings..."
adb shell am broadcast -a $BROADCAST_ACTION --es command import_config --es name "${TEMP_CONFIG}.json"
echo "Did the UI update to the original values? (y/n)"
read config_import_worked

echo ""
echo "===== Test Results ====="
echo "1. Direct settings update:"
echo "   - Iterations updated: $iterations_updated"
echo "   - Min interval updated: $min_interval_updated"
echo "   - Max interval updated: $max_interval_updated"
echo "   - Rotate IP toggle OFF: $rotate_ip_updated"
echo "   - Rotate IP toggle ON: $rotate_ip_updated_again"
echo "2. Config import update: $config_import_worked"
echo ""

if [[ "$iterations_updated" == "y" && "$min_interval_updated" == "y" && 
      "$max_interval_updated" == "y" && "$rotate_ip_updated" == "y" && 
      "$rotate_ip_updated_again" == "y" && "$config_import_worked" == "y" ]]; then
    echo "🎉 All tests PASSED! UI updates are working correctly."
else
    echo "❌ Some tests FAILED. UI updates might not be working correctly."
    echo ""
    echo "Recommendations:"
    echo "1. Check that the app is in the foreground during testing."
    echo "2. Try restarting the app and testing again."
    echo "3. Verify that the AdbCommandReceiver is properly registered."
    echo "4. Look for any error messages in logcat."
fi 