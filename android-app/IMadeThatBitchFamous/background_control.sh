#!/bin/bash
# Background Control Script for Drono App
# This script uses a combination of techniques to work with apps in the background

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define action for commands
ACTION="com.example.imtbf.REMOTE_COMMAND"
# Define broadcast action
BROADCAST_ACTION="com.example.imtbf.debug.COMMAND"
# Define broadcast receiver
RECEIVER="com.example.imtbf.remote.AdbCommandReceiver"

# Function to send broadcast command (best for background operation)
send_broadcast() {
  echo "Sending broadcast command: $1"
  # Try explicit component targeting
  adb shell am broadcast -a $BROADCAST_ACTION -n $PACKAGE/$RECEIVER -e command "$1"
  sleep 1
}

# Function to send direct intent to activity (best for foreground operation)
send_direct_intent() {
  echo "Sending direct intent: $1"
  # Force new task to ensure delivery with FLAG_ACTIVITY_NEW_TASK
  adb shell am start -n $PACKAGE/$ACTIVITY -a $ACTION --es command "$1" -f 0x10000000
  sleep 1
}

# Alternative broadcast method using just package specification
send_package_broadcast() {
  echo "Sending package broadcast command: $1"
  adb shell am broadcast -a $BROADCAST_ACTION -p $PACKAGE -e command "$1"
  sleep 1
}

# Function to wake device and send command (try all methods)
send_command() {
  local cmd="$1"
  echo "Executing command: $cmd"
  
  # Try all methods for maximum reliability
  send_broadcast "$cmd"
  send_package_broadcast "$cmd"
  send_direct_intent "$cmd"
  
  echo "Command attempts completed"
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to show help
show_help() {
  echo "Drono App Background Control"
  echo "---------------------------"
  echo "Usage: ./background_control.sh <command>"
  echo ""
  echo "Commands:"
  echo "  start       - Start simulation"
  echo "  pause       - Pause simulation"
  echo "  resume      - Resume simulation"
  echo "  stop        - Stop simulation"
  echo "  status      - Get status info"
  echo ""
  echo "Examples:"
  echo "  ./background_control.sh start"
  echo "  ./background_control.sh pause"
}

# Main command processing
case "$1" in
  "start")
    send_command "start"
    ;;
  "pause")
    send_command "pause"
    ;;
  "resume")
    send_command "resume"
    ;;
  "stop")
    send_command "stop"
    ;;
  "status")
    send_command "get_status"
    ;;
  *)
    show_help
    ;;
esac 