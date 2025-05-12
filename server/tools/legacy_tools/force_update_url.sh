#!/bin/bash

# force_update_url.sh
# A minimal script that forces an Instagram URL update while the app is running
# This script assumes the app is already running on the device

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id> [url_file]"
  echo ""
  echo "If url_file is not provided, will use instagram_url.txt"
  exit 1
fi

DEVICE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL_FILE="${2:-${SCRIPT_DIR}/instagram_url.txt}"

if [ ! -f "$URL_FILE" ]; then
  echo "Error: URL file not found at $URL_FILE"
  exit 1
fi

# Target app settings
PACKAGE="com.example.imtbf.debug"
PREFS_FILE="/data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

# Read the URL from the file without any processing
INSTAGRAM_URL=$(cat "$URL_FILE")
echo "Using URL: $INSTAGRAM_URL"

# Properly escape the URL for XML
XML_URL=$(echo "$INSTAGRAM_URL" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

echo "Step 1: Extracting current preferences"
# First, extract the current preference file
TEMP_PREFS="current_prefs.xml"
adb -s $DEVICE_ID shell "su -c 'cat $PREFS_FILE'" > $TEMP_PREFS

echo "Step 2: Modifying URL in preferences"
# Replace the URL but keep all other settings
sed -i.bak "s|<string name=\"target_url\">.*</string>|<string name=\"target_url\">$XML_URL</string>|g" $TEMP_PREFS

# Verify that the URL was actually changed in the file
if ! grep -q "<string name=\"target_url\">$XML_URL</string>" $TEMP_PREFS; then
  echo "Error: Failed to update URL in preferences file"
  rm -f $TEMP_PREFS $TEMP_PREFS.bak
  exit 1
fi

echo "Step 3: Pushing updated preferences back to device"
# Push the modified file back to the device
adb -s $DEVICE_ID push $TEMP_PREFS /sdcard/updated_prefs.xml

# Apply it to the app's data directory
adb -s $DEVICE_ID shell "su -c 'cp /sdcard/updated_prefs.xml $PREFS_FILE && chmod 660 $PREFS_FILE && chown u0_a245:u0_a245 $PREFS_FILE || chown 10245:10245 $PREFS_FILE || true'"

echo "Step 4: Verifying change was applied"
# Check if the change was successfully applied
FINAL_PREFS=$(adb -s $DEVICE_ID shell "su -c 'cat $PREFS_FILE'")
if echo "$FINAL_PREFS" | grep -q "<string name=\"target_url\">$XML_URL</string>"; then
  echo "✅ SUCCESS: URL has been directly updated to:"
  echo "$INSTAGRAM_URL"
else
  echo "❌ ERROR: URL update failed"
  echo "Current URL value:"
  echo "$FINAL_PREFS" | grep -o '<string name="target_url">.*</string>'
fi

echo "Step 5: Forcing app to reload settings"
# Broadcast reload command
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command reload_settings -p $PACKAGE"
sleep 1

# Alternative: restart activity to force reload
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command restart -p $PACKAGE"

# Clean up
rm -f $TEMP_PREFS $TEMP_PREFS.bak

echo "Done! The URL has been forcefully updated while the app is running."
echo "If the app still doesn't use the new URL, you may need to restart it completely." 