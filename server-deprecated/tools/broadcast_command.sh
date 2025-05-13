#!/bin/bash
# Broadcast Command Script
# This script automatically gets all device IDs and sends a command to all devices

SERVER_URL="http://127.0.0.1:8000"
API_DEVICES_URL="${SERVER_URL}/devices"
API_BATCH_ENDPOINT="${SERVER_URL}/api/devices/batch/command"
DRONO_SCRIPT="../../android-app/drono_control.sh"

# Help function
show_help() {
    echo "Drono Broadcast Command Utility"
    echo "--------------------------------"
    echo "Usage: ./broadcast_command.sh [options]"
    echo ""
    echo "Required options:"
    echo "  --command <cmd>      Command to execute (e.g., start, stop, pause)"
    echo ""
    echo "Optional parameters:"
    echo "  --include <pattern>    Only include devices matching this pattern (e.g., 'SM-A')"
    echo "  --exclude <pattern>    Exclude devices matching this pattern"
    echo "  --url <url>            Target URL for start command"
    echo "  --iterations <num>     Number of iterations"
    echo "  --min-interval <sec>   Minimum interval between requests (seconds)"
    echo "  --max-interval <sec>   Maximum interval between requests (seconds)"
    echo "  --webview-mode         Enable webview mode"
    echo "  --no-webview-mode      Disable webview mode"
    echo "  --dismiss-restore      Dismiss restore dialog"
    echo "  --dry-run              Simulate execution without actually running commands"
    echo "  --direct               Use direct execution with drono_control.sh instead of server API"
    echo "  --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "./broadcast_command.sh --command start --url https://veewoy.com/ip-text --iterations 100 --min-interval 1 --max-interval 2 --webview-mode --dismiss-restore"
    exit 0
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_help
fi

# Parse arguments
COMMAND=""
INCLUDE_PATTERN=""
EXCLUDE_PATTERN=""
URL=""
ITERATIONS=""
MIN_INTERVAL=""
MAX_INTERVAL=""
WEBVIEW_MODE=""
DISMISS_RESTORE=false
DRY_RUN=false
DIRECT_EXECUTION=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --command)
            COMMAND="$2"
            shift 2
            ;;
        --include)
            INCLUDE_PATTERN="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_PATTERN="$2"
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
        --direct)
            DIRECT_EXECUTION=true
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

# Get all devices
echo "Fetching connected devices..."
DEVICES_JSON=$(curl -s "$API_DEVICES_URL")
if [ -z "$DEVICES_JSON" ] || [ "$DEVICES_JSON" == "{}" ]; then
    echo "Error: Failed to get devices or no devices found"
    exit 1
fi

# We need to use jq to parse JSON
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required to parse device data. Please install jq."
    exit 1
fi

# Filter devices based on include/exclude patterns
if [ ! -z "$INCLUDE_PATTERN" ]; then
    echo "Filtering devices that match pattern: $INCLUDE_PATTERN"
    FILTERED_DEVICES=$(echo "$DEVICES_JSON" | jq -c "[.[] | select(.model | contains(\"$INCLUDE_PATTERN\") or .id | contains(\"$INCLUDE_PATTERN\"))]")
    DEVICES_JSON="$FILTERED_DEVICES"
fi

if [ ! -z "$EXCLUDE_PATTERN" ]; then
    echo "Excluding devices that match pattern: $EXCLUDE_PATTERN"
    FILTERED_DEVICES=$(echo "$DEVICES_JSON" | jq -c "[.[] | select(.model | contains(\"$EXCLUDE_PATTERN\") or .id | contains(\"$EXCLUDE_PATTERN\") | not)]")
    DEVICES_JSON="$FILTERED_DEVICES"
fi

# Extract device IDs
DEVICE_IDS=$(echo "$DEVICES_JSON" | jq -r '.[].id')
DEVICE_COUNT=$(echo "$DEVICE_IDS" | wc -l | tr -d ' ')
DEVICE_MODELS=$(echo "$DEVICES_JSON" | jq -r '.[].model')

