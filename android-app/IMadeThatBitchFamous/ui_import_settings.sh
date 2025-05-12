#!/bin/bash
# UI Import Settings Script for Drono App
# Uses direct UI intent to refresh the app interface

# Define package name
PACKAGE="com.example.imtbf.debug"
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"
CONFIG_NAME="ui_refresh_config"

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to send broadcast command
send_broadcast() {
  local command="$1"
  local params="$2"
  
  if [ -z "$params" ]; then
    echo "Sending command: $command"
  else
    echo "Setting $command to $params"
  fi
  
  result=$(adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE")
  
  if [[ "$result" == *"result=0"* ]]; then
    return 0
  else
    echo "❌ Command failed: $result"
    return 1
  fi
}

# Function to print a divider
print_divider() {
  echo "===================================================="
}

# Process arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <setting> <value> [<setting2> <value2> ...]"
  echo ""
  echo "Available settings:"
  echo "  iterations <number>      - Set the number of iterations"
  echo "  min_interval <seconds>   - Set minimum interval"
  echo "  max_interval <seconds>   - Set maximum interval"
  echo "  url <url>                - Set target URL"
  echo "  delay <milliseconds>     - Set airplane mode delay"
  echo "  toggle <feature> <true|false> - Toggle feature on/off (rotate_ip, random_devices, webview_mode, etc.)"
  echo ""
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30 max_interval 60"
  exit 1
fi

# Make sure app is running and in foreground
echo "📱 Making sure app is running..."
adb shell am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity
sleep 1

# Save current state before making changes
echo "Making configuration backup..."
send_broadcast "export_config" "-e name 'backup_before_changes' -e desc 'Backup before changes'"
sleep 0.5

# Change all requested settings
echo "Updating settings..."
arg_count=$#
i=1
changes=()

while [ $i -le $((arg_count-1)) ]; do
  setting="${!i}"
  i=$((i+1))
  value="${!i}"
  i=$((i+1))
  
  # Store changes for summary
  changes+=("$setting=$value")
  
  # Apply setting change based on parameter type
  case "$setting" in
    "iterations")
      send_broadcast "set_iterations" "-e value $value"
      ;;
    "min_interval")
      send_broadcast "set_min_interval" "-e value $value"
      ;;
    "max_interval")
      send_broadcast "set_max_interval" "-e value $value"
      ;;
    "url")
      send_broadcast "set_url" "-e value '$value'"
      ;;
    "delay")
      send_broadcast "set_airplane_delay" "-e value $value"
      ;;
    "toggle")
      if [ $i -le $arg_count ]; then
        feature="$value"
        toggle_value="${!i}"
        i=$((i+1))
        
        # Update the changes array to reflect the toggle
        changes[${#changes[@]}-1]="toggle $feature=$toggle_value"
        
        # Send the toggle command
        send_broadcast "toggle_feature" "-e feature '$feature' -e value $toggle_value"
      else
        echo "⚠️ Missing toggle value for feature $value"
      fi
      ;;
    *)
      echo "⚠️ Unknown setting: $setting (skipping)"
      ;;
  esac
done

# Print summary of changes
print_divider
echo "✅ Settings updated with these changes:"
for change in "${changes[@]}"; do
  echo "  👉 $change"
done
print_divider

# Create a configuration with updated settings
echo "🔄 Creating update configuration..."
send_broadcast "export_config" "-e name '$CONFIG_NAME' -e desc 'UI update config'"
sleep 0.5

# Now force refresh of UI with direct activity intent
echo "⚡ Forcing app restart to refresh UI..."
adb shell am force-stop $PACKAGE
sleep 1
adb shell am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity
sleep 2

# Import the configuration using a new intent
echo "📲 Importing configuration to refresh UI..."
send_broadcast "import_config" "-e name '${CONFIG_NAME}.json'"

echo "🎉 Done! The UI should now be refreshed with your changes." 