#!/bin/bash

# direct_url_command.sh - Absolute minimal approach to set a URL and start the simulator
# This script uses the most direct method possible

if [ $# -lt 2 ]; then
  echo "Usage: $0 <device_id> <url> [iterations] [min_interval] [max_interval] [webview_mode] [rotate_ip] [random_devices] [new_webview_per_request] [restore_on_exit] [use_proxy] [proxy_address] [proxy_port]"
  echo "Default: iterations=1000, min_interval=1, max_interval=2, all boolean options=true except restore_on_exit=false"
  exit 1
fi

DEVICE_ID="$1"
TARGET_URL="$2"
ITERATIONS="${3:-1000}"
MIN_INTERVAL="${4:-1}"
MAX_INTERVAL="${5:-2}"
WEBVIEW_MODE="${6:-true}"
ROTATE_IP="${7:-true}"
RANDOM_DEVICES="${8:-true}"
NEW_WEBVIEW_PER_REQUEST="${9:-true}"
RESTORE_ON_EXIT="${10:-false}"
USE_PROXY="${11:-false}"
PROXY_ADDRESS="${12:-}"
PROXY_PORT="${13:-0}"
PACKAGE="com.example.imtbf.debug"

# Verify device connection
if ! adb -s $DEVICE_ID get-state > /dev/null 2>&1; then
  echo "ERROR: Device $DEVICE_ID is not connected"
  exit 1
fi

# Kill app first
adb -s $DEVICE_ID shell "am force-stop $PACKAGE"
sleep 2

# Create a complete preferences XML with all options
PREFS_XML="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name=\"target_url\">$TARGET_URL</string>
    <int name=\"iterations\" value=\"$ITERATIONS\" />
    <int name=\"min_interval\" value=\"$MIN_INTERVAL\" />
    <int name=\"max_interval\" value=\"$MAX_INTERVAL\" />
    <boolean name=\"use_webview_mode\" value=\"$WEBVIEW_MODE\" />
    <boolean name=\"rotate_ip\" value=\"$ROTATE_IP\" />
    <boolean name=\"use_random_device_profile\" value=\"$RANDOM_DEVICES\" />
    <boolean name=\"new_webview_per_request\" value=\"$NEW_WEBVIEW_PER_REQUEST\" />
    <boolean name=\"restore_on_exit\" value=\"$RESTORE_ON_EXIT\" />
    <boolean name=\"use_proxy\" value=\"$USE_PROXY\" />
    <string name=\"proxy_address\">$PROXY_ADDRESS</string>
    <int name=\"proxy_port\" value=\"$PROXY_PORT\" />
    <boolean name=\"is_running\" value=\"false\" />
    <long name=\"last_update_time\" value=\"$(date +%s%3N)\" />
    <string name=\"device_id\">$(date +%s)-$DEVICE_ID</string>
    <string name=\"current_session_id\">$(date +%Y%m%d_%H%M%S)</string>
</map>"

# Push preferences directly to a temporary file
echo "$PREFS_XML" > temp_prefs.xml
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

# Try to copy to all possible preferences locations
echo "Setting up preferences..."
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/$PACKAGE/shared_prefs'" || true
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 666 /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" || \
adb -s $DEVICE_ID shell "cp /sdcard/temp_prefs.xml /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

# Create a URL config file also
URL_CONFIG="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name=\"instagram_url\">$TARGET_URL</string>
    <string name=\"url_source\">external</string>
    <long name=\"url_timestamp\">$(date +%s%3N)</long>
</map>"

echo "$URL_CONFIG" > url_config.xml
adb -s $DEVICE_ID push url_config.xml /sdcard/url_config.xml

adb -s $DEVICE_ID shell "su -c 'cp /sdcard/url_config.xml /data/data/$PACKAGE/shared_prefs/url_config.xml && chmod 666 /data/data/$PACKAGE/shared_prefs/url_config.xml'" || \
adb -s $DEVICE_ID shell "cp /sdcard/url_config.xml /data/data/$PACKAGE/shared_prefs/url_config.xml"

# Start app with URL parameter directly through a deep link
echo "Starting app with URL parameter..."
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d 'traffic-sim://instagram?url=$TARGET_URL&force=true'"
sleep 3

# Send broadcast commands to ensure proper setup
echo "Sending config broadcast..."
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es url \"$TARGET_URL\" -p $PACKAGE"
sleep 1

# Set additional options via broadcast
echo "Setting additional options..."
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value $WEBVIEW_MODE -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key rotate_ip --ez value $ROTATE_IP -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_random_device_profile --ez value $RANDOM_DEVICES -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value $NEW_WEBVIEW_PER_REQUEST -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value $RESTORE_ON_EXIT -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key iterations --ei value $ITERATIONS -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key min_interval --ei value $MIN_INTERVAL -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key max_interval --ei value $MAX_INTERVAL -p $PACKAGE"

# Set proxy options if enabled
if [ "$USE_PROXY" = "true" ]; then
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_proxy --ez value true -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key proxy_address --es value \"$PROXY_ADDRESS\" -p $PACKAGE"
  adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key proxy_port --ei value $PROXY_PORT -p $PACKAGE"
fi
sleep 1

# Start simulation
echo "Starting simulation..."
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE"
sleep 1

# Verify
echo "Checking current status..."
PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
         adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)

echo "$PREFS"

# Check running status
if adb -s $DEVICE_ID shell "ps | grep $PACKAGE" | grep -q "$PACKAGE"; then
  echo "App is running"
else
  echo "Warning: App may not be running"
fi

# Clean up
rm -f temp_prefs.xml url_config.xml

echo "Done! Instagram simulation is running on $DEVICE_ID with the following config:"
echo "URL: $TARGET_URL"
echo "Iterations: $ITERATIONS"
echo "Min Interval: $MIN_INTERVAL"
echo "Max Interval: $MAX_INTERVAL"
echo "Webview mode: $WEBVIEW_MODE"
echo "Rotate IP: $ROTATE_IP"
echo "Random device profiles: $RANDOM_DEVICES"
echo "New webview per request: $NEW_WEBVIEW_PER_REQUEST"
echo "Restore on exit: $RESTORE_ON_EXIT"
if [ "$USE_PROXY" = "true" ]; then
  echo "Using proxy: $PROXY_ADDRESS:$PROXY_PORT"
fi 