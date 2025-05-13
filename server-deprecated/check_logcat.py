#!/usr/bin/env python3
import asyncio
import re
import sys
import os
from core.adb_controller import AdbController

async def get_progress():
    device_id = "R9WR310F4GJ"  # Replace with your device ID
    adb = AdbController()
    
    try:
        # Get progress from logcat
        output = await adb.execute_adb_command(
            device_id, 
            ["logcat", "-d", "-t", "100", "-e", "Progress:"]
        )
        
        # Parse the progress
        progress_matches = re.findall(r"Progress: (\d+)/(\d+)", output)
        if progress_matches:
            # Sort by iteration number to get the highest (most recent)
            sorted_matches = sorted(progress_matches, key=lambda x: int(x[0]), reverse=True)
            current = int(sorted_matches[0][0])  # Get the highest iteration
            total = int(sorted_matches[0][1])
            print(f"Latest progress from logcat: {current}/{total}")
        else:
            print("No progress information found in logcat")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(get_progress()) 