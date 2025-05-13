# Drono Lite Control Server

A streamlined server for controlling Android devices running the IMadeThatBitchFamous app. This lightweight server provides essential functionality for device control and URL distribution while removing unnecessary complexity.

## Features

- **ADB Device Control**: Direct ADB command execution for Android devices
- **Batch Command Execution**: Execute commands on multiple devices simultaneously
- **URL Distribution**: Efficiently distribute URLs to multiple devices
- **Real-time Updates**: WebSocket-based communication for live device status and command results
- **Web Dashboard**: Browser-based control interface for managing devices
- **REST API**: HTTP endpoints for integration with external systems

## Prerequisites

- Python 3.8 or higher
- ADB (Android Debug Bridge) installed and in PATH
- Connected Android devices with IMadeThatBitchFamous app installed
- USB debugging enabled on devices

## Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/drono-lite.git
cd drono-lite
```

2. Create and activate a virtual environment:
```bash
# On Windows
python -m venv venv
venv\Scripts\activate

# On Linux/Mac
python3 -m venv venv
source venv/bin/activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Starting the Server

```bash
cd drono_lite
python main.py
```

The server will start on http://localhost:8000 by default.

### Using the Web Dashboard

1. Open a web browser and navigate to http://localhost:8000
2. Use the web interface to:
   - Scan for connected devices
   - Distribute URLs to devices
   - Send batch commands to multiple devices
   - Monitor device status

### API Endpoints

#### Device Management

- `GET /devices` - List all connected devices
- `POST /devices/scan` - Scan for new devices

#### Device Commands

- `POST /devices/{device_id}/command` - Execute a command on a specific device
- `POST /devices/batch/command` - Execute a command on multiple devices
- `POST /distribute-url` - Distribute a URL to multiple devices

#### WebSockets

- `WS /ws/{channel}` - WebSocket endpoint for real-time updates

## Examples

### Distributing a URL to Devices

```bash
curl -X POST "http://localhost:8000/distribute-url" \
     -H "Content-Type: application/json" \
     -d '{
       "url": "https://example.com",
       "iterations": 100,
       "min_interval": 1,
       "max_interval": 2
     }'
```

### Executing a Command on a Device

```bash
curl -X POST "http://localhost:8000/devices/R38N9014KDM/command" \
     -H "Content-Type: application/json" \
     -d '{
       "command": "start",
       "parameters": {
         "url": "https://example.com",
         "iterations": 100
       }
     }'
```

## Troubleshooting

### Common Issues

1. **ADB Not Found**: Ensure ADB is installed and in your system PATH.
2. **Device Not Detected**: Make sure USB debugging is enabled and the device is connected.
3. **Permission Errors**: On some devices, you may need to run the server with elevated privileges.

### Debugging

Check the log file `drono_lite.log` for detailed error information.

## Folder Structure

```
drono_lite/
├── api/            # API endpoints and routes
├── core/           # Core functionality modules
│   ├── adb_controller.py      # ADB command execution
│   └── websocket_manager.py   # WebSocket connection management
├── static/         # Static web files
│   └── dashboard.html         # Web dashboard interface
├── utils/          # Utility functions
├── main.py         # Server entry point
└── requirements.txt # Python dependencies
``` 