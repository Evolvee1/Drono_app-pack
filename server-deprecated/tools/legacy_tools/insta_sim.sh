#!/bin/bash

# insta_sim.sh - Robust Instagram Simulation Script
# Script to set up and run Instagram traffic simulations on Android devices
# Handles complex Instagram URLs with special characters and ensures proper configuration

set -e  # Exit on error

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "ERROR: Device ID is required"
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTAGRAM_URL_FILE="${SCRIPT_DIR}/instagram_url.txt"

# Make sure the URL file exists
if [ ! -f "$INSTAGRAM_URL_FILE" ]; then
  echo "ERROR: Instagram URL file not found at $INSTAGRAM_URL_FILE"
  echo "Please create this file with your target URL before running the script"
  exit 1
fi

# Read the URL from the file without any processing
INSTAGRAM_URL=$(cat "$INSTAGRAM_URL_FILE")
echo "Using URL: $INSTAGRAM_URL"

# Default settings
PACKAGE="com.example.imtbf.debug"
PREFS_DIR="/data/data/$PACKAGE/shared_prefs"
PREFS_FILE="$PREFS_DIR/instagram_traffic_simulator_prefs.xml"
CONFIG_FILE="$PREFS_DIR/url_config.xml"
ITERATIONS=900
MIN_INTERVAL=1
MAX_INTERVAL=2
DELAY=3000
USE_WEBVIEW=true
ROTATE_IP=true
RANDOM_DEVICES=true
NEW_WEBVIEW=true

echo "Step 1: Verifying device connection"
if ! adb -s $DEVICE_ID get-state >/dev/null 2>&1; then
  echo "ERROR: Device $DEVICE_ID is not connected or authorized"
  exit 1
fi

echo "Step 2: Killing any running app instance"
adb -s $DEVICE_ID shell "am force-stop $PACKAGE" || echo "No running app to stop"
adb -s $DEVICE_ID shell "am kill $PACKAGE" || echo "No app to kill"
sleep 1

echo "Step 3: Cleaning up any existing preferences"
adb -s $DEVICE_ID shell "su -c 'rm -f $PREFS_FILE'" || echo "Could not remove existing preferences (may not exist)"
adb -s $DEVICE_ID shell "su -c 'rm -f $CONFIG_FILE'" || echo "Could not remove existing config (may not exist)"

echo "Step 4: Creating special URL config file"
# Properly escape the URL for XML
XML_URL=$(echo "$INSTAGRAM_URL" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

# Create a separate URL config file
cat > url_config.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="instagram_url">$XML_URL</string>
    <string name="url_source">external</string>
    <long name="url_timestamp">$(date +%s%3N)</long>
</map>
EOL

# Create main preferences file
cat > main_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="$USE_WEBVIEW" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$(date +%Y%m%d_%H%M%S)</string>
    <string name="target_url">$XML_URL</string>
    <int name="iterations" value="$ITERATIONS" />
    <boolean name="is_running" value="false" />
    <int name="min_interval" value="$MIN_INTERVAL" />
    <int name="max_interval" value="$MAX_INTERVAL" />
    <boolean name="rotate_ip" value="$ROTATE_IP" />
    <boolean name="use_random_device_profile" value="$RANDOM_DEVICES" />
    <boolean name="new_webview_per_request" value="$NEW_WEBVIEW" />
</map>
EOL

echo "Step 5: Pushing files to device"
# Make sure directory exists first
adb -s $DEVICE_ID shell "su -c 'mkdir -p $PREFS_DIR && chmod 771 $PREFS_DIR'" || {
  echo "ERROR: Failed to create preferences directory"
  echo "Make sure the device is rooted and su command is working"
  exit 1
}

# Push files to temporary location
adb -s $DEVICE_ID push url_config.xml /sdcard/url_config.xml || {
  echo "ERROR: Failed to push URL config file to device"
  exit 1
}
adb -s $DEVICE_ID push main_prefs.xml /sdcard/main_prefs.xml || {
  echo "ERROR: Failed to push main preferences file to device"
  exit 1
}

echo "Step 6: Installing preferences files"
# Copy files to app's directory 
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/url_config.xml $CONFIG_FILE && cp /sdcard/main_prefs.xml $PREFS_FILE'" || {
  echo "ERROR: Failed to copy preference files to app directory"
  exit 1
}

# Fix permissions - try multiple approaches
echo "Setting permissions..."
adb -s $DEVICE_ID shell "su -c 'chmod 660 $CONFIG_FILE $PREFS_FILE'"
# Try multiple user/group combinations since these can vary by device
adb -s $DEVICE_ID shell "su -c 'chown 10245:10245 $CONFIG_FILE $PREFS_FILE || chown u0_a245:u0_a245 $CONFIG_FILE $PREFS_FILE || chown 1000:1000 $CONFIG_FILE $PREFS_FILE || true'"

echo "Step 7: Verifying files were created correctly"
CONFIG_CHECK=$(adb -s $DEVICE_ID shell "su -c 'ls -la $CONFIG_FILE'" 2>&1)
PREFS_CHECK=$(adb -s $DEVICE_ID shell "su -c 'ls -la $PREFS_FILE'" 2>&1)

if [[ "$CONFIG_CHECK" == *"No such file"* ]]; then
  echo "ERROR: URL config file was not created properly"
  exit 1
fi

if [[ "$PREFS_CHECK" == *"No such file"* ]]; then
  echo "ERROR: Preferences file was not created properly"
  exit 1
fi

echo "URL Config file: $CONFIG_CHECK"
echo "Main Prefs file: $PREFS_CHECK"

echo "Step 8: Starting app with 'preload URL' action"
# Use deep link specifically for loading URLs
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d 'traffic-sim://load_url?source=external'" || {
  echo "ERROR: Failed to start the app"
  exit 1
}
sleep 3

echo "Step 9: Forcing URL reload via broadcast"
# Use broadcast commands to ensure URL is loaded
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command reload_url -p $PACKAGE" || {
  echo "WARNING: Failed to send reload URL broadcast"
}
sleep 1

echo "Step 10: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE" || {
  echo "ERROR: Failed to start simulation"
  exit 1
}
sleep 1

echo "Step 11: Verifying URL was set correctly"
FINAL_PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat $PREFS_FILE'")
echo "----- Current preferences content -----"
echo "$FINAL_PREFS"
echo "--------------------------------------"

# Extract URL value
URL_VALUE=$(echo "$FINAL_PREFS" | grep -o '<string name="target_url">.*</string>' | sed 's/<string name="target_url">\(.*\)<\/string>/\1/')

if [ "$URL_VALUE" == "https://example.com" ]; then
  echo "⚠️ WARNING: App is still using the default URL (https://example.com)"
  echo "This indicates the app is overriding our settings."
  echo "Try editing the app code to respect external URL settings."
else
  echo "✅ SUCCESS: URL appears to be set correctly:"
  echo "$URL_VALUE"
fi

# Clean up
rm -f url_config.xml main_prefs.xml 2>/dev/null || true

echo "Done! Instagram simulation should now be running."
echo "Check the device to confirm the correct URL is being used." 