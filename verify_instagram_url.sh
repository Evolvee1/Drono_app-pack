#!/bin/bash

# verify_instagram_url.sh - Directly verify and set the Instagram URL on a device
# with detailed debugging information

if [ $# -lt 2 ]; then
  echo "Usage: $0 <device_id> <url>"
  exit 1
fi

DEVICE_ID="$1"
TARGET_URL="$2"
PACKAGE="com.example.imtbf.debug"

# Echo with timestamp
function log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting verification for device $DEVICE_ID"

# Check if device is connected
if ! adb -s $DEVICE_ID get-state > /dev/null 2>&1; then
  log "ERROR: Device $DEVICE_ID is not connected"
  exit 1
fi

log "Device $DEVICE_ID is connected"

# Kill app first to start fresh
log "Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop $PACKAGE"
sleep 2

# Try to read existing preferences
log "Checking existing preferences"
PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)

if [ -n "$PREFS" ]; then
  log "Found existing preferences:"
  echo "$PREFS"
else
  log "No existing preferences found"
fi

# Create a complete preferences XML with the target URL
log "Creating new preferences with URL: $TARGET_URL"
PREFS_XML="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name=\"target_url\">$TARGET_URL</string>
    <int name=\"iterations\" value=\"900\" />
    <int name=\"min_interval\" value=\"1\" />
    <int name=\"max_interval\" value=\"2\" />
    <boolean name=\"use_webview_mode\" value=\"true\" />
    <boolean name=\"rotate_ip\" value=\"true\" />
    <boolean name=\"use_random_device_profile\" value=\"true\" />
    <boolean name=\"new_webview_per_request\" value=\"true\" />
    <boolean name=\"restore_on_exit\" value=\"false\" />
    <boolean name=\"use_proxy\" value=\"false\" />
    <string name=\"proxy_address\"></string>
    <int name=\"proxy_port\" value=\"0\" />
    <boolean name=\"is_running\" value=\"false\" />
    <long name=\"last_update_time\" value=\"$(date +%s%3N)\" />
    <string name=\"device_id\">$(date +%s)-$DEVICE_ID</string>
    <string name=\"current_session_id\">$(date +%Y%m%d_%H%M%S)</string>
</map>"

# Save the preferences to a temporary file
log "Saving preferences to temporary file"
echo "$PREFS_XML" > temp_prefs_$DEVICE_ID.xml
adb -s $DEVICE_ID push temp_prefs_$DEVICE_ID.xml /sdcard/temp_prefs.xml

# Create URL config file
log "Creating URL config file"
URL_CONFIG="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name=\"instagram_url\">$TARGET_URL</string>
    <string name=\"url_source\">external</string>
    <long name=\"url_timestamp\">$(date +%s%3N)</long>
</map>"

echo "$URL_CONFIG" > url_config_$DEVICE_ID.xml
adb -s $DEVICE_ID push url_config_$DEVICE_ID.xml /sdcard/url_config.xml

# Try to copy to all possible preferences locations
log "Copying preferences to app's shared_prefs directory"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/$PACKAGE/shared_prefs'" || true
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 666 /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" || \
adb -s $DEVICE_ID shell "cp /sdcard/temp_prefs.xml /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

adb -s $DEVICE_ID shell "su -c 'cp /sdcard/url_config.xml /data/data/$PACKAGE/shared_prefs/url_config.xml && chmod 666 /data/data/$PACKAGE/shared_prefs/url_config.xml'" || \
adb -s $DEVICE_ID shell "cp /sdcard/url_config.xml /data/data/$PACKAGE/shared_prefs/url_config.xml"

# Verify that the files were copied
log "Verifying preferences were copied"
COPIED_PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)

if [ -n "$COPIED_PREFS" ]; then
  log "SUCCESS: Preferences were copied successfully"
  echo "$COPIED_PREFS" | grep -i "target_url"
else
  log "WARNING: Could not verify that preferences were copied"
fi

COPIED_URL=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/url_config.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/url_config.xml" 2>/dev/null)

if [ -n "$COPIED_URL" ]; then
  log "SUCCESS: URL config was copied successfully"
  echo "$COPIED_URL" | grep -i "instagram_url"
else
  log "WARNING: Could not verify that URL config was copied"
fi

# Start app with URL parameter through a deep link
log "Starting app with Instagram URL deep link"
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d 'traffic-sim://instagram?url=$TARGET_URL&force=true'"
sleep 3

# Send URL via broadcast
log "Sending URL via broadcast"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es url \"$TARGET_URL\" -p $PACKAGE"
sleep 1

# Set additional options via broadcast
log "Setting additional options via broadcast"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key rotate_ip --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_random_device_profile --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value false -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key iterations --ei value 900 -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key min_interval --ei value 1 -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key max_interval --ei value 2 -p $PACKAGE"
sleep 1

# Start simulation
log "Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p $PACKAGE"
sleep 1

# Check app logs for confirmation
log "Checking app logs for URL loading"
adb -s $DEVICE_ID logcat -d | grep -i "$PACKAGE.*URL" | tail -n 10

# Verify app is running
if adb -s $DEVICE_ID shell "ps | grep $PACKAGE" | grep -q "$PACKAGE"; then
  log "SUCCESS: App is running"
else
  log "WARNING: App may not be running"
fi

# Verify current status in preferences file
log "Final preferences status:"
FINAL_PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)

if [ -n "$FINAL_PREFS" ]; then
  echo "$FINAL_PREFS"
else
  log "WARNING: Could not read final preferences"
fi

# Try to get status via broadcast
log "Requesting status via broadcast"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p $PACKAGE"

# Clean up
rm -f temp_prefs_$DEVICE_ID.xml url_config_$DEVICE_ID.xml

log "Verification complete for device $DEVICE_ID" 