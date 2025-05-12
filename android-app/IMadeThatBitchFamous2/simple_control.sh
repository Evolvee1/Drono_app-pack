#!/bin/bash
# Simple Control Script for Drono App
# This script uses direct activity intents to control the app

# Define app package name for debug build
PACKAGE="com.example.imtbf2.debug"
# Define main activity
ACTIVITY="com.example.imtbf2.presentation.activities.MainActivity"

# Check if ADB is available
adb devices > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: ADB not found or not working"
  exit 1
fi

# Function to start the app with a command
send_command() {
  echo "Sending command: $1"
  adb shell am start -n $PACKAGE/$ACTIVITY -a "com.example.imtbf2.REMOTE_COMMAND" --es command "$1"
  echo "Command sent"
}

# Function to show help
show_help() {
  echo "Drono App Simple Control"
  echo "-----------------------"
  echo "Usage: ./simple_control.sh <command>"
  echo ""
  echo "Commands:"
  echo "  start    - Start simulation"
  echo "  pause    - Pause simulation"
  echo "  resume   - Resume simulation"
  echo "  stop     - Stop simulation"
  echo ""
  echo "Examples:"
  echo "  ./simple_control.sh start"
  echo "  ./simple_control.sh pause"
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
  *)
    show_help
    ;;
esac 