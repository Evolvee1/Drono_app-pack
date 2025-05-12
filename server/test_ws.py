import asyncio
import websockets

async def test_websocket():
    try:
        print("Connecting to WebSocket...")
        async with websockets.connect('ws://localhost:8000/devices/ws') as websocket:
            print("WebSocket connection successful!")
            # Send a ping message
            await websocket.send('{"type": "ping", "data": {}}')
            print("Sent ping message")
            
            # Wait for response
            response = await websocket.recv()
            print(f"Received response: {response}")
            
            # Keep connection alive for a moment
            await asyncio.sleep(2)
            print("Test completed successfully!")
    except Exception as e:
        print(f"Error: {e}")

# Run the test
asyncio.run(test_websocket()) 