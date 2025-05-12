#!/bin/bash
# Update With Status Script for Drono App
# Shows current status, updates settings, and restarts simulation

# Define package name
PACKAGE="com.example.imtbf.debug"
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

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
  
  adb shell "am broadcast -a $BROADCAST_ACTION -e command '$command' $params -p $PACKAGE" > /dev/null
  sleep 0.5
}

# Function to print a divider
print_divider() {
  echo "===================================================="
}

# Function to get app status
check_app_status() {
  echo "📱 Checking current app status..."
  print_divider
  
  # Request status (this may or may not work depending on app implementation)
  send_broadcast "get_status" ""
  echo "⚠️ Note: The UI may show different values than what's stored in preferences."
  print_divider
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
  echo ""
  echo "Examples:"
  echo "  $0 iterations 200"
  echo "  $0 min_interval 30 max_interval 60"
  exit 1
fi

# Check current status before making changes
check_app_status

# Stop any running simulation
echo "Stopping any running simulation..."
send_broadcast "stop" ""
sleep 2

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

# Start a new simulation
echo "Starting new simulation with updated settings..."
send_broadcast "start" ""
echo "✅ Simulation restarted! The new settings should now be visible in the UI." 