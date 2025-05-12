# ADB Settings Management Solution

This project provides a comprehensive solution for managing settings on Android devices via ADB, particularly for Instagram traffic simulations. It enables users to pass settings from a frontend dashboard to connected phones.

## Features

- **Device Management**: Discover and manage connected Android devices
- **Settings Configuration**: Apply general and Instagram-specific settings
- **URL Configuration**: Handle complex Instagram URLs with maximum compatibility
- **Parallel Execution**: Process multiple devices simultaneously
- **Detailed Reporting**: Get comprehensive success/failure reports
- **Multiple Approaches**: Use different methods for maximum reliability
- **Proxy Support**: Configure proxy settings for traffic routing
- **Command-line Interface**: Interact with the API via a CLI tool

## Components

1. **Settings API Server**
   - REST API for device management and settings configuration
   - Built with FastAPI for high performance and easy extension

2. **Shell Scripts**
   - `direct_url_command.sh`: Minimalist approach for reliable URL setting
   - `enhanced_insta_sim.sh`: Enhanced version with better error handling
   - `direct_url_setter.sh`: Comprehensive script trying multiple methods

3. **Command-line Tool**
   - `test_settings_api.py`: CLI for interacting with the API
   - Supports all operations with detailed output options

4. **Frontend Dashboard**
   - Web interface for managing settings (optional component)

## Getting Started

### Prerequisites

- Python 3.6+
- ADB (Android Debug Bridge) installed
- Connected Android devices with USB debugging enabled

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/adb-settings-management.git
   cd adb-settings-management
   ```

2. Install required packages:
   ```bash
   pip install -r requirements.txt
   ```

3. Make shell scripts executable:
   ```bash
   chmod +x server/tools/*.sh
   ```

### Running the Server

```bash
cd server/tools
python settings_api_server.py
```

The server will be available at http://localhost:8000.

### Using the Command-line Tool

List connected devices:
```bash
python test_settings_api.py list
```

Apply settings to a specific device:
```bash
python test_settings_api.py cmd --url "https://example.com" --devices R9WR310F4GJ
```

See all available commands:
```bash
python test_settings_api.py help
```

## Documentation

Detailed documentation is available in the `docs` directory:

- [Setup Guide](docs/setup.md): Instructions for installation and configuration
- [API Documentation](docs/api.md): Details on available API endpoints
- [Architecture Overview](docs/architecture.md): System architecture and components

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- The Android Debug Bridge (ADB) team
- FastAPI project for the excellent API framework 