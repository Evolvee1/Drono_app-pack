# Instagram URL Manager - Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           INSTAGRAM URL MANAGER                          │
└─────────────────────────────────────────────────────────────────────────┘
                                     │
                 ┌──────────────────┬┴┬──────────────────┐
                 │                  │ │                  │
                 ▼                  ▼ │                  ▼
┌───────────────────────┐ ┌──────────┴─────────┐ ┌───────────────────────┐
│       API LAYER       │ │     CORE LAYER     │ │    COMMAND LAYER      │
└───────────────────────┘ └────────────────────┘ └───────────────────────┘
│                       │ │                    │ │                       │
│ - Instagram Routes    │ │ - Instagram Manager│ │ - CLI Tool            │
│   ┌────────────────┐ │ │   ┌──────────────┐ │ │   ┌────────────────┐  │
│   │/instagram/     │ │ │   │Device Mgmt   │ │ │   │instagram_cli.py│  │
│   │devices         │◄┼─┼─┼─►              │◄┼─┼─┼─►                │  │
│   └────────────────┘ │ │   └──────────────┘ │ │   └────────────────┘  │
│   ┌────────────────┐ │ │   ┌──────────────┐ │ │   ┌────────────────┐  │
│   │/instagram/     │ │ │   │File Creation │ │ │   │Shell Script    │  │
│   │set-url         │◄┼─┼─┼─►& Pushing     │◄┼─┼─┼─►Wrapper         │  │
│   └────────────────┘ │ │   └──────────────┘ │ │   └────────────────┘  │
│   ┌────────────────┐ │ │   ┌──────────────┐ │ │                       │
│   │/instagram/     │ │ │   │Broadcast     │ │ │                       │
│   │restart-app     │◄┼─┼─┼─►Commands      │ │ │                       │
│   └────────────────┘ │ │   └──────────────┘ │ │                       │
│                      │ │   ┌──────────────┐ │ │                       │
│                      │ │   │App Launch    │ │ │                       │
│                      │ │   │& Verification│ │ │                       │
│                      │ │   └──────────────┘ │ │                       │
└──────────────────────┘ └────────────────────┘ └───────────────────────┘
                 │                  │                  │
                 └──────────────────┼──────────────────┘
                                    │
                                    ▼
                         ┌────────────────────┐
                         │    ANDROID DEVICE  │
                         └────────────────────┘
                         │  ┌──────────────┐  │
                         │  │  URL Config  │  │
                         │  │  XML Files   │  │
                         │  └──────────────┘  │
                         │  ┌──────────────┐  │
                         │  │  App with    │  │
                         │  │  WebView     │  │
                         │  └──────────────┘  │
                         └────────────────────┘
```

## Components Explanation

### 1. API Layer

The API layer provides REST endpoints through FastAPI:

- `/instagram/devices` - Get connected devices
- `/instagram/set-url` - Set URL asynchronously
- `/instagram/set-url-sync` - Set URL synchronously
- `/instagram/restart-app` - Restart the app
- `/instagram/device/{id}/status` - Get device status
- `/instagram/device/{id}/set-url` - Set URL on specific device

This layer interacts with the core by directly calling its methods, without any HTTP/REST calls in between.

### 2. Core Layer

The core layer contains the `instagram_manager` singleton which provides:

- **Device Management**: Find and manage Android devices
- **File Creation & Pushing**: Generate and push XML config files
- **Broadcast Commands**: Send intents to set URL and features
- **App Launch & Verification**: Start app with URL and verify loading

This is the central component that all other parts interact with.

### 3. Command Layer

The command layer provides command-line tools:

- **CLI Tool** (`instagram_cli.py`): Command-line interface with multiple commands
- **Shell Script** (`set_instagram_url.sh`): Simple shell script wrapper

These tools use the core layer directly to provide functionality.

### 4. Android Device

The Android device receives:

- **Configuration Files**: XML files with URL and settings
- **Broadcast Intents**: Commands to set URL and features
- **Launch Intents**: Direct app launches with URL

The combination of these methods ensures the URL is properly set.

## Data Flow

1. **User Request** → API or Command Interface
2. **Command Processing** → Core Manager
3. **Device Operations** → Multiple simultaneous methods:
   - Configuration file creation and pushing
   - Broadcast commands
   - Direct app launch
4. **Verification** → Check that URL is properly loaded
5. **Response** → Success/failure result to user

## Key Benefits

1. **Unified Architecture**: One central module handles all functionality
2. **Direct Integration**: No HTTP/REST overhead between components
3. **Multiple Interfaces**: API, CLI, and direct module access
4. **Simultaneous Methods**: Several approaches used together for reliability
5. **Verification**: Built-in checking that URL was properly loaded 