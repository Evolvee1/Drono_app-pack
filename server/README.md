# Drono Control Server

A FastAPI-based server for controlling Android devices running the Drono simulation app. The server provides a REST API and WebSocket interface for device management, command execution, and real-time monitoring.

## Features

- Device Management
  - Device discovery and status monitoring
  - Real-time device status updates via WebSocket
  - Device property management

- Command Execution
  - Start/stop/pause/resume simulations
  - Configure simulation parameters
  - Command execution with retry mechanism
  - Parallel command execution

- Real-time Monitoring
  - Device status monitoring
  - Simulation progress tracking
  - Alert system for errors and status changes
  - WebSocket-based real-time updates

- Security
  - JWT-based authentication
  - Role-based access control
  - Rate limiting
  - Input validation

## Prerequisites

- Python 3.8+
- ADB (Android Debug Bridge)
- PostgreSQL (for persistent storage)
- Redis (for caching and rate limiting)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/drono-control-server.git
cd drono-control-server
```

2. Create and activate a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Create a `.env` file with the following configuration:
```env
SECRET_KEY=your-secret-key-here
DATABASE_URL=postgresql://user:password@localhost/drono
REDIS_URL=redis://localhost:6379
DEBUG=True
```

5. Initialize the database:
```bash
alembic upgrade head
```

## Running the Server

Start the server with:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The server will be available at:
- API: http://localhost:8000
- API Documentation: http://localhost:8000/docs
- WebSocket: ws://localhost:8000/ws/{channel}

## API Usage

### Authentication

1. Get an access token:
```bash
curl -X POST "http://localhost:8000/auth/token" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=user&password=pass"
```

2. Use the token in subsequent requests:
```bash
curl -X GET "http://localhost:8000/devices" \
     -H "Authorization: Bearer {token}"
```

### Device Management

1. Scan for devices:
```bash
curl -X POST "http://localhost:8000/devices/scan" \
     -H "Authorization: Bearer {token}"
```

2. Get device list:
```bash
curl -X GET "http://localhost:8000/devices" \
     -H "Authorization: Bearer {token}"
```

### Command Execution

1. Start a simulation:
```bash
curl -X POST "http://localhost:8000/commands/{device_id}" \
     -H "Authorization: Bearer {token}" \
     -H "Content-Type: application/json" \
     -d '{
       "type": "start",
       "parameters": {
         "url": "https://example.com",
         "iterations": 10,
         "delay": 5
       }
     }'
```

### WebSocket Connection

Connect to the WebSocket endpoint for real-time updates:

```javascript
const ws = new WebSocket('ws://localhost:8000/ws/devices');
ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};
```

## Monitoring

The server provides several monitoring endpoints:

- Health check: `GET /health`
- Metrics: `GET /metrics` (Prometheus format)

## Error Handling

The server implements comprehensive error handling:

- HTTP exceptions are logged and reported via the alert system
- Command execution failures are retried automatically
- WebSocket connection errors are handled gracefully

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.


The server implements comprehensive error handling:

- HTTP exceptions are logged and reported via the alert system
- Command execution failures are retried automatically
- WebSocket connection errors are handled gracefully

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.