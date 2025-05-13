#!/bin/bash

# Configuration
BASE_PORT=8001
NUM_SERVERS=4
VENV_PATH="/opt/drono-control/venv"
APP_PATH="/opt/drono-control"
LOG_DIR="/var/log/drono-control"

# Create log directory if it doesn't exist
mkdir -p $LOG_DIR

# Function to start a server instance
start_server() {
    local port=$1
    local log_file="$LOG_DIR/server_$port.log"
    
    echo "Starting server on port $port..."
    $VENV_PATH/bin/uvicorn main:app --host 0.0.0.0 --port $port \
        --workers 4 \
        --log-level info \
        --access-log \
        --proxy-headers \
        --forwarded-allow-ips '*' \
        > $log_file 2>&1 &
    
    echo $! > "$LOG_DIR/server_$port.pid"
}

# Function to stop a server instance
stop_server() {
    local port=$1
    local pid_file="$LOG_DIR/server_$port.pid"
    
    if [ -f $pid_file ]; then
        echo "Stopping server on port $port..."
        kill $(cat $pid_file)
        rm $pid_file
    fi
}

# Function to check server status
check_server() {
    local port=$1
    local pid_file="$LOG_DIR/server_$port.pid"
    
    if [ -f $pid_file ]; then
        if ps -p $(cat $pid_file) > /dev/null; then
            echo "Server on port $port is running"
        else
            echo "Server on port $port is not running (stale PID file)"
            rm $pid_file
        fi
    else
        echo "Server on port $port is not running"
    fi
}

# Function to restart a server instance
restart_server() {
    local port=$1
    stop_server $port
    sleep 2
    start_server $port
}

# Main script logic
case "$1" in
    start)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            start_server $port
        done
        ;;
    stop)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            stop_server $port
        done
        ;;
    restart)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            restart_server $port
        done
        ;;
    status)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            check_server $port
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0 

# Configuration
BASE_PORT=8001
NUM_SERVERS=4
VENV_PATH="/opt/drono-control/venv"
APP_PATH="/opt/drono-control"
LOG_DIR="/var/log/drono-control"

# Create log directory if it doesn't exist
mkdir -p $LOG_DIR

# Function to start a server instance
start_server() {
    local port=$1
    local log_file="$LOG_DIR/server_$port.log"
    
    echo "Starting server on port $port..."
    $VENV_PATH/bin/uvicorn main:app --host 0.0.0.0 --port $port \
        --workers 4 \
        --log-level info \
        --access-log \
        --proxy-headers \
        --forwarded-allow-ips '*' \
        > $log_file 2>&1 &
    
    echo $! > "$LOG_DIR/server_$port.pid"
}

# Function to stop a server instance
stop_server() {
    local port=$1
    local pid_file="$LOG_DIR/server_$port.pid"
    
    if [ -f $pid_file ]; then
        echo "Stopping server on port $port..."
        kill $(cat $pid_file)
        rm $pid_file
    fi
}

# Function to check server status
check_server() {
    local port=$1
    local pid_file="$LOG_DIR/server_$port.pid"
    
    if [ -f $pid_file ]; then
        if ps -p $(cat $pid_file) > /dev/null; then
            echo "Server on port $port is running"
        else
            echo "Server on port $port is not running (stale PID file)"
            rm $pid_file
        fi
    else
        echo "Server on port $port is not running"
    fi
}

# Function to restart a server instance
restart_server() {
    local port=$1
    stop_server $port
    sleep 2
    start_server $port
}

# Main script logic
case "$1" in
    start)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            start_server $port
        done
        ;;
    stop)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            stop_server $port
        done
        ;;
    restart)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            restart_server $port
        done
        ;;
    status)
        for ((i=0; i<NUM_SERVERS; i++)); do
            port=$((BASE_PORT + i))
            check_server $port
        done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0 