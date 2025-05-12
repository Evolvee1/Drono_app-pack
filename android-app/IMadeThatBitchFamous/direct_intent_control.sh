#!/bin/bash
# Direct Intent Control Script for Drono App
# This script uses direct intents to the MainActivity

# Define app package name for debug build
PACKAGE="com.example.imtbf.debug"
# Define main activity
ACTIVITY="com.example.imtbf.presentation.activities.MainActivity"
# Define action for commands
ACTION="com.example.imtbf.REMOTE_COMMAND"

# Function to send command via activity intent
send_command() {
  echo "Sending command to MainActivity: $1"
  # Use start activity with a specific action and bring to foreground
  adb shell am start -n $PACKAGE/$ACTIVITY -a $ACTION --es command "$1" --activity-brought-to-front
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
  echo "Drono App Direct Control"
  echo "-----------------------"
  echo "Usage: ./direct_intent_control.sh <command>"
  echo ""
  echo "Commands:"
  echo "  start       - Start simulation"
  echo "  pause       - Pause simulation"
  echo "  resume      - Resume simulation"
  echo "  stop        - Stop simulation"
  echo ""
  echo "Examples:"
  echo "  ./direct_intent_control.sh start"
  echo "  ./direct_intent_control.sh pause"
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
