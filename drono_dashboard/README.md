# Drono Dashboard

A Flutter web dashboard for managing Drono devices and simulations.

## Features

- Device Management
  - View connected devices
  - Monitor device status
  - Execute commands
  - Configure device settings

- Command Execution
  - Start/stop simulations
  - Pause/resume operations
  - Monitor command status
  - View execution history

- Real-time Monitoring
  - Device status updates
  - Simulation progress
  - System alerts
  - Performance metrics

- Network Management
  - Network namespace configuration
  - Firewall rules
  - Device isolation
  - Connection status

## Setup

1. Install Flutter:
   ```bash
   # macOS
   brew install flutter
   ```

2. Clone the repository:
   ```bash
   git clone <repository-url>
   cd drono_dashboard
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Create `.env` file:
   ```
   API_BASE_URL=http://localhost:8000
   WS_URL=ws://localhost:8000/ws
   API_TIMEOUT=5000
   MAX_RETRIES=3
   RETRY_DELAY=1000
   CACHE_DURATION=300
   ```

5. Run the dashboard:
   ```bash
   flutter run -d chrome
   ```

## Development

- The dashboard is built using Flutter for web
- Uses Riverpod for state management
- Implements WebSocket for real-time updates
- Follows Material Design 3 guidelines

## Project Structure

```
lib/
  ├── core/
  │   └── config.dart
  ├── features/
  │   ├── auth/
  │   ├── devices/
  │   ├── commands/
  │   ├── monitoring/
  │   └── network/
  ├── shared/
  └── utils/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.


- Real-time Monitoring
  - Device status updates
  - Simulation progress
  - System alerts
  - Performance metrics

- Network Management
  - Network namespace configuration
  - Firewall rules
  - Device isolation
  - Connection status

## Setup

1. Install Flutter:
   ```bash
   # macOS
   brew install flutter
   ```

2. Clone the repository:
   ```bash
   git clone <repository-url>
   cd drono_dashboard
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Create `.env` file:
   ```
   API_BASE_URL=http://localhost:8000
   WS_URL=ws://localhost:8000/ws
   API_TIMEOUT=5000
   MAX_RETRIES=3
   RETRY_DELAY=1000
   CACHE_DURATION=300
   ```

5. Run the dashboard:
   ```bash
   flutter run -d chrome
   ```

## Development

- The dashboard is built using Flutter for web
- Uses Riverpod for state management
- Implements WebSocket for real-time updates
- Follows Material Design 3 guidelines

## Project Structure

```
lib/
  ├── core/
  │   └── config.dart
  ├── features/
  │   ├── auth/
  │   ├── devices/
  │   ├── commands/
  │   ├── monitoring/
  │   └── network/
  ├── shared/
  └── utils/
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.