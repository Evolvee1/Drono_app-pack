#!/bin/bash

# run_instagram.sh
# Helper script to easily run Instagram simulations on multiple devices
# This provides a simple command-line interface to batch_instagram.py

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATCH_SCRIPT="${SCRIPT_DIR}/batch_instagram.py"

# Display usage information
function show_help {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help            Show this help message"
  echo "  -a, --all-devices     Run on all connected devices"
  echo "  -d, --devices DEV     Specify device IDs (space-separated)"
  echo "  -u, --url URL         Set Instagram URL"
  echo "  -p, --parallel        Run simulations in parallel"
  echo ""
  echo "Examples:"
  echo "  $0 --url 'https://l.instagram.com/?u=https%3A%2F%2Fexample.com'"
  echo "  $0 --all-devices --parallel"
  echo "  $0 --devices 'emulator-5554 R5CN20HTRWJ'"
  exit 0
}

# Check if Python script exists
if [ ! -f "${BATCH_SCRIPT}" ]; then
  echo "Error: batch_instagram.py script not found at ${BATCH_SCRIPT}"
  exit 1
fi

# Make script executable if needed
if [ ! -x "${BATCH_SCRIPT}" ]; then
  chmod +x "${BATCH_SCRIPT}"
fi

# Initialize variables
ALL_DEVICES=false
DEVICES_SPECIFIED=false
DEVICES=()
URL=""
PARALLEL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -a|--all-devices)
      ALL_DEVICES=true
      shift
      ;;
    -d|--devices)
      DEVICES_SPECIFIED=true
      shift
      # Collect all device IDs until we hit another option or end of args
      while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
        DEVICES+=("$1")
        shift
      done
      ;;
    -u|--url)
      URL="$2"
      shift 2
      ;;
    -p|--parallel)
      PARALLEL=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      ;;
  esac
done

# Construct command
CMD=("${BATCH_SCRIPT}")

# Add options
if [[ "$ALL_DEVICES" == true ]]; then
  CMD+=("--all-devices")
elif [[ "$DEVICES_SPECIFIED" == true && ${#DEVICES[@]} -gt 0 ]]; then
  CMD+=("--devices")
  for dev in "${DEVICES[@]}"; do
    CMD+=("$dev")
  done
fi

if [[ -n "$URL" ]]; then
  CMD+=("--url" "$URL")
fi

if [[ "$PARALLEL" == true ]]; then
  CMD+=("--parallel")
fi

# Run the command
echo "Running: ${CMD[*]}"
"${CMD[@]}" 