# Check if we have any devices after filtering
if [ -z "$DEVICE_IDS" ] || [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "No devices found after applying filters."
    exit 1
fi

# Show list of devices that will receive the command
echo "Found $DEVICE_COUNT devices:"
paste <(echo "$DEVICE_IDS") <(echo "$DEVICE_MODELS") | while read id model; do
    echo "  - $id ($model)"
done
echo ""

# If direct execution, use drono_control.sh instead of server API
if [ "$DIRECT_EXECUTION" = true ]; then
    # Check if drono_control.sh exists
    SCRIPT_PATH=$(realpath "$DRONO_SCRIPT")
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "Error: drono_control.sh not found at $SCRIPT_PATH"
        exit 1
    fi
    
    echo "Using direct execution with drono_control.sh"
    echo "Script path: $SCRIPT_PATH"
    
    # Build command arguments
    ARGS=""
    if [ ! -z "$URL" ]; then
        ARGS="$ARGS url \"$URL\""
    fi
    if [ ! -z "$ITERATIONS" ]; then
        ARGS="$ARGS iterations $ITERATIONS"
    fi
    if [ ! -z "$MIN_INTERVAL" ]; then
        ARGS="$ARGS min_interval $MIN_INTERVAL"
    fi
    if [ ! -z "$MAX_INTERVAL" ]; then
        ARGS="$ARGS max_interval $MAX_INTERVAL"
    fi
    if [ "$DISMISS_RESTORE" = true ]; then
        ARGS="$ARGS dismiss_restore"
    fi
    if [ ! -z "$WEBVIEW_MODE" ]; then
        ARGS="$ARGS toggle webview_mode $WEBVIEW_MODE"
    fi
    
    # Preview the command
    echo "Command template: ADB_DEVICE_ID=<DEVICE_ID> $SCRIPT_PATH -settings $ARGS $COMMAND"
    
    # Confirm execution
    if [ "$DRY_RUN" = false ]; then
        read -p "Execute this command on $DEVICE_COUNT devices? (y/n): " CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            echo "Aborted by user."
            exit 0
        fi
    fi
    
    # Execute on each device
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: Command would be executed on $DEVICE_COUNT devices"
    else
        TOTAL_SUCCESS=0
        TOTAL_FAILED=0
        
        echo "Executing command on $DEVICE_COUNT devices..."
        echo "========================================================"
        
        for DEVICE_ID in $DEVICE_IDS; do
            MODEL=$(echo "$DEVICES_JSON" | jq -r ".[] | select(.id == \"$DEVICE_ID\") | .model")
            echo "Executing on $DEVICE_ID ($MODEL)..."
            
            FULL_COMMAND="ADB_DEVICE_ID=$DEVICE_ID $SCRIPT_PATH -settings $ARGS $COMMAND"
            echo "$FULL_COMMAND"
            
            if eval "$FULL_COMMAND"; then
                echo "✅ Command succeeded on $DEVICE_ID"
                TOTAL_SUCCESS=$((TOTAL_SUCCESS + 1))
            else
                echo "❌ Command failed on $DEVICE_ID"
                TOTAL_FAILED=$((TOTAL_FAILED + 1))
            fi
            echo "-------------------------------------------------------"
        done
        
        echo "========================================================"
        echo "Execution complete: $TOTAL_SUCCESS succeeded, $TOTAL_FAILED failed"
    fi
else
    # Use server API
    # Format device IDs for JSON payload
    DEVICE_IDS_JSON=$(echo "$DEVICE_IDS" | jq -Rc '. | split("\n") | map(select(length > 0))')
    
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
    JSON="{\"command\":\"$COMMAND\",\"parameters\":$PARAMS,\"device_ids\":$DEVICE_IDS_JSON,\"dryrun\":$DRY_RUN}"
    
    # Preview the command
    echo "Sending command to API endpoint: $API_BATCH_ENDPOINT"
    echo "Payload:"
    echo $JSON | jq .
    
    # Confirm execution
    if [ "$DRY_RUN" = false ]; then
        read -p "Execute this command on $DEVICE_COUNT devices? (y/n): " CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            echo "Aborted by user."
            exit 0
        fi
    fi
    
    # Send the command
    echo "Executing command on $DEVICE_COUNT devices..."
    curl -X POST "$API_BATCH_ENDPOINT" \
      -H "Content-Type: application/json" \
      -d "$JSON" | jq .
fi

echo ""
echo "Broadcast command completed." 