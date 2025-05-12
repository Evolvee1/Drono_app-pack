#!/bin/bash
# Direct Edit Preferences Script
# This script will directly modify the app's shared preferences files

PACKAGE="com.example.imtbf.debug"
PREFS_FILE="/data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml"

# First check if we can access the file (requires root)
adb shell "su -c 'ls $PREFS_FILE'" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "❌ Cannot access preferences file. Root access may be required."
  # Try using run-as as a fallback (for debug builds)
  adb shell "run-as $PACKAGE ls /data/data/$PACKAGE/shared_prefs/instagram_traffic_simulator_prefs.xml" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "❌ Cannot access preferences file even with run-as. Aborting."
    exit 1
  else
    echo "✅ Can access file with run-as. Continuing with non-root method."
    USE_RUNAS=1
  fi
else
  echo "✅ Can access file with root. Continuing."
  USE_RUNAS=0
fi

# Function to update preference
update_preference() {
  local name=$1
  local value=$2
  local type=$3
  echo "Updating $name to $value..."
  
  if [ $USE_RUNAS -eq 1 ]; then
    # Use run-as for debug builds
    adb shell "run-as $PACKAGE sed -i 's|<$type name=\"$name\" value=\"[^\"]*\"|<$type name=\"$name\" value=\"$value\"|g' $PREFS_FILE"
  else
    # Use su for rooted devices
    adb shell "su -c 'sed -i \"s|<$type name=\\\"$name\\\" value=\\\"[^\\\"]*\\\"|<$type name=\\\"$name\\\" value=\\\"$value\\\"|g\" $PREFS_FILE'"
  fi
}

# Function to update string preference (special handling for URL with escaping)
update_string_preference() {
  local name=$1
  local value=$2
  echo "Updating $name to $value..."
  
  # Escape special characters for sed
  local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
  
  if [ $USE_RUNAS -eq 1 ]; then
    # Use run-as for debug builds
    adb shell "run-as $PACKAGE sed -i 's|<string name=\"$name\">[^<]*</string>|<string name=\"$name\">$escaped_value</string>|g' $PREFS_FILE"
  else
    # Use su for rooted devices
    adb shell "su -c 'sed -i \"s|<string name=\\\"$name\\\">[^<]*</string>|<string name=\\\"$name\\\">$escaped_value</string>|g\" $PREFS_FILE'"
  fi
}

# Set new values
echo "Stopping app to safely edit preferences..."
adb shell am force-stop $PACKAGE
sleep 1

# Process command line arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value> [<setting2> <value2> ...]"
  echo "Available settings: iterations, min_interval, max_interval, url, delay, is_running"
  exit 1
fi

# Parse and process arguments
arg_count=$#
i=1

while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  case "$setting" in
    "iterations")
      update_preference "iterations" "$value" "int"
      ;;
    "min_interval")
      update_preference "min_interval" "$value" "int"
      ;;
    "max_interval")
      update_preference "max_interval" "$value" "int"
      ;;
    "url")
      update_string_preference "target_url" "$value"
      ;;
    "delay")
      update_preference "airplane_mode_delay" "$value" "int"
      ;;
    "is_running")
      update_preference "is_running" "$value" "boolean"
      ;;
    *)
      echo "Unknown setting: $setting (skipping)"
      ;;
  esac
done

# Fix permissions if needed
if [ $USE_RUNAS -eq 0 ]; then
  echo "Fixing file permissions..."
  adb shell "su -c 'chmod 660 $PREFS_FILE && chown $PACKAGE:$PACKAGE $PREFS_FILE'"
fi

# Start app
echo "Starting app..."
adb shell am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity

echo "Done! The app should now load with the new values." 