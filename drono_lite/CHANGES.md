# Changes from Original Drono Server to Drono Lite

This document outlines the changes made when streamlining the original Drono server to create the more focused Drono Lite version.

## Components Removed

1. **Database Layer**: Removed SQLAlchemy/database dependencies to create a stateless server
2. **Authentication System**: Removed JWT authentication for simplicity
3. **Complex Monitoring**: Removed detailed monitoring and alerting systems
4. **Redis Integration**: Removed Redis caching and pub/sub features
5. **Advanced Device Management**: Simplified device management system
6. **Server Clustering**: Removed distributed server capabilities
7. **Migration System**: Removed Alembic database migrations
8. **Complex Configuration**: Simplified environment configuration

## Core Functionality Retained

1. **ADB Device Control**: Direct control of Android devices via ADB
2. **URL Distribution**: Ability to send URLs to multiple devices
3. **WebSocket Communication**: Real-time updates between server and clients
4. **Device Monitoring**: Basic device status monitoring
5. **Web Dashboard**: Browser-based control interface

## Recent Improvements

The following critical issues have been fixed to ensure reliable operation with all Android devices:

1. **Enhanced ADB Controller**: 
   - Added robust device permission checking
   - Implemented multiple methods for different device access levels
   - Incorporated successful techniques from direct_command.ps1

2. **Improved Settings Distribution**: 
   - Added file-based settings application for devices with write access
   - Added root-based settings application for devices with root access
   - Enhanced intent-based settings for devices with limited access
   - Combined multiple techniques to ensure maximum compatibility
   
3. **Better Device Access Detection**:
   - Automatic detection of write access to app directories
   - Automatic detection of root access
   - Custom handling for each device based on available permissions
   
4. **Improved Web Dashboard**:
   - Enhanced UI with better device status visualization
   - Added permission/access level indicators for each device
   - Improved communication via WebSockets and HTTP fallback
   - Added better logging and error handling

5. **Environment Setup**:
   - Added auto-detecting run scripts for Windows and Linux
   - Added automatic Python and dependency installation
   - Fixed path issues and environment detection

## Latest Update: ROOT MODE Implementation

The newest version implements a complete ROOT MODE operation that solves all permission-related issues:

1. **ROOT MODE ADB Controller**:
   - Completely rewritten to use root (su) commands exclusively
   - Bypasses all permission checks and restrictions
   - Creates required directories with proper permissions
   - Ensures maximum compatibility with all rooted devices
   
2. **Removed Permission Checking**:
   - All devices are now assumed to have root access
   - No more permission checking or fallback methods
   - Simplified code with a single approach (root)
   
3. **Enhanced Device Control**:
   - More reliable command execution via root
   - Direct file manipulation with root privileges
   - Proper handling of file permissions and ownership
   
4. **Improved Startup**:
   - Simplified startup using existing scripts
   - Removed unnecessary run_server scripts
   - Better logging showing ROOT MODE operation
   
5. **Problem Resolution**:
   - Fixed issues with problematic devices (e.g., R9WR310F4GJ)
   - Solved permission problems by using root exclusively
   - Consistent behavior across all device models and Android versions

## Documentation

New documentation has been added:

1. **ROOT_MODE_DOCUMENTATION.md**: Detailed explanation of ROOT MODE operation
2. **INSTALLATION.md**: Step-by-step installation guide
3. **API_REFERENCE.md**: Comprehensive API endpoint reference

## Usage Instructions

1. Run the appropriate startup script for your platform:
   - Windows: `start_server.bat`
   - Linux/macOS: `start_server.sh`

2. Access the web dashboard at: http://localhost:8000

3. Connect your Android devices via USB and ensure:
   - USB debugging is enabled
   - Root access is enabled
   - IMadeThatBitchFamous app is installed

4. Use the dashboard to control devices and distribute URLs

## Compatibility

The server now works exclusively with rooted Android devices that:
- Have USB debugging enabled
- Have root access enabled
- Are properly connected to the host computer
- Have the IMadeThatBitchFamous app installed

ROOT MODE ensures consistent behavior across all devices by bypassing standard permission models.

## Version 0.4.0 (Unreleased)

### Added
- New detailed timing information API endpoint at `/devices/{device_id}/timing`
- Enhanced ADB command `get_detailed_status` to extract precise timing information
- Added support for retrieving `actualElapsedMs` which accounts for paused time
- Added utility scripts for retrieving timing information:
  - `utils/timing_test.py` - Python script to monitor timing information
  - `utils/get_timing.sh` - Bash script to get timing directly via ADB
  - `utils/get_timing.bat` - Windows batch script to get timing directly via ADB
- Enhanced device status endpoint to include delay_min and delay_max parameters

### Changed
- Improved timing accuracy by accounting for paused time in elapsed time calculations
- Expanded API documentation with detailed timing information examples 

## Version 0.5.0 (Unreleased)

### Added
- Added extended interval endpoint `/settings/extended-interval/{minutes}` to set very long update intervals
- Added new documentation section on status update configuration
- Enhanced API with more explicit status update controls

### Changed
- Increased default status update interval from 15 minutes to 1 hour (3600 seconds)
- Disabled automatic status updates by default to reduce device lag
- Modified WebSocket behavior to only send status updates when explicitly requested
- Removed automatic status update on dashboard page load
- Updated dropdown default selection to 1 hour instead of 15 minutes 

### Fixed
- Addressed device lag issue caused by frequent status updates
- Improved performance on devices with limited resources by reducing update frequency 