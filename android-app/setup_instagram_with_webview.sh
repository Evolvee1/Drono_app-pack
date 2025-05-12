#!/bin/bash
# Script to set up Instagram URL in the app with all WebView features enabled
# Usage: ./setup_instagram_with_webview.sh [device_id]

# Set device ID
if [ -z "$1" ]; then
  # Get first device if not specified
  DEVICE_ID=$(adb devices | grep -v "List" | grep "device$" | head -n 1 | cut -f1)
  if [ -z "$DEVICE_ID" ]; then
    echo "No device connected"
    exit 1
  fi
else
  DEVICE_ID="$1"
fi

echo "Using device: $DEVICE_ID"

# Instagram URL to set
URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

# Package and preferences constants
PACKAGE="com.example.imtbf.debug"
PREFS_FILE="/data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"
URL_CONFIG_FILE="/data/data/$PACKAGE/shared_prefs/url_config.xml"

echo "Step 1: Force stopping app..."
adb -s "$DEVICE_ID" shell am force-stop "$PACKAGE"
sleep 1

echo "Step 2: Setting up preferences directly..."

# Create a temp preferences file
cat > temp_prefs.xml << EOF
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="use_webview_mode" value="true" />
    <boolean name="new_webview_per_request" value="true" />
    <boolean name="rotate_ip" value="true" />
    <boolean name="use_random_device_profile" value="true" />
    <boolean name="handle_marketing_redirects" value="true" />
    <string name="target_url">$URL</string>
    <int name="iterations" value="1000" />
    <int name="min_interval" value="1" />
    <int name="max_interval" value="2" />
    <int name="airplane_mode_delay" value="3000" />
    <int name="delay_min" value="1" />
    <int name="delay_max" value="5" />
    <boolean name="is_running" value="false" />
    <boolean name="is_first_run" value="false" />
</map>
EOF

# Create URL config file
cat > temp_url_config.xml << EOF
<?xml version="1.0" encoding="utf-8" ?>
<map>
<string name="instagram_url">$URL</string>
<string name="url_source">external</string>
<long name="url_timestamp">$(date +%s)000000000</long>
</map>
EOF

# Push the preferences files to device
echo "Step 3: Pushing preferences files to device..."
adb -s "$DEVICE_ID" push temp_prefs.xml /data/local/tmp/prefs.xml
adb -s "$DEVICE_ID" push temp_url_config.xml /data/local/tmp/url_config.xml

# Check access method and copy files
echo "Step 4: Checking access method and copying files..."
if adb -s "$DEVICE_ID" shell "su -c 'ls $PREFS_FILE'" >/dev/null 2>&1; then
    echo "Using root access method"
    # Get the package's UID and GID
    PACKAGE_UID=$(adb -s "$DEVICE_ID" shell "su -c 'stat -c %u /data/data/$PACKAGE'")
    PACKAGE_GID=$(adb -s "$DEVICE_ID" shell "su -c 'stat -c %g /data/data/$PACKAGE'")
    
    echo "Using UID: $PACKAGE_UID and GID: $PACKAGE_GID"
    
    adb -s "$DEVICE_ID" shell "su -c 'cp /data/local/tmp/prefs.xml $PREFS_FILE && chmod 660 $PREFS_FILE && chown $PACKAGE_UID:$PACKAGE_GID $PREFS_FILE'"
    adb -s "$DEVICE_ID" shell "su -c 'cp /data/local/tmp/url_config.xml $URL_CONFIG_FILE && chmod 660 $URL_CONFIG_FILE && chown $PACKAGE_UID:$PACKAGE_GID $URL_CONFIG_FILE'"
elif adb -s "$DEVICE_ID" shell "run-as $PACKAGE ls" >/dev/null 2>&1; then
    echo "Using run-as access method"
    adb -s "$DEVICE_ID" shell "run-as $PACKAGE cp /data/local/tmp/prefs.xml $PREFS_FILE"
    adb -s "$DEVICE_ID" shell "run-as $PACKAGE cp /data/local/tmp/url_config.xml $URL_CONFIG_FILE"
else
    echo "No valid access method available"
    exit 1
fi

# Clean up temp files
rm temp_prefs.xml temp_url_config.xml
adb -s "$DEVICE_ID" shell "rm /data/local/tmp/prefs.xml /data/local/tmp/url_config.xml"

# Start the app using direct intent with URL parameter
echo "Step 5: Starting app with direct URL intent..."
# URL-encode the URL parameter for the intent
URL_ESCAPED=$(echo "$URL" | sed 's/&/\\&/g')
adb -s "$DEVICE_ID" shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity -e direct_url \"$URL_ESCAPED\""

# Wait for app to start
echo "Step 6: Waiting for app to initialize..."
sleep 3

# Check if text field has URL, if not, fill it manually
echo "Step 7: Verifying URL field contains the correct URL, manually filling if needed..."
adb -s "$DEVICE_ID" shell "input tap 300 80 && sleep 0.5 && input keyevent KEYCODE_CTRL_A && input keyevent KEYCODE_DEL && input text '$URL'"

# Ensure toggles are enabled by tapping them (assuming 5 toggles, adjusting Y positions)
echo "Step 8: Enabling all toggle switches..."
adb -s "$DEVICE_ID" shell "input tap 550 985" # WebView Mode
sleep 0.3
adb -s "$DEVICE_ID" shell "input tap 550 1195" # New WebView Per Request
sleep 0.3
adb -s "$DEVICE_ID" shell "input tap 550 1405" # Rotate IP
sleep 0.3
adb -s "$DEVICE_ID" shell "input tap 550 1615" # Random Devices
sleep 0.3
adb -s "$DEVICE_ID" shell "input tap 550 1825" # Handle Marketing Redirects

# Check status
echo "Step 9: Checking app status..."
adb -s "$DEVICE_ID" shell "dumpsys activity top | grep -A 5 'etTargetUrl'"

# Take a screenshot for verification
echo "Step 10: Taking screenshot for verification..."
adb -s "$DEVICE_ID" shell screencap -p /sdcard/instagram_setup_screenshot.png
adb -s "$DEVICE_ID" pull /sdcard/instagram_setup_screenshot.png .

echo "Instagram URL has been set up with all WebView features enabled."
echo "Screenshot saved to instagram_setup_screenshot.png" 