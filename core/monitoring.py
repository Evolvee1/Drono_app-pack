import asyncio
import logging
from typing import Dict, Optional
from datetime import datetime, timedelta
from models.database_models import Device, DeviceStatus, Simulation, SimulationStatus
from .alerting import alert_manager
from .websocket_manager import websocket_manager
from .loop_utils import loop_manager

logger = logging.getLogger(__name__)

class DeviceMonitor:
    def __init__(self, check_interval: int = 30):
        self.devices: Dict[str, Device] = {}
        self.check_interval = check_interval
        self.monitoring_task = None
        self.last_check: Dict[str, datetime] = {}
        self._loop = None

    async def start(self):
        """Start the device monitoring task"""
        if not self.monitoring_task:
            # Get the current event loop using loop_manager
            self._loop = loop_manager.get_loop()
            self.monitoring_task = self._loop.create_task(self._monitor_devices())
            logger.info("Device monitoring task started")

    async def stop(self):
        """Stop the device monitoring task"""
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
            self.monitoring_task = None
            logger.info("Device monitoring task stopped")

    def register_device(self, device: Device):
        """Register a new device for monitoring"""
        self.devices[device.id] = device
        self.last_check[device.id] = datetime.utcnow()
        logger.info(f"Registered device: {device.id} - {device.model}")

    def unregister_device(self, device_id: str):
        """Unregister a device from monitoring"""
        if device_id in self.devices:
            del self.devices[device_id]
        if device_id in self.last_check:
            del self.last_check[device_id]
        logger.info(f"Unregistered device: {device_id}")

    async def _monitor_devices(self):
        """Monitor device status"""
        logger.info("Starting device monitoring loop")
        while True:
            try:
                for device_id, device in self.devices.items():
                    try:
                        # Check if device is still connected
                        is_online = await self._check_device_online(device_id)
                        
                        # Update device status
                        new_status = DeviceStatus.ONLINE if is_online else DeviceStatus.OFFLINE
                        if device.status != new_status:
                            device.status = new_status
                            device.last_seen = datetime.utcnow()
                            
                            # Broadcast status update
                            await websocket_manager.broadcast_device_status(device_id, device)
                            
                            # Send alert
                            if not is_online:
                                await alert_manager.send_alert(
                                    "warning",
                                    f"Device {device_id} went offline",
                                    device_id
                                )
                            else:
                                await alert_manager.send_alert(
                                    "info",
                                    f"Device {device_id} came online",
                                    device_id
                                )
                        
                        self.last_check[device_id] = datetime.utcnow()
                        
                    except Exception as e:
                        logger.error(f"Error monitoring device {device_id}: {str(e)}")
                        await alert_manager.send_alert(
                            "error",
                            f"Error monitoring device {device_id}: {str(e)}",
                            device_id
                        )
                
                await asyncio.sleep(self.check_interval)
                
            except asyncio.CancelledError:
                logger.info("Device monitoring loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error in device monitoring: {str(e)}")
                await asyncio.sleep(self.check_interval)

    async def _check_device_online(self, device_id: str) -> bool:
        """Check if a device is online"""
        try:
            # Here you would typically use ADB to check device status
            # For now, we'll just check if the device was seen recently
            last_seen = self.last_check.get(device_id)
            if last_seen and datetime.utcnow() - last_seen < timedelta(minutes=5):
                return True
            return False
        except Exception as e:
            logger.error(f"Error checking device {device_id} status: {str(e)}")
            return False

class SimulationMonitor:
    def __init__(self, check_interval: int = 10):
        self.simulations: Dict[str, Simulation] = {}
        self.check_interval = check_interval
        self.monitoring_task = None
        self._loop = None

    async def start(self):
        """Start the simulation monitoring task"""
        if not self.monitoring_task:
            # Get the current event loop using loop_manager
            self._loop = loop_manager.get_loop()
            self.monitoring_task = self._loop.create_task(self._monitor_simulations())
            logger.info("Simulation monitoring task started")

    async def stop(self):
        """Stop the simulation monitoring task"""
        if self.monitoring_task:
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass
            self.monitoring_task = None
            logger.info("Simulation monitoring task stopped")

    def register_simulation(self, simulation: Simulation):
        """Register a new simulation for monitoring"""
        self.simulations[simulation.id] = simulation
        logger.info(f"Registered simulation: {simulation.id} for device {simulation.device_id}")

    def unregister_simulation(self, simulation_id: str):
        """Unregister a simulation from monitoring"""
        if simulation_id in self.simulations:
            del self.simulations[simulation_id]
            logger.info(f"Unregistered simulation: {simulation_id}")

    async def _monitor_simulations(self):
        """Monitor simulation progress"""
        logger.info("Starting simulation monitoring loop")
        while True:
            try:
                for simulation_id, simulation in self.simulations.items():
                    try:
                        if simulation.status == SimulationStatus.RUNNING:
                            # Get current progress
                            progress = await self._get_simulation_progress(simulation)
                            
                            # Update simulation status
                            if progress["status"] != simulation.status:
                                simulation.status = progress["status"]
                                if progress["status"] == SimulationStatus.COMPLETED:
                                    simulation.end_time = datetime.utcnow()
                                elif progress["status"] == SimulationStatus.ERROR:
                                    simulation.error = progress.get("error")
                            
                            # Update progress
                            simulation.current_iteration = progress["current_iteration"]
                            simulation.progress = progress["progress"]
                            
                            # Broadcast progress update
                            await websocket_manager.broadcast_simulation_progress(
                                simulation.device_id,
                                {
                                    "simulation_id": simulation.id,
                                    "current_iteration": simulation.current_iteration,
                                    "total_iterations": simulation.total_iterations,
                                    "progress": simulation.progress,
                                    "status": simulation.status.value,
                                    "error": simulation.error
                                }
                            )
                            
                            # Send alerts for status changes
                            if progress["status"] == SimulationStatus.COMPLETED:
                                await alert_manager.send_alert(
                                    "info",
                                    f"Simulation {simulation_id} completed",
                                    simulation.device_id,
                                    {"simulation_id": simulation_id}
                                )
                            elif progress["status"] == SimulationStatus.ERROR:
                                await alert_manager.send_alert(
                                    "error",
                                    f"Simulation {simulation_id} failed: {progress.get('error')}",
                                    simulation.device_id,
                                    {"simulation_id": simulation_id, "error": progress.get("error")}
                                )
                        
                    except Exception as e:
                        logger.error(f"Error monitoring simulation {simulation_id}: {str(e)}")
                        await alert_manager.send_alert(
                            "error",
                            f"Error monitoring simulation {simulation_id}: {str(e)}",
                            simulation.device_id
                        )
                
                await asyncio.sleep(self.check_interval)
                
            except asyncio.CancelledError:
                logger.info("Simulation monitoring loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error in simulation monitoring: {str(e)}")
                await asyncio.sleep(self.check_interval)

    async def _get_simulation_progress(self, simulation: Simulation) -> Dict:
        """Get the current progress of a simulation"""
        try:
            # Here you would typically use ADB to get simulation progress
            # For now, we'll return a mock progress
            return {
                "status": simulation.status,
                "current_iteration": simulation.current_iteration,
                "progress": simulation.progress,
                "error": simulation.error
            }
        except Exception as e:
            logger.error(f"Error getting simulation progress: {str(e)}")
            return {
                "status": SimulationStatus.ERROR,
                "current_iteration": simulation.current_iteration,
                "progress": simulation.progress,
                "error": str(e)
            }

# Global monitor instances
device_monitor = DeviceMonitor()
simulation_monitor = SimulationMonitor() 