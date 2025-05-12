#!/bin/bash
# Force UI Update script
# This script will simulate UI actions to reload settings

PACKAGE="com.example.imtbf.debug"
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

# Set the new values
echo "Setting new iteration value to 999..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_iterations --ei value 999

echo "Setting min interval to 3..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_min_interval --ei value 3

echo "Setting max interval to 15..."
adb shell am broadcast -a $BROADCAST_ACTION --es command set_max_interval --ei value 15

# Save current configuration
echo "Saving configuration..."
adb shell am broadcast -a $BROADCAST_ACTION --es command export_config --es name "force_update" --es desc "Force UI Update"

# Force restart the app
echo "Force stopping app..."
adb shell am force-stop $PACKAGE
sleep 2

# Start app again
echo "Restarting app..."
adb shell am start -n $PACKAGE/$ACTIVITY
sleep 3

# Import the config to force UI refresh
echo "Importing configuration to force UI refresh..."
adb shell am broadcast -a $BROADCAST_ACTION --es command import_config --es name "force_update.json"

echo "Done! The UI should now show the updated values." 