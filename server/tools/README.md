# Device Settings Tools

> **Note:** Some older or redundant tools have been moved to the `legacy_tools` folder. For current functionality, please use the Settings API server and its associated tools as documented in `README_SETTINGS_API.md`.

# API-Based Device Settings Management

This directory contains tools for managing settings on Android devices via a REST API. The system allows frontend dashboards to easily control and configure Android devices via ADB.

## Core Components

- `settings_api_server.py` - The main API server that exposes endpoints for device management
- `test_settings_api.py` - Command-line client for interacting with the API
- `robust_batch_drono.py` - Core implementation for batch command execution
- `direct_url_setter.sh` - Specialized script for setting URLs with high compatibility
- `enhanced_insta_sim.sh` - Enhanced simulation script with improved error handling

## Starting the Servers

To start both the API server and frontend dashboard:

```bash
./start_servers.sh
```

This will:
1. Start the API server on port 8000
2. Start the frontend server on port 8080
3. Open the dashboard in your browser

## Recommended Usage

For most operations, use the test_settings_api.py client:

```bash
# For the most reliable URL setting (recommended for complex URLs):
python3 test_settings_api.py cmd --url "https://example.com" --devices DEVICE_ID

# To list connected devices:
python3 test_settings_api.py list

# For built-in help guide:
python3 test_settings_api.py help
```

## Documentation

For detailed documentation on the API endpoints and usage, please refer to `README_SETTINGS_API.md`. 