#!/bin/bash

# pre_start_settings.sh
# A focused script to reliably apply settings to the app BEFORE starting it
# This avoids the issue of settings being overwritten by the app on start

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id> <url> [options]"
  echo "Options:"
  echo "  --iterations <number>          Number of iterations to run (default: 900)"
  echo "  --min-interval <seconds>       Minimum interval between requests (default: 1)"
  echo "  --max-interval <seconds>       Maximum interval between requests (default: 2)"
  echo "  --delay <milliseconds>         Delay after airplane mode toggle (default: 3000)"
  echo "  --webview <true|false>         Use WebView mode (default: true)"
  echo "  --rotate-ip <true|false>       Toggle airplane mode to rotate IP (default: true)"
  echo "  --random-devices <true|false>  Use random device profiles (default: true)"
  echo "  --new-webview <true|false>     Create new WebView per request (default: true)"
  exit 1
fi

# Function to properly escape XML special characters
escape_xml() {
  local string="$1"
  string="${string//&/&amp;}"
  string="${string//</&lt;}"
  string="${string//>/&gt;}"
  string="${string//\"/&quot;}"
  string="${string//'/&apos;}"
  echo "$string"
}

# Required parameters
DEVICE_ID="$1"
if [ -z "$2" ]; then
  echo "Error: URL is required"
  exit 1
fi
RAW_TARGET_URL="$2"
# Escape the URL for XML
TARGET_URL=$(escape_xml "$RAW_TARGET_URL")
shift 2  # Remove device_id and url from args

# Default settings
ITERATIONS=900
MIN_INTERVAL=1
MAX_INTERVAL=2
DELAY=3000
USE_WEBVIEW=true
ROTATE_IP=true
RANDOM_DEVICES=true
NEW_WEBVIEW=true

# Parse optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --min-interval)
      MIN_INTERVAL="$2"
      shift 2
      ;;
    --max-interval)
      MAX_INTERVAL="$2"
      shift 2
      ;;
    --delay)
      DELAY="$2"
      shift 2
      ;;
    --webview)
      USE_WEBVIEW="$2"
      shift 2
      ;;
    --rotate-ip)
      ROTATE_IP="$2"
      shift 2
      ;;
    --random-devices)
      RANDOM_DEVICES="$2"
      shift 2
      ;;
    --new-webview)
      NEW_WEBVIEW="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Define the package and preferences file
PACKAGE="com.example.imtbf.debug"
PREFS_FILE="/data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

echo "Step 1: Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop $PACKAGE"
adb -s $DEVICE_ID shell "am kill $PACKAGE"
sleep 1

echo "Step 2: Remove existing preferences file"
adb -s $DEVICE_ID shell "su -c 'rm -f $PREFS_FILE'"

echo "Step 3: Creating preferences file"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cat > temp_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="$USE_WEBVIEW" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$TIMESTAMP</string>
    <string name="target_url">$TARGET_URL</string>
    <int name="delay_max" value="5" />
    <boolean name="is_first_run" value="false" />
    <int name="airplane_mode_delay" value="$DELAY" />
    <int name="iterations" value="$ITERATIONS" />
    <boolean name="is_running" value="false" />
    <boolean name="config_expanded" value="true" />
    <int name="min_interval" value="$MIN_INTERVAL" />
    <int name="delay_min" value="1" />
    <int name="max_interval" value="$MAX_INTERVAL" />
    <boolean name="rotate_ip" value="$ROTATE_IP" />
    <boolean name="use_random_device_profile" value="$RANDOM_DEVICES" />
    <boolean name="new_webview_per_request" value="$NEW_WEBVIEW" />
</map>
EOL

echo "Step 4: Pushing preferences file to device"
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

echo "Step 5: Creating shared_prefs directory and setting permissions"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/$PACKAGE/shared_prefs && chmod 771 /data/data/$PACKAGE/shared_prefs'"

echo "Step 6: Injecting preferences file to app's data directory"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml $PREFS_FILE && chmod 660 $PREFS_FILE && chown u0_a245:u0_a245 $PREFS_FILE'"

echo "Step 7: Starting app"
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity"

echo "Step 8: Starting simulation via broadcast"
sleep 2  # Give the app a moment to initialize
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE"

echo "Step 9: Verifying settings were applied"
adb -s $DEVICE_ID shell "su -c 'cat $PREFS_FILE'" | grep -q "use_webview_mode.*$USE_WEBVIEW"
if [ $? -ne 0 ]; then
  echo "Warning: Settings may not have been applied correctly. Using broadcast commands as fallback."
  
  # Use broadcast command fallback (simpler and more reliable than content provider)
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_webview_mode --es value $USE_WEBVIEW -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_new_webview_per_request --es value $NEW_WEBVIEW -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es value '$RAW_TARGET_URL' -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_iterations --ei value $ITERATIONS -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_rotate_ip --es value $ROTATE_IP -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE"
else
  echo "Success! Settings applied correctly."
fi

echo "Done! Simulation should now be running with the following settings:"
echo "  URL: $RAW_TARGET_URL"
echo "  Iterations: $ITERATIONS"
echo "  Interval: $MIN_INTERVAL-$MAX_INTERVAL seconds"
echo "  WebView mode: $USE_WEBVIEW"
echo "  Rotate IP: $ROTATE_IP"
echo "  Random device profiles: $RANDOM_DEVICES"
echo "  New WebView per request: $NEW_WEBVIEW"

# Clean up
rm -f temp_prefs.xml 
 