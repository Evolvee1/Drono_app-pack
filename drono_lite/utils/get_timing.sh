#!/bin/bash
# Script to get detailed timing information from Android devices

# Check if device ID is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <device_id>"
  echo "Example: $0 R9WR310F4GJ"
  exit 1
fi

DEVICE_ID=$1

# Send command to get detailed status
echo "Requesting detailed timing information from device $DEVICE_ID..."
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_detailed_status -p com.example.imtbf.debug"

# Wait a moment for the command to be processed
sleep 1

# Get the logcat output with timing information
echo "Retrieving timing information from logcat..."
adb -s $DEVICE_ID shell "logcat -d -v brief -t 100 MainActivity:D AdbCommandReceiver:I | grep -E 'Time elapsed|remaining|Progress'"

# Try to get the status.json file
echo -e "\nAttempting to get status.json file..."
STATUS_FILE=$(adb -s $DEVICE_ID shell "su -c 'cat /data/data/com.example.imtbf.debug/files/status.json'" 2>/dev/null)

if [ ! -z "$STATUS_FILE" ]; then
  echo -e "\nStatus file content:"
  echo $STATUS_FILE
  
  # Extract key timing information
  START_TIME=$(echo $STATUS_FILE | grep -o '"startTimeMs":[0-9]*' | cut -d':' -f2)
  PAUSED_TIME=$(echo $STATUS_FILE | grep -o '"totalPausedTimeMs":[0-9]*' | cut -d':' -f2)
  ACTUAL_ELAPSED=$(echo $STATUS_FILE | grep -o '"actualElapsedMs":[0-9]*' | cut -d':' -f2)
  CURRENT=$(echo $STATUS_FILE | grep -o '"currentIteration":[0-9]*' | cut -d':' -f2)
  TOTAL=$(echo $STATUS_FILE | grep -o '"totalIterations":[0-9]*' | cut -d':' -f2)
  
  echo -e "\nSummary:"
  echo "Start Time: $(date -d @$((START_TIME/1000)) 2>/dev/null || date -r $((START_TIME/1000)) 2>/dev/null)"
  echo "Total Paused Time: $((PAUSED_TIME/1000)) seconds"
  echo "Actual Elapsed Time: $((ACTUAL_ELAPSED/1000)) seconds"
  
  if [ ! -z "$CURRENT" ] && [ ! -z "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    PERCENTAGE=$(echo "scale=1; $CURRENT * 100 / $TOTAL" | bc)
    echo "Progress: $CURRENT/$TOTAL ($PERCENTAGE%)"
  fi
else
  echo "Could not retrieve status.json file. Make sure the device is rooted and the app is running."
fi 