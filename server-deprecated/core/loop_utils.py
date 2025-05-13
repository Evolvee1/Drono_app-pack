import asyncio
import logging
from typing import Optional, Callable, Coroutine, Any

logger = logging.getLogger(__name__)

class LoopManager:
    """Utility class to manage asyncio tasks and ensure they all run in the same event loop"""
    
    def __init__(self):
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._tasks = {}
    
    def get_loop(self) -> asyncio.AbstractEventLoop:
        """Get or create the event loop for this manager"""
        if self._loop is None:
            try:
                self._loop = asyncio.get_running_loop()
                logger.debug("Using existing event loop")
            except RuntimeError:
                self._loop = asyncio.new_event_loop()
                asyncio.set_event_loop(self._loop)
                logger.debug("Created new event loop")
        return self._loop
    
    def create_task(self, name: str, coro: Coroutine) -> asyncio.Task:
        """Create a task in the managed event loop"""
        loop = self.get_loop()
        task = loop.create_task(coro, name=name)
        self._tasks[name] = task
        logger.debug(f"Created task: {name}")
        return task
    
    async def cancel_task(self, name: str) -> bool:
        """Cancel a task by name"""
        if name in self._tasks:
            task = self._tasks[name]
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
            except Exception as e:
                logger.error(f"Error cancelling task {name}: {e}")
            del self._tasks[name]
            logger.debug(f"Cancelled task: {name}")
            return True
        return False
    
    def is_task_running(self, name: str) -> bool:
        """Check if a task is running"""
        return name in self._tasks and not self._tasks[name].done()

# Create a singleton instance
loop_manager = LoopManager() 