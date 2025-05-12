#!/bin/bash

# launch_insta_simulation.sh
# This script properly launches the Instagram traffic simulation on a device
# using the correct sequence of steps to ensure settings are applied correctly.

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
INSTAGRAM_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

echo "Step 1: Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop com.example.imtbf.debug"

echo "Step 2: Creating preferences file"
cat > temp_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="true" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$(date +%Y%m%d_%H%M%S)</string>
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

echo "Step 3: Pushing preferences file to device"
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

echo "Step 4: Injecting preferences file to app's data directory"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/com.example.imtbf.debug/shared_prefs'"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Step 5: Starting app with special intent"
adb -s $DEVICE_ID shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity --ez load_settings false"

echo "Step 6: Waiting for app to initialize (2 seconds)"
sleep 2

echo "Step 7: Double checking preferences are still correct"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'" | grep -q "use_webview_mode.*true"
if [ $? -ne 0 ]; then
  echo "Warning: Preferences may have been overwritten. Reapplying settings..."
  adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
fi

echo "Step 8: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"

echo "Step 9: Checking final status"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Done! Simulation should now be running with the correct settings."

# Clean up
rm -f temp_prefs.xml 

# launch_insta_simulation.sh
# This script properly launches the Instagram traffic simulation on a device
# using the correct sequence of steps to ensure settings are applied correctly.

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id>"
  exit 1
fi

DEVICE_ID="$1"
INSTAGRAM_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

echo "Step 1: Stopping app on device $DEVICE_ID"
adb -s $DEVICE_ID shell "am force-stop com.example.imtbf.debug"

echo "Step 2: Creating preferences file"
cat > temp_prefs.xml << EOL
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="true" />
    <string name="device_id">$(date +%s)-$DEVICE_ID</string>
    <string name="current_session_id">$(date +%Y%m%d_%H%M%S)</string>
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

echo "Step 3: Pushing preferences file to device"
adb -s $DEVICE_ID push temp_prefs.xml /sdcard/temp_prefs.xml

echo "Step 4: Injecting preferences file to app's data directory"
adb -s $DEVICE_ID shell "su -c 'mkdir -p /data/data/com.example.imtbf.debug/shared_prefs'"
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Step 5: Starting app with special intent"
adb -s $DEVICE_ID shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity --ez load_settings false"

echo "Step 6: Waiting for app to initialize (2 seconds)"
sleep 2

echo "Step 7: Double checking preferences are still correct"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'" | grep -q "use_webview_mode.*true"
if [ $? -ne 0 ]; then
  echo "Warning: Preferences may have been overwritten. Reapplying settings..."
  adb -s $DEVICE_ID shell "su -c 'cp /sdcard/temp_prefs.xml /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chmod 660 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml && chown u0_a245:u0_a245 /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"
fi

echo "Step 8: Starting simulation"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"

echo "Step 9: Checking final status"
adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/instagram_traffic_simulator_prefs.xml'"

echo "Done! Simulation should now be running with the correct settings."

# Clean up
rm -f temp_prefs.xml 