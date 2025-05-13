#!/bin/bash

# run_batch_simulation.sh
# A helper script to run batch simulations with common configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make the Python script executable
chmod +x "${SCRIPT_DIR}/batch_simulation.py"
# Make the shell script executable
chmod +x "${SCRIPT_DIR}/pre_start_settings.sh"

# Function to print usage
print_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --instagram        Run Instagram simulation with sample_config.json"
    echo "  --veewoy           Run Veewoy simulation with veewoy_config.json"
    echo "  --all-devices      Run on all connected devices (default: first device only)"
    echo "  --devices <ids>    Run on specific devices (space-separated IDs)"
    echo "  --parallel         Run in parallel mode (default: sequential)"
    echo "  --url <url>        Use a custom URL (without config file)"
    echo "  --config <file>    Use a custom config file"
    echo "  --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --instagram --all-devices --parallel"
    echo "  $0 --veewoy --devices R38N9014KDM R9WR310F4GJ"
    echo "  $0 --url \"https://example.com\" --parallel"
}

# Default values
CONFIG_FILE=""
DEVICES_OPTION=""
PARALLEL_OPTION=""
CUSTOM_URL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --instagram)
            CONFIG_FILE="${SCRIPT_DIR}/sample_config.json"
            shift
            ;;
        --veewoy)
            CONFIG_FILE="${SCRIPT_DIR}/veewoy_config.json"
            shift
            ;;
        --all-devices)
            DEVICES_OPTION="--all-devices"
            shift
            ;;
        --devices)
            shift
            DEVICES_OPTION="--devices $1"
            # If multiple device IDs are provided, process them all
            while [[ $# -gt 1 && ! $2 == --* ]]; do
                shift
                DEVICES_OPTION="$DEVICES_OPTION $1"
            done
            shift
            ;;
        --parallel)
            PARALLEL_OPTION="--parallel"
            shift
            ;;
        --url)
            CUSTOM_URL="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$CONFIG_FILE" && -z "$CUSTOM_URL" ]]; then
    echo "Error: Either a config file or URL must be specified"
    print_usage
    exit 1
fi

# Build the Python command
if [[ -n "$CONFIG_FILE" ]]; then
    COMMAND="${SCRIPT_DIR}/batch_simulation.py --config \"${CONFIG_FILE}\" ${DEVICES_OPTION} ${PARALLEL_OPTION}"
else
    COMMAND="${SCRIPT_DIR}/batch_simulation.py --url \"${CUSTOM_URL}\" ${DEVICES_OPTION} ${PARALLEL_OPTION}"
fi

echo "Executing: $COMMAND"
eval "$COMMAND"

exit $? 

# run_batch_simulation.sh
# A helper script to run batch simulations with common configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make the Python script executable
chmod +x "${SCRIPT_DIR}/batch_simulation.py"
# Make the shell script executable
chmod +x "${SCRIPT_DIR}/pre_start_settings.sh"

# Function to print usage
print_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --instagram        Run Instagram simulation with sample_config.json"
    echo "  --veewoy           Run Veewoy simulation with veewoy_config.json"
    echo "  --all-devices      Run on all connected devices (default: first device only)"
    echo "  --devices <ids>    Run on specific devices (space-separated IDs)"
    echo "  --parallel         Run in parallel mode (default: sequential)"
    echo "  --url <url>        Use a custom URL (without config file)"
    echo "  --config <file>    Use a custom config file"
    echo "  --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --instagram --all-devices --parallel"
    echo "  $0 --veewoy --devices R38N9014KDM R9WR310F4GJ"
    echo "  $0 --url \"https://example.com\" --parallel"
}

# Default values
CONFIG_FILE=""
DEVICES_OPTION=""
PARALLEL_OPTION=""
CUSTOM_URL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --instagram)
            CONFIG_FILE="${SCRIPT_DIR}/sample_config.json"
            shift
            ;;
        --veewoy)
            CONFIG_FILE="${SCRIPT_DIR}/veewoy_config.json"
            shift
            ;;
        --all-devices)
            DEVICES_OPTION="--all-devices"
            shift
            ;;
        --devices)
            shift
            DEVICES_OPTION="--devices $1"
            # If multiple device IDs are provided, process them all
            while [[ $# -gt 1 && ! $2 == --* ]]; do
                shift
                DEVICES_OPTION="$DEVICES_OPTION $1"
            done
            shift
            ;;
        --parallel)
            PARALLEL_OPTION="--parallel"
            shift
            ;;
        --url)
            CUSTOM_URL="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$CONFIG_FILE" && -z "$CUSTOM_URL" ]]; then
    echo "Error: Either a config file or URL must be specified"
    print_usage
    exit 1
fi

# Build the Python command
if [[ -n "$CONFIG_FILE" ]]; then
    COMMAND="${SCRIPT_DIR}/batch_simulation.py --config \"${CONFIG_FILE}\" ${DEVICES_OPTION} ${PARALLEL_OPTION}"
else
    COMMAND="${SCRIPT_DIR}/batch_simulation.py --url \"${CUSTOM_URL}\" ${DEVICES_OPTION} ${PARALLEL_OPTION}"
fi

echo "Executing: $COMMAND"
eval "$COMMAND"

exit $? 