import asyncio
from typing import Dict, List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from models.database_models import Command, Device
import logging

logger = logging.getLogger(__name__)

class CommandQueue:
    def __init__(self):
        self.queues: Dict[str, asyncio.PriorityQueue] = {}
        self.running_commands: Dict[str, Command] = {}
        self.locks: Dict[str, asyncio.Lock] = {}

    async def add_command(self, db: Session, command: Command) -> None:
        """Add a command to the queue for a specific device"""
        device_id = command.device_id
        
        # Create queue and lock if they don't exist
        if device_id not in self.queues:
            self.queues[device_id] = asyncio.PriorityQueue()
            self.locks[device_id] = asyncio.Lock()
        
        # Add command to queue with priority
        await self.queues[device_id].put((-command.priority, command))
        logger.info(f"Added command {command.id} to queue for device {device_id}")

    async def process_queue(self, db: Session, device_id: str) -> None:
        """Process commands in the queue for a specific device"""
        if device_id not in self.queues:
            return

        async with self.locks[device_id]:
            while not self.queues[device_id].empty():
                # Get next command
                _, command = await self.queues[device_id].get()
                
                try:
                    # Update command status
                    command.status = "running"
                    command.started_at = datetime.utcnow()
                    db.commit()
                    
                    # Execute command
                    # TODO: Implement actual command execution
                    await self._execute_command(command)
                    
                    # Update command status
                    command.status = "completed"
                    command.completed_at = datetime.utcnow()
                    db.commit()
                    
                except Exception as e:
                    logger.error(f"Error executing command {command.id}: {str(e)}")
                    command.status = "failed"
                    command.error = str(e)
                    command.completed_at = datetime.utcnow()
                    db.commit()
                
                finally:
                    self.queues[device_id].task_done()

    async def _execute_command(self, command: Command) -> None:
        """Execute a command"""
        # TODO: Implement actual command execution logic
        await asyncio.sleep(1)  # Placeholder

    def get_queue_status(self, device_id: str) -> Dict:
        """Get the status of the command queue for a device"""
        if device_id not in self.queues:
            return {"queue_size": 0, "running_command": None}
        
        return {
            "queue_size": self.queues[device_id].qsize(),
            "running_command": self.running_commands.get(device_id)
        }

    def clear_queue(self, device_id: str) -> None:
        """Clear the command queue for a device"""
        if device_id in self.queues:
            while not self.queues[device_id].empty():
                self.queues[device_id].get_nowait()
                self.queues[device_id].task_done()
            logger.info(f"Cleared command queue for device {device_id}")

# Global command queue instance
command_queue = CommandQueue() 
from typing import Dict, List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from models.database_models import Command, Device
import logging

logger = logging.getLogger(__name__)

class CommandQueue:
    def __init__(self):
        self.queues: Dict[str, asyncio.PriorityQueue] = {}
        self.running_commands: Dict[str, Command] = {}
        self.locks: Dict[str, asyncio.Lock] = {}

    async def add_command(self, db: Session, command: Command) -> None:
        """Add a command to the queue for a specific device"""
        device_id = command.device_id
        
        # Create queue and lock if they don't exist
        if device_id not in self.queues:
            self.queues[device_id] = asyncio.PriorityQueue()
            self.locks[device_id] = asyncio.Lock()
        
        # Add command to queue with priority
        await self.queues[device_id].put((-command.priority, command))
        logger.info(f"Added command {command.id} to queue for device {device_id}")

    async def process_queue(self, db: Session, device_id: str) -> None:
        """Process commands in the queue for a specific device"""
        if device_id not in self.queues:
            return

        async with self.locks[device_id]:
            while not self.queues[device_id].empty():
                # Get next command
                _, command = await self.queues[device_id].get()
                
                try:
                    # Update command status
                    command.status = "running"
                    command.started_at = datetime.utcnow()
                    db.commit()
                    
                    # Execute command
                    # TODO: Implement actual command execution
                    await self._execute_command(command)
                    
                    # Update command status
                    command.status = "completed"
                    command.completed_at = datetime.utcnow()
                    db.commit()
                    
                except Exception as e:
                    logger.error(f"Error executing command {command.id}: {str(e)}")
                    command.status = "failed"
                    command.error = str(e)
                    command.completed_at = datetime.utcnow()
                    db.commit()
                
                finally:
                    self.queues[device_id].task_done()

    async def _execute_command(self, command: Command) -> None:
        """Execute a command"""
        # TODO: Implement actual command execution logic
        await asyncio.sleep(1)  # Placeholder

    def get_queue_status(self, device_id: str) -> Dict:
        """Get the status of the command queue for a device"""
        if device_id not in self.queues:
            return {"queue_size": 0, "running_command": None}
        
        return {
            "queue_size": self.queues[device_id].qsize(),
            "running_command": self.running_commands.get(device_id)
        }

    def clear_queue(self, device_id: str) -> None:
        """Clear the command queue for a device"""
        if device_id in self.queues:
            while not self.queues[device_id].empty():
                self.queues[device_id].get_nowait()
                self.queues[device_id].task_done()
            logger.info(f"Cleared command queue for device {device_id}")

# Global command queue instance
command_queue = CommandQueue() 