#!/bin/bash
# Force Wake Control Script for Drono App
# This script first ensures the app is awake before sending commands

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define action for commands
ACTION="com.example.imtbf.REMOTE_COMMAND"
# Define broadcast action
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"

# Function to wake up the app
wake_app() {
  echo "Waking up the app..."
  
  # First try to start the app directly
  adb shell am start -n $PACKAGE/$ACTIVITY
  sleep 2
  
  # Then make sure it's in foreground
  adb shell am start -n $PACKAGE/$ACTIVITY -a android.intent.action.MAIN
  sleep 1
}

# Function to send command
send_command() {
  local cmd="$1"
  echo "Sending command: $cmd"
  
  # Send direct activity intent
  adb shell am start -n $PACKAGE/$ACTIVITY -a $ACTION --es command "$cmd" --activity-single-top
  sleep 1
  
  # Send broadcast as backup
  adb shell am broadcast -a $BROADCAST_ACTION -p $PACKAGE -e command "$cmd"
  
  echo "Command sent"
}

# Function to execute a command with app wakeup
execute_command() {
  local cmd="$1"
  echo "Executing command: $cmd"
  
  # First wake the app
  wake_app
  
  # Then send the command
  send_command "$cmd"
  
  echo "Command execution completed"
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to show help
show_help() {
  echo "Drono App Force Wake Control"
  echo "---------------------------"
  echo "Usage: ./force_wake_control.sh <command>"
  echo ""
  echo "Commands:"
  echo "  start       - Start simulation"
  echo "  pause       - Pause simulation"
  echo "  resume      - Resume simulation"
  echo "  stop        - Stop simulation"
  echo ""
  echo "Examples:"
  echo "  ./force_wake_control.sh start"
  echo "  ./force_wake_control.sh pause"
}

# Main command processing
case "$1" in
  "start")
    execute_command "start"
    ;;
  "pause")
    execute_command "pause"
    ;;
  "resume")
    execute_command "resume"
    ;;
  "stop")
    execute_command "stop"
    ;;
  *)
    show_help
    ;;
esac 