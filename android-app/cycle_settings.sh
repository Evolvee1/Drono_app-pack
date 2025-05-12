#!/bin/bash
# Script to cycle through different settings every few seconds

echo "Starting settings cycle script..."
echo "Press Ctrl+C to stop"

# First stop any running simulation
./combo_control.sh stop
sleep 2

# Start with initial configuration
echo "Setting initial configuration..."
./combo_control.sh min_interval=5 max_interval=15 iterations=100
sleep 1

# Check status before starting
echo "Starting simulation..."
./combo_control.sh start
sleep 5

counter=1
while true; do
  echo "===================================="
  echo "Change #$counter"
  
  case $((counter % 4)) in
    0)
      echo "Setting very low intervals (1 & 3), high iterations (300)"
      ./combo_control.sh min_interval=1 max_interval=3 iterations=300
      ;;
    1)
      echo "Setting medium intervals (8 & 15), medium iterations (100)"
      ./combo_control.sh min_interval=8 max_interval=15 iterations=100
      ;;
    2)
      echo "Setting high intervals (20 & 40), low iterations (50)"
      ./combo_control.sh min_interval=20 max_interval=40 iterations=50
      ;;
    3)
      echo "Setting extreme values: very short intervals (1 & 2), very high iterations (500)"
      ./combo_control.sh min_interval=1 max_interval=2 iterations=500
      ;;
  esac
  
  # Wait before next change
  echo "Waiting 15 seconds before next change..."
  sleep 15
  counter=$((counter + 1))
done 