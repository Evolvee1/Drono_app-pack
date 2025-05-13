#!/bin/bash
# Batch Command Utility Script
# This simple bash script uses curl to send commands to multiple devices

SERVER_URL="http://127.0.0.1:8000"
API_ENDPOINT="${SERVER_URL}/api/devices/batch/command"

# Help function
show_help() {
    echo "Drono Batch Command Utility"
    echo "----------------------------"
    echo "Usage: ./batch_curl.sh [options]"
    echo ""
    echo "Required options:"
    echo "  --command <cmd>    Command to execute (e.g., start, stop, pause)"
    echo "  --devices <ids>    Comma-separated list of device IDs"
    echo ""
    echo "Optional parameters:"
    echo "  --url <url>             Target URL for start command"
    echo "  --iterations <num>      Number of iterations"
    echo "  --min-interval <sec>    Minimum interval between requests (seconds)"
    echo "  --max-interval <sec>    Maximum interval between requests (seconds)"
    echo "  --webview-mode          Enable webview mode"
    echo "  --no-webview-mode       Disable webview mode"
    echo "  --dismiss-restore       Dismiss restore dialog"
    echo "  --dry-run               Simulate execution without actually running commands"
    echo "  --help                  Show this help message"
    echo ""
    echo "Example:"
    echo "./batch_curl.sh --command start --devices R9WR310F4GJ,1b0527540404 --url https://veewoy.com/ip-text --iterations 100 --min-interval 1 --max-interval 2 --webview-mode --dismiss-restore"
    exit 0
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
fi

# Parse arguments
COMMAND=""
DEVICES=""
URL=""
ITERATIONS=""
MIN_INTERVAL=""
MAX_INTERVAL=""
WEBVIEW_MODE=""
DISMISS_RESTORE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --devices)
            DEVICES="$2"
            shift 2
            ;;
        --url)
            URL="$2"
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
            WEBVIEW_MODE=true
            shift
            ;;
        --no-webview-mode)
            WEBVIEW_MODE=false
            shift
            ;;
        --dismiss-restore)
            DISMISS_RESTORE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate required arguments
if [ -z "$COMMAND" ]; then
    echo "Error: --command is required"
    exit 1
fi

if [ -z "$DEVICES" ]; then
    echo "Error: --devices is required"
    exit 1
fi

# Convert comma-separated device IDs to JSON array
DEVICE_IDS=$(echo $DEVICES | sed 's/,/","/g')
DEVICE_IDS="[\"$DEVICE_IDS\"]"

# Build parameters JSON
PARAMS="{"
if [ ! -z "$URL" ]; then
    PARAMS="$PARAMS\"url\":\"$URL\","
fi
if [ ! -z "$ITERATIONS" ]; then
    PARAMS="$PARAMS\"iterations\":$ITERATIONS,"
fi
if [ ! -z "$MIN_INTERVAL" ]; then
    PARAMS="$PARAMS\"min_interval\":$MIN_INTERVAL,"
fi
if [ ! -z "$MAX_INTERVAL" ]; then
    PARAMS="$PARAMS\"max_interval\":$MAX_INTERVAL,"
fi
if [ ! -z "$WEBVIEW_MODE" ]; then
    PARAMS="$PARAMS\"webview_mode\":$WEBVIEW_MODE,"
fi
if [ "$DISMISS_RESTORE" = true ]; then
    PARAMS="$PARAMS\"dismiss_restore\":true,"
fi
# Remove trailing comma if necessary
PARAMS=$(echo $PARAMS | sed 's/,$//')
PARAMS="$PARAMS}"

# Build final JSON payload
JSON="{\"command\":\"$COMMAND\",\"parameters\":$PARAMS,\"device_ids\":$DEVICE_IDS,\"dryrun\":$DRY_RUN}"

# Preview the command
echo "Sending command to API endpoint: $API_ENDPOINT"
echo "Payload:"
echo $JSON | python3 -m json.tool

# Confirm execution
if [ "$DRY_RUN" = false ]; then
    read -p "Execute this command on the selected devices? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
fi

# Send the command
echo "Executing command..."
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$JSON" | python3 -m json.tool

echo ""
echo "Command execution complete." 
# Batch Command Utility Script
# This simple bash script uses curl to send commands to multiple devices

SERVER_URL="http://127.0.0.1:8000"
API_ENDPOINT="${SERVER_URL}/api/devices/batch/command"

# Help function
show_help() {
    echo "Drono Batch Command Utility"
    echo "----------------------------"
    echo "Usage: ./batch_curl.sh [options]"
    echo ""
    echo "Required options:"
    echo "  --command <cmd>    Command to execute (e.g., start, stop, pause)"
    echo "  --devices <ids>    Comma-separated list of device IDs"
    echo ""
    echo "Optional parameters:"
    echo "  --url <url>             Target URL for start command"
    echo "  --iterations <num>      Number of iterations"
    echo "  --min-interval <sec>    Minimum interval between requests (seconds)"
    echo "  --max-interval <sec>    Maximum interval between requests (seconds)"
    echo "  --webview-mode          Enable webview mode"
    echo "  --no-webview-mode       Disable webview mode"
    echo "  --dismiss-restore       Dismiss restore dialog"
    echo "  --dry-run               Simulate execution without actually running commands"
    echo "  --help                  Show this help message"
    echo ""
    echo "Example:"
    echo "./batch_curl.sh --command start --devices R9WR310F4GJ,1b0527540404 --url https://veewoy.com/ip-text --iterations 100 --min-interval 1 --max-interval 2 --webview-mode --dismiss-restore"
    exit 0
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
fi

# Parse arguments
COMMAND=""
DEVICES=""
URL=""
ITERATIONS=""
MIN_INTERVAL=""
MAX_INTERVAL=""
WEBVIEW_MODE=""
DISMISS_RESTORE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --devices)
            DEVICES="$2"
            shift 2
            ;;
        --url)
            URL="$2"
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
            WEBVIEW_MODE=true
            shift
            ;;
        --no-webview-mode)
            WEBVIEW_MODE=false
            shift
            ;;
        --dismiss-restore)
            DISMISS_RESTORE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate required arguments
if [ -z "$COMMAND" ]; then
    echo "Error: --command is required"
    exit 1
fi

if [ -z "$DEVICES" ]; then
    echo "Error: --devices is required"
    exit 1
fi

# Convert comma-separated device IDs to JSON array
DEVICE_IDS=$(echo $DEVICES | sed 's/,/","/g')
DEVICE_IDS="[\"$DEVICE_IDS\"]"

# Build parameters JSON
PARAMS="{"
if [ ! -z "$URL" ]; then
    PARAMS="$PARAMS\"url\":\"$URL\","
fi
if [ ! -z "$ITERATIONS" ]; then
    PARAMS="$PARAMS\"iterations\":$ITERATIONS,"
fi
if [ ! -z "$MIN_INTERVAL" ]; then
    PARAMS="$PARAMS\"min_interval\":$MIN_INTERVAL,"
fi
if [ ! -z "$MAX_INTERVAL" ]; then
    PARAMS="$PARAMS\"max_interval\":$MAX_INTERVAL,"
fi
if [ ! -z "$WEBVIEW_MODE" ]; then
    PARAMS="$PARAMS\"webview_mode\":$WEBVIEW_MODE,"
fi
if [ "$DISMISS_RESTORE" = true ]; then
    PARAMS="$PARAMS\"dismiss_restore\":true,"
fi
# Remove trailing comma if necessary
PARAMS=$(echo $PARAMS | sed 's/,$//')
PARAMS="$PARAMS}"

# Build final JSON payload
JSON="{\"command\":\"$COMMAND\",\"parameters\":$PARAMS,\"device_ids\":$DEVICE_IDS,\"dryrun\":$DRY_RUN}"

# Preview the command
echo "Sending command to API endpoint: $API_ENDPOINT"
echo "Payload:"
echo $JSON | python3 -m json.tool

# Confirm execution
if [ "$DRY_RUN" = false ]; then
    read -p "Execute this command on the selected devices? (y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
fi

# Send the command
echo "Executing command..."
curl -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$JSON" | python3 -m json.tool

echo ""
echo "Command execution complete." 