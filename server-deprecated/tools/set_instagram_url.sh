#!/bin/bash
# Instagram URL Setter - Simple shell script for setting Instagram URLs
# This script wraps the Instagram CLI tool

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CLI_SCRIPT="$SCRIPT_DIR/instagram_cli.py"

# Default values
URL=""
DEVICE=""
ITERATIONS=100
MIN_INTERVAL=3
MAX_INTERVAL=5
WEBVIEW_MODE=true
NEW_WEBVIEW=true
ROTATE_IP=true
RANDOM_DEVICES=true
DELAY=3000

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --url)
      URL="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --min-interval)
      MIN_INTERVAL="$2"
      shift 2
      ;;
    --max-interval)
      MAX_INTERVAL="$2"
      shift 2
      ;;
    --webview-mode)
      if [[ "$2" == "true" || "$2" == "1" || "$2" == "yes" ]]; then
        WEBVIEW_MODE=true
      else
        WEBVIEW_MODE=false
      fi
      shift 2
      ;;
    --new-webview-per-request)
      if [[ "$2" == "true" || "$2" == "1" || "$2" == "yes" ]]; then
        NEW_WEBVIEW=true
      else
        NEW_WEBVIEW=false
      fi
      shift 2
      ;;
    --rotate-ip)
      if [[ "$2" == "true" || "$2" == "1" || "$2" == "yes" ]]; then
        ROTATE_IP=true
      else
        ROTATE_IP=false
      fi
      shift 2
      ;;
    --random-devices)
      if [[ "$2" == "true" || "$2" == "1" || "$2" == "yes" ]]; then
        RANDOM_DEVICES=true
      else
        RANDOM_DEVICES=false
      fi
      shift 2
      ;;
    --delay)
      DELAY="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --url <url>                  Instagram URL to set (required)"
      echo "  --device <device_id>         Target specific device (optional)"
      echo "  --iterations <num>           Number of iterations (default: 100)"
      echo "  --min-interval <seconds>     Minimum interval between requests (default: 3)"
      echo "  --max-interval <seconds>     Maximum interval between requests (default: 5)"
      echo "  --webview-mode <true|false>  Use WebView mode (default: true)"
      echo "  --new-webview-per-request <true|false>  Create new WebView per request (default: true)"
      echo "  --rotate-ip <true|false>     Rotate IP between requests (default: true)"
      echo "  --random-devices <true|false> Use random device profiles (default: true)"
      echo "  --delay <milliseconds>       Airplane mode delay (default: 3000)"
      echo "  --help, -h                   Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check for required parameters
if [ -z "$URL" ]; then
  echo "Error: URL is required"
  echo "Use --help for usage information"
  exit 1
fi

# Check if Python CLI script exists
if [ ! -f "$CLI_SCRIPT" ]; then
  echo "Error: Instagram CLI script not found at $CLI_SCRIPT"
  exit 1
fi

# Make script executable if it's not already
chmod +x "$CLI_SCRIPT" 2>/dev/null

# Build command arguments
CMD_ARGS="set-url --url \"$URL\" --iterations $ITERATIONS --min-interval $MIN_INTERVAL --max-interval $MAX_INTERVAL --delay $DELAY"

# Add device if specified
if [ -n "$DEVICE" ]; then
  CMD_ARGS="$CMD_ARGS --device $DEVICE"
fi

# Add feature flags
if [ "$WEBVIEW_MODE" = false ]; then
  CMD_ARGS="$CMD_ARGS --no-webview-mode"
fi

if [ "$NEW_WEBVIEW" = false ]; then
  CMD_ARGS="$CMD_ARGS --no-new-webview-per-request"
fi

if [ "$ROTATE_IP" = false ]; then
  CMD_ARGS="$CMD_ARGS --no-rotate-ip"
fi

if [ "$RANDOM_DEVICES" = false ]; then
  CMD_ARGS="$CMD_ARGS --no-random-devices"
fi

# Display settings
echo "Setting Instagram URL with the following parameters:"
echo "URL: $URL"
echo "Iterations: $ITERATIONS"
echo "Interval: $MIN_INTERVAL-$MAX_INTERVAL seconds"
echo "WebView Mode: $WEBVIEW_MODE"
echo "New WebView Per Request: $NEW_WEBVIEW"
echo "Rotate IP: $ROTATE_IP"
echo "Random Devices: $RANDOM_DEVICES"
echo "Delay: $DELAY ms"
echo "Device: ${DEVICE:-All Devices}"
echo ""
echo "Using reliable method: Force stop app → Set config → Restart app"
echo "This ensures the UI is properly updated and settings are persisted"
echo ""

# Execute the CLI command
cd "$(dirname "$CLI_SCRIPT")"
python3 "$(basename "$CLI_SCRIPT")" $CMD_ARGS

# Get exit code and exit
exit $? 