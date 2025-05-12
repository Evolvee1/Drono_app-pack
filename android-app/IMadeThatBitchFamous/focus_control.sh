#!/bin/bash
# Focus Control Script for Drono App
# This script focuses the app window first, then sends commands

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define action for commands
ACTION="com.example.imtbf.REMOTE_COMMAND"

# Function to focus the app window
focus_app() {
  echo "Focusing app window..."
  adb shell "input keyevent KEYCODE_WAKEUP"
  sleep 0.5
  adb shell "am start -n $PACKAGE/$ACTIVITY"
  sleep 1
}

# Function to send command
send_command() {
  echo "Sending command: $1"
  adb shell "am start -n $PACKAGE/$ACTIVITY -a $ACTION --es command '$1'"
  echo "Command sent"
  sleep 1
}

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to show help
show_help() {
  echo "Drono App Focus Control"
  echo "----------------------"
  echo "Usage: ./focus_control.sh <command>"
  echo ""
  echo "Commands:"
  echo "  start    - Start simulation"
  echo "  pause    - Pause simulation"
  echo "  resume   - Resume simulation"
  echo "  stop     - Stop simulation"
  echo ""
  echo "Examples:"
  echo "  ./focus_control.sh start"
  echo "  ./focus_control.sh pause"
}

# Main command processing
case "$1" in
  "start")
    focus_app
    send_command "start"
    ;;
  "pause")
    focus_app
    send_command "pause"
    ;;
  "resume")
    focus_app
    send_command "resume"
    ;;
  "stop")
    focus_app
    send_command "stop"
    ;;
  *)
    show_help
    ;;
esac 