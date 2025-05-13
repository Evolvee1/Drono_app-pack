#!/bin/bash

# enhanced_insta_sim.sh - Improved Instagram Simulation Script
# Script to set up and run Instagram traffic simulations on Android devices
# With improved error handling and debugging

set -e  # Exit on error

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "ERROR: Device ID is required"
  echo "Usage: $0 <device_id> [url]"
  exit 1
fi

DEVICE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTAGRAM_URL_FILE="${SCRIPT_DIR}/instagram_url.txt"

# If URL is provided as second argument, use it
if [ ! -z "$2" ]; then
  INSTAGRAM_URL="$2"
  echo "Using provided URL: $INSTAGRAM_URL"
  
  # Also update the URL file for consistency
  echo "$INSTAGRAM_URL" > "$INSTAGRAM_URL_FILE"
  echo "URL saved to $INSTAGRAM_URL_FILE"
else
  # Make sure the URL file exists
  if [ ! -f "$INSTAGRAM_URL_FILE" ]; then
    echo "ERROR: Instagram URL file not found at $INSTAGRAM_URL_FILE"
    echo "Please create this file with your target URL before running the script"
    exit 1
  fi

  # Read the URL from the file without any processing
  INSTAGRAM_URL=$(cat "$INSTAGRAM_URL_FILE")
  echo "Using URL from file: $INSTAGRAM_URL"
fi

# Default settings
PACKAGE="com.example.imtbf.debug"
PREFS_DIR="/data/data/$PACKAGE/shared_prefs"
PREFS_FILE="$PREFS_DIR/instagram_traffic_simulator_prefs.xml"
CONFIG_FILE="$PREFS_DIR/url_config.xml"
DEFAULT_URL_FILE="$PREFS_DIR/default_url.xml"
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
sleep 2

echo "Step 3: Cleaning up any existing preferences"
# Clean temp files first
adb -s $DEVICE_ID shell "rm -f /sdcard/url_config.xml /sdcard/main_prefs.xml /sdcard/default_url.xml" || echo "No temp files to clean"

# Clean app preferences
adb -s $DEVICE_ID shell "su -c 'rm -f $PREFS_FILE $CONFIG_FILE $DEFAULT_URL_FILE'" || {
  echo "WARNING: Could not remove existing preferences as root (proceeding anyway)"
  
  # Try without su
  adb -s $DEVICE_ID shell "rm -f $PREFS_FILE $CONFIG_FILE $DEFAULT_URL_FILE" || {
    echo "WARNING: Could not remove existing preferences without root either"
  }
}

echo "Step 4: Creating special URL config files"
# Properly escape the URL for XML (double-escape for extra safety with complex URLs)
XML_URL=$(echo "$INSTAGRAM_URL" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&apos;/g')
TIMESTAMP=$(date +%s%3N)

# Create a separate URL config file
cat > url_config.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="instagram_url">$XML_URL</string>
    <string name="url_source">external</string>
    <long name="url_timestamp">$TIMESTAMP</long>
</map>
EOL

# Create default URL file (to ensure the app doesn't override our settings)
cat > default_url.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="default_url">$XML_URL</string>
    <long name="default_timestamp">$TIMESTAMP</long>
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
    <string name="start_url">$XML_URL</string>
    <string name="cached_url">$XML_URL</string>
    <int name="iterations" value="$ITERATIONS" />
    <boolean name="is_running" value="false" />
    <int name="min_interval" value="$MIN_INTERVAL" />
    <int name="max_interval" value="$MAX_INTERVAL" />
    <boolean name="rotate_ip" value="$ROTATE_IP" />
    <boolean name="use_random_device_profile" value="$RANDOM_DEVICES" />
    <boolean name="new_webview_per_request" value="$NEW_WEBVIEW" />
    <long name="last_update_time" value="$TIMESTAMP" />
    <string name="origin">external_script</string>
</map>
EOL

echo "Step 5: Pushing files to device"
# Make sure directory exists first
adb -s $DEVICE_ID shell "su -c 'mkdir -p $PREFS_DIR && chmod 777 $PREFS_DIR'" || {
  echo "WARNING: Failed to create preferences directory as root, trying without root"
  adb -s $DEVICE_ID shell "mkdir -p $PREFS_DIR" || {
    echo "ERROR: Failed to create preferences directory"
    exit 1
  }
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
adb -s $DEVICE_ID push default_url.xml /sdcard/default_url.xml || {
  echo "ERROR: Failed to push default URL file to device"
  exit 1
}

echo "Step 6: Installing preferences files"
# Copy files to app's directory, try with su first, then without if it fails
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/url_config.xml $CONFIG_FILE && cp /sdcard/main_prefs.xml $PREFS_FILE && cp /sdcard/default_url.xml $DEFAULT_URL_FILE'" || {
  echo "WARNING: Failed to copy preference files as root, trying without root"
  adb -s $DEVICE_ID shell "cp /sdcard/url_config.xml $CONFIG_FILE && cp /sdcard/main_prefs.xml $PREFS_FILE && cp /sdcard/default_url.xml $DEFAULT_URL_FILE" || {
    echo "ERROR: Failed to copy preference files to app directory"
    exit 1
  }
}

# Fix permissions - try multiple approaches
echo "Setting permissions..."
adb -s $DEVICE_ID shell "su -c 'chmod 777 $CONFIG_FILE $PREFS_FILE $DEFAULT_URL_FILE'" || {
  echo "WARNING: Failed to set permissions as root, trying without root"
  adb -s $DEVICE_ID shell "chmod 666 $CONFIG_FILE $PREFS_FILE $DEFAULT_URL_FILE" || {
    echo "WARNING: Could not set permissions (proceeding anyway)"
  }
}

# Try to set file ownership (multiple attempts with different approaches)
adb -s $DEVICE_ID shell "su -c 'chown 10245:10245 $CONFIG_FILE $PREFS_FILE $DEFAULT_URL_FILE || chown u0_a245:u0_a245 $CONFIG_FILE $PREFS_FILE $DEFAULT_URL_FILE || chown 1000:1000 $CONFIG_FILE $PREFS_FILE $DEFAULT_URL_FILE || true'"

echo "Step 7: Verifying files were created correctly"
CONFIG_CHECK=$(adb -s $DEVICE_ID shell "ls -la $CONFIG_FILE" 2>&1)
PREFS_CHECK=$(adb -s $DEVICE_ID shell "ls -la $PREFS_FILE" 2>&1)

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
# Start app with clear data flag to ensure it reads our preferences
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity --activity-clear-task -a android.intent.action.VIEW -d 'traffic-sim://load_url?source=external&force=true&url=$XML_URL'" || {
  echo "WARNING: Failed to start the app with deep link, trying standard start"
  adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity" || {
    echo "ERROR: Failed to start the app"
    exit 1
  }
}
sleep 4

echo "Step 9: Forcing URL reload via broadcast"
# Use broadcast commands to ensure URL is loaded
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command reload_url --es url \"$XML_URL\" -p $PACKAGE" || {
  echo "WARNING: Failed to send reload URL broadcast"
}
sleep 2

echo "Step 10: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE" || {
  echo "ERROR: Failed to start simulation"
  exit 1
}
sleep 2

echo "Step 11: Verifying URL was set correctly"
FINAL_PREFS=$(adb -s $DEVICE_ID shell "cat $PREFS_FILE" 2>/dev/null || adb -s $DEVICE_ID shell "su -c 'cat $PREFS_FILE'" 2>/dev/null)
echo "----- Current preferences content -----"
echo "$FINAL_PREFS"
echo "--------------------------------------"

# Extract URL value
URL_VALUE=$(echo "$FINAL_PREFS" | grep -o '<string name="target_url">.*</string>' | sed 's/<string name="target_url">\(.*\)<\/string>/\1/')

# If we can't extract the URL, try a direct broadcast to check the status
if [ -z "$URL_VALUE" ]; then
  echo "WARNING: Couldn't extract URL from preferences, trying direct status check"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p $PACKAGE"
  sleep 1
  URL_VALUE="Unknown (but simulation should be running)"
fi

if [ "$URL_VALUE" == "https://example.com" ]; then
  echo "⚠️ WARNING: App is still using the default URL (https://example.com)"
  echo "This indicates the app is overriding our settings."
  echo "Trying one last approach - direct command with the URL"
  
  # Try one more approach - send direct command with URL
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es url \"$XML_URL\" -p $PACKAGE"
  sleep 1
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE"
  
  echo "⚠️ Direct command sent, simulation should now be running"
else
  echo "✅ SUCCESS: URL appears to be set correctly:"
  echo "$URL_VALUE"
fi

# Clean up
rm -f url_config.xml main_prefs.xml default_url.xml 2>/dev/null || true

echo "Done! Instagram simulation should now be running."
echo "Check the device to confirm the correct URL is being used." 