#!/bin/bash

# force_insta_sim.sh
# This script forces the Instagram traffic simulation on a device
# using an aggressive approach to ensure settings are applied correctly.

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
INSTAGRAM_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

echo "Aggressive Step 1: Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop com.example.imtbf.debug"
adb -s $DEVICE_ID shell "am kill com.example.imtbf.debug"

echo "Aggressive Step 2: Remove existing preferences file"
adb -s $DEVICE_ID shell "su -c 'rm -f /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 3: Creating preferences file"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cat > temp_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="true" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$TIMESTAMP</string>
    <string name="target_url">$INSTAGRAM_URL</string>
    <int name="delay_max" value="5" />
    <boolean name="is_first_run" value="false" />
    <int name="airplane_mode_delay" value="3000" />
    <int name="iterations" value="900" />
    <boolean name="is_running" value="false" />
    <boolean name="config_expanded" value="true" />
    <int name="min_interval" value="1" />
    <int name="delay_min" value="1" />
    <int name="max_interval" value="2" />
    <boolean name="rotate_ip" value="true" />
    <boolean name="use_random_device_profile" value="true" />
    <boolean name="new_webview_per_request" value="true" />
</map>
EOL

echo "Aggressive Step 4: Pushing preferences file to device"
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

echo "Aggressive Step 5: Creating shared_prefs directory and setting permissions"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/com.example.imtbf.debug/shared_prefs && chmod 771 /data/data/com.example.imtbf.debug/shared_prefs'"

echo "Aggressive Step 6: Injecting preferences file to app's data directory"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 7: Starting app"
adb -s $DEVICE_ID shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity"

echo "Aggressive Step 8: Waiting for app to initialize (2 seconds)"
sleep 2

echo "Aggressive Step 9: Force overwriting preferences file again after app has started"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 10: Waiting 1 more second for UI to update"
sleep 1

echo "Aggressive Step 11: Last check - are settings correct?"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'" | grep -q "use_webview_mode.*true"
if [ $? -ne 0 ]; then
  echo "CRITICAL WARNING: Preferences still being overwritten by app. Using most extreme approach!"
  
  # Extreme approach - modify app directly using monkey tester to click UI elements
  echo "Aggressive Step 12: Forcing app to use WebView mode through UI automation"
  # Use content provider to force settings
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:use_webview_mode --bind value:b:1'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:new_webview_per_request --bind value:b:1'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:target_url --bind value:s:$INSTAGRAM_URL'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:iterations --bind value:i:900'"
  
  # Last direct modification attempt
  adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
else
  echo "Success! Preferences set correctly"
fi

echo "Aggressive Step 13: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"

echo "Aggressive Step 14: Final check - Verifying if simulation is running"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 15: Force toggling settings to ensure they apply"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_webview_mode --es value true -p com.example.imtbf.debug"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_new_webview_per_request --es value true -p com.example.imtbf.debug"

echo "Done! Simulation should now be running with correct settings."

# Clean up
rm -f temp_prefs.xml 

# force_insta_sim.sh
# This script forces the Instagram traffic simulation on a device
# using an aggressive approach to ensure settings are applied correctly.

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
INSTAGRAM_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

echo "Aggressive Step 1: Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop com.example.imtbf.debug"
adb -s $DEVICE_ID shell "am kill com.example.imtbf.debug"

echo "Aggressive Step 2: Remove existing preferences file"
adb -s $DEVICE_ID shell "su -c 'rm -f /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 3: Creating preferences file"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cat > temp_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="true" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$TIMESTAMP</string>
    <string name="target_url">$INSTAGRAM_URL</string>
    <int name="delay_max" value="5" />
    <boolean name="is_first_run" value="false" />
    <int name="airplane_mode_delay" value="3000" />
    <int name="iterations" value="900" />
    <boolean name="is_running" value="false" />
    <boolean name="config_expanded" value="true" />
    <int name="min_interval" value="1" />
    <int name="delay_min" value="1" />
    <int name="max_interval" value="2" />
    <boolean name="rotate_ip" value="true" />
    <boolean name="use_random_device_profile" value="true" />
    <boolean name="new_webview_per_request" value="true" />
</map>
EOL

echo "Aggressive Step 4: Pushing preferences file to device"
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

echo "Aggressive Step 5: Creating shared_prefs directory and setting permissions"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/com.example.imtbf.debug/shared_prefs && chmod 771 /data/data/com.example.imtbf.debug/shared_prefs'"

echo "Aggressive Step 6: Injecting preferences file to app's data directory"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 7: Starting app"
adb -s $DEVICE_ID shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity"

echo "Aggressive Step 8: Waiting for app to initialize (2 seconds)"
sleep 2

echo "Aggressive Step 9: Force overwriting preferences file again after app has started"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 10: Waiting 1 more second for UI to update"
sleep 1

echo "Aggressive Step 11: Last check - are settings correct?"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'" | grep -q "use_webview_mode.*true"
if [ $? -ne 0 ]; then
  echo "CRITICAL WARNING: Preferences still being overwritten by app. Using most extreme approach!"
  
  # Extreme approach - modify app directly using monkey tester to click UI elements
  echo "Aggressive Step 12: Forcing app to use WebView mode through UI automation"
  # Use content provider to force settings
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:use_webview_mode --bind value:b:1'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:new_webview_per_request --bind value:b:1'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:target_url --bind value:s:$INSTAGRAM_URL'"
  adb -s $DEVICE_ID shell "su -c 'content insert --uri content://com.example.imtbf.debug.provider/settings --bind name:s:iterations --bind value:i:900'"
  
  # Last direct modification attempt
  adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
else
  echo "Success! Preferences set correctly"
fi

echo "Aggressive Step 13: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"

echo "Aggressive Step 14: Final check - Verifying if simulation is running"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Aggressive Step 15: Force toggling settings to ensure they apply"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_webview_mode --es value true -p com.example.imtbf.debug"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command toggle_new_webview_per_request --es value true -p com.example.imtbf.debug"

echo "Done! Simulation should now be running with correct settings."

# Clean up
rm -f temp_prefs.xml 