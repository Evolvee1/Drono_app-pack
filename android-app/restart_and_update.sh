#!/bin/bash
# ADB-Only Settings Update Script
# This script guarantees UI updates by restarting the app

# Define package and activity names
PACKAGE="com.example.imtbf.debug"
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

# Function to send broadcast command
send_broadcast() {
  local command="$1"
  local value_type="$2"
  local value="$3"
  
  echo "Sending command: $command = $value"
  if [ "$value_type" = "string" ]; then
    adb shell am broadcast -a $BROADCAST_ACTION --es command "$command" --es value "$value" -p $PACKAGE
  else
    # Default to integer type
    adb shell am broadcast -a $BROADCAST_ACTION --es command "$command" --ei value $value -p $PACKAGE
  fi
  sleep 0.5
}

# Process arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value> [<setting2> <value2> ...]"
  echo ""
  echo "Available settings:"
  echo "  iterations <number>      - Set the number of iterations"
  echo "  min_interval <seconds>   - Set minimum interval"
  echo "  max_interval <seconds>   - Set maximum interval"
  echo "  toggle <feature> <true|false> - Toggle feature on/off"
  echo ""
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30 max_interval 60"
  exit 1
fi

# Step 1: Export current config as backup
echo "Backing up current configuration..."
adb shell am broadcast -a $BROADCAST_ACTION --es command "export_config" --es name "backup_config" --es desc "Auto Backup" -p $PACKAGE

# Step 2: Apply all requested changes
echo "Applying requested changes..."
arg_count=$#
i=1

while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  case "$setting" in
    "iterations")
      send_broadcast "set_iterations" "int" "$value"
      ;;
    "min_interval")
      send_broadcast "set_min_interval" "int" "$value"
      ;;
    "max_interval")
      send_broadcast "set_max_interval" "int" "$value"
      ;;
    "toggle")
      if [ $i -le $arg_count ]; then
        feature="$value"
        toggle_value="${!i}"
        i=$((i+1))
        adb shell am broadcast -a $BROADCAST_ACTION --es command "toggle_feature" --es feature "$feature" --es value "$toggle_value" -p $PACKAGE
      else
        echo "Missing toggle value for feature $value"
      fi
      ;;
    *)
      echo "Unknown setting: $setting (skipping)"
      ;;
  esac
done

# Step 3: Export a temporary config with new settings
echo "Saving new configuration..."
adb shell am broadcast -a $BROADCAST_ACTION --es command "export_config" --es name "temp_ui_update" --es desc "Temporary Config" -p $PACKAGE

# Step 4: Force stop the app
echo "Stopping app..."
adb shell am force-stop $PACKAGE
sleep 1

# Step 5: Start app again
echo "Starting app..."
adb shell am start -n $PACKAGE/$ACTIVITY
sleep 2

# Step 6: Import the temporary config to ensure UI is updated
echo "Importing configuration to refresh UI..."
adb shell am broadcast -a $BROADCAST_ACTION --es command "import_config" --es name "temp_ui_update.json" -p $PACKAGE

echo "Done! The UI should now reflect the updated settings." 