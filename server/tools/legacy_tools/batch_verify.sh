#!/bin/bash

# batch_verify.sh - Apply Instagram URL and settings to multiple devices

# Instagram URL to use
INSTAGRAM_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"

# Get a list of connected devices
DEVICES=$(adb devices | grep -v "List" | grep "device$" | awk '{print $1}')
SCRIPT_DIR="$(dirname "$0")"
VERIFY_SCRIPT="$SCRIPT_DIR/verify_instagram_url.sh"

if [ -z "$DEVICES" ]; then
  echo "No devices connected. Exiting."
  exit 1
fi

echo "Found connected devices:"
for DEVICE in $DEVICES; do
  echo "- $DEVICE"
done

echo "------------------------------"
echo "Setting up Instagram URL and preferences on all devices..."

for DEVICE in $DEVICES; do
  echo "------------------------------"
  echo "Setting up device: $DEVICE"
  
  # Verify URL and settings are properly set
  if [ -x "$VERIFY_SCRIPT" ]; then
    "$VERIFY_SCRIPT" "$DEVICE" "$INSTAGRAM_URL"
  else
    echo "Error: verify_instagram_url.sh not found or not executable at $VERIFY_SCRIPT"
    echo "Falling back to basic setup..."
    
    # Basic setup commands
    adb -s "$DEVICE" shell "am force-stop com.example.imtbf.debug"
    sleep 2
    
    # Send the URL via broadcast
    adb -s "$DEVICE" shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es url \"$INSTAGRAM_URL\" -p com.example.imtbf.debug"
    
    # Set required preferences
    adb -s "$DEVICE" shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value true -p com.example.imtbf.debug"
    adb -s "$DEVICE" shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value true -p com.example.imtbf.debug"
    adb -s "$DEVICE" shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value false -p com.example.imtbf.debug"
    
    # Start with deep link
    adb -s "$DEVICE" shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d \"traffic-sim://instagram?url=$INSTAGRAM_URL&force=true\""
    sleep 1
    
    # Start the simulation
    adb -s "$DEVICE" shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"
  fi
  
  echo "Setup complete for device: $DEVICE"
done

echo "------------------------------"
echo "All devices have been set up"
echo "------------------------------"

# Verification step
echo "Verifying setup on all devices..."
for DEVICE in $DEVICES; do
  echo "------------------------------"
  echo "Verifying device: $DEVICE"
  
  # Check if app is running
  if adb -s $DEVICE shell "ps | grep com.example.imtbf.debug" | grep -q "com.example.imtbf.debug"; then
    echo "✓ App is running on $DEVICE"
  else
    echo "✗ App is NOT running on $DEVICE"
  fi
  
  # Check URL in config
  URL_CONFIG=$(adb -s $DEVICE shell "su -c 'cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml'" 2>/dev/null || \
    adb -s $DEVICE shell "cat /data/data/com.example.imtbf.debug/shared_prefs/url_config.xml" 2>/dev/null)
  
  if echo "$URL_CONFIG" | grep -q "instagram_url"; then
    echo "✓ URL is configured in url_config.xml"
  else
    echo "✗ URL is NOT configured in url_config.xml"
  fi
  
  # Request status via broadcast
  echo "Requesting status from app..."
  adb -s $DEVICE shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p com.example.imtbf.debug"
done

echo "------------------------------"
echo "Batch verification complete" 