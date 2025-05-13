#!/bin/bash

# fix_instagram_settings.sh - Update settings for Instagram traffic simulation
# This script only fixes the settings without changing the URL

# Check if device ID is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
PACKAGE="com.example.imtbf.debug"

# Echo with timestamp
function log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Fixing Instagram traffic simulation settings for device $DEVICE_ID"

# Check if device is connected
if ! adb -s $DEVICE_ID get-state > /dev/null 2>&1; then
  log "ERROR: Device $DEVICE_ID is not connected"
  exit 1
fi

log "Device $DEVICE_ID is connected"

# Kill app first
log "Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop $PACKAGE"
sleep 2

# Create settings XML with correct values
log "Creating new settings XML"
SETTINGS_XML="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name=\"use_webview_mode\" value=\"true\" />
    <boolean name=\"new_webview_per_request\" value=\"true\" />
    <boolean name=\"restore_on_exit\" value=\"false\" />
    <boolean name=\"rotate_ip\" value=\"true\" />
    <boolean name=\"use_random_device_profile\" value=\"true\" />
    <int name=\"iterations\" value=\"900\" />
    <int name=\"min_interval\" value=\"1\" />
    <int name=\"max_interval\" value=\"2\" />
    <long name=\"last_update_time\" value=\"$(date +%s%3N)\" />
</map>"

# Save the settings to a temporary file
log "Saving settings to temporary file"
echo "$SETTINGS_XML" > temp_settings_$DEVICE_ID.xml
adb -s $DEVICE_ID push temp_settings_$DEVICE_ID.xml /sdcard/temp_settings.xml

# Try to copy to preferences location
log "Copying settings to app's shared_prefs directory"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/$PACKAGE/shared_prefs'" || true

# Don't overwrite the entire file, instead use the broadcast method to update individual settings
log "Setting key preferences via broadcast intents"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value false -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key rotate_ip --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_random_device_profile --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key iterations --ei value 900 -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key min_interval --ei value 1 -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key max_interval --ei value 2 -p $PACKAGE"

# Verify settings in preferences file
log "Verifying settings in preferences file"
PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" 2>/dev/null)

if [ -n "$PREFS" ]; then
  log "Current preferences after update:"
  echo "$PREFS"
  
  # Check if key settings are correct
  if echo "$PREFS" | grep -q 'name="use_webview_mode" value="true"' && \
     echo "$PREFS" | grep -q 'name="new_webview_per_request" value="true"' && \
     echo "$PREFS" | grep -q 'name="restore_on_exit" value="false"'; then
    log "SUCCESS: Key settings have been verified"
  else
    log "WARNING: Some key settings may not be correctly set"
  fi
else
  log "WARNING: Could not verify preferences file"
fi

# Get the current URL from the URL config file
URL_CONFIG=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/$PACKAGE/shared_prefs/url_config.xml'" 2>/dev/null || \
  adb -s $DEVICE_ID shell "cat /data/data/$PACKAGE/shared_prefs/url_config.xml" 2>/dev/null)

if [ -n "$URL_CONFIG" ]; then
  log "Current URL configuration:"
  echo "$URL_CONFIG" | grep -i "instagram_url"
else
  log "WARNING: Could not read URL config file"
fi

# Start the app with the current URL
log "Starting app with current URL configuration"
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity"
sleep 2

# Check if app is running
if adb -s $DEVICE_ID shell "ps | grep $PACKAGE" | grep -q "$PACKAGE"; then
  log "SUCCESS: App is running"
else
  log "WARNING: App may not be running"
fi

# Request status
log "Requesting status via broadcast"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p $PACKAGE"

# Clean up
rm -f temp_settings_$DEVICE_ID.xml

log "Settings fix complete for device $DEVICE_ID" 