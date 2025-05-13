# Drono Control Server - Usage Guide

This guide provides instructions on how to use the Drono Control Server to manage and monitor Android devices running the Drono simulation app.

## Getting Started

1. **Start the server:**
   ```bash
   cd server
   python -m main
   ```

   The server will start on port 8000 by default.

2. **Authentication:**
   All API endpoints require authentication. The default credentials are:
   - Username: `admin`
   - Password: `adminpassword`

## Using the Demo Script

The `demo_control.py` script provides a command-line interface for controlling devices through the server.

### Basic Commands

1. **List all connected devices:**
   ```bash
   ./demo_control.py --list
   ```

2. **Check status of a specific device:**
   ```bash
   ./demo_control.py --status DEVICE_ID
   ```
   Replace `DEVICE_ID` with the actual ID of your Android device.

3. **Start a simulation:**
   ```bash
   ./demo_control.py --start DEVICE_ID --url https://example.com --iterations 50 --min-interval 1 --max-interval 3
   ```

4. **Monitor progress of a running simulation:**
   ```bash
   ./demo_control.py --monitor DEVICE_ID
   ```

5. **Start a simulation and automatically monitor progress:**
   ```bash
   ./demo_control.py --start DEVICE_ID --monitor auto
   ```

6. **Stop a running simulation:**
   ```bash
   ./demo_control.py --stop DEVICE_ID
   ```

### Advanced Options

- **Custom server location:**
  ```bash
  ./demo_control.py --server 192.168.1.100 --port 8080 --list
  ```

- **Disable WebView mode:**
  ```bash
  ./demo_control.py --start DEVICE_ID --no-webview
  ```

- **Use a pre-existing authentication token:**
  ```bash
  ./demo_control.py --token YOUR_JWT_TOKEN --list
  ```

## WebSocket Interface

The server provides a WebSocket interface for real-time device status updates. Two HTML clients are available:

1. **Basic WebSocket Client:**
   Open `test_websocket.html` in a browser to connect to the WebSocket endpoint without authentication.

2. **Authenticated WebSocket Client:**
   Open `test_websocket_auth.html` in a browser to connect with authentication and monitor devices in real-time.

   This client provides:
   - Authentication to the server
   - Real-time device status updates
   - Progress tracking with completion percentage
   - Estimated time remaining for simulations
   - Controls for starting and stopping simulations

## REST API Endpoints

### Authentication

- `POST /auth/token` - Get JWT token
  ```bash
  curl -X POST http://localhost:8000/auth/token -d "username=admin&password=adminpassword"
  ```

### Device Management

- `GET /devices` - List all connected devices
  ```bash
  curl -H "Authorization: Bearer YOUR_JWT_TOKEN" http://localhost:8000/devices
  ```

- `GET /devices/{device_id}/status` - Get detailed device status
  ```bash
  curl -H "Authorization: Bearer YOUR_JWT_TOKEN" http://localhost:8000/devices/DEVICE_ID/status
  ```

### Command Execution

- `POST /commands/start` - Start simulation on a device
  ```bash
  curl -X POST -H "Authorization: Bearer YOUR_JWT_TOKEN" -H "Content-Type: application/json" \
    -d '{"device_id":"DEVICE_ID","url":"https://example.com","iterations":50,"min_interval":1,"max_interval":3,"webview_mode":true}' \
    http://localhost:8000/commands/start
  ```

- `POST /commands/stop` - Stop simulation on a device
  ```bash
  curl -X POST -H "Authorization: Bearer YOUR_JWT_TOKEN" -H "Content-Type: application/json" \
    -d '{"device_id":"DEVICE_ID"}' \
    http://localhost:8000/commands/stop
  ```

## Progress Tracking

The Drono Control Server provides detailed progress tracking information:

1. **Progress Percentage:** Shows the current iteration out of the total iterations as a percentage.
2. **Time Remaining:** Estimates the time remaining based on the elapsed time and completed iterations.

This progress information is available through:
- The WebSocket interface in real-time
- The REST API status endpoint
- The command-line demo script's monitoring feature

## Troubleshooting

1. **Authentication Issues:**
   If you receive HTTP 401 errors, ensure you're using the correct username and password, or check that your JWT token is valid and hasn't expired.

2. **Device Not Found:**
   Make sure the Android device is properly connected via ADB and that USB debugging is enabled.

3. **Server Connection Issues:**
   Verify that the server is running and accessible from your client. Check for any firewalls or network restrictions that might block the connection.

4. **WebSocket Connection Issues:**
   WebSockets require an initial upgrade request. If your connection fails, check if there's any proxy or firewall in between that doesn't support WebSockets.

## Support

For additional help, please check the README.md file or report issues to the project maintainers. 