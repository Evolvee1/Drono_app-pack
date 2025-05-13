import asyncio
from datetime import datetime
from typing import Dict, Optional
from sqlalchemy.orm import Session
from models.database_models import Device, DeviceMetrics
import logging
from .adb_controller import AdbController

logger = logging.getLogger(__name__)

class DeviceMonitor:
    def __init__(self, db: Session):
        self.db = db
        self.adb = AdbController()
        self.monitoring_tasks: Dict[str, asyncio.Task] = {}
        self.metrics_interval = 60  # seconds

    async def start_monitoring(self, device_id: str) -> None:
        """Start monitoring a device"""
        if device_id in self.monitoring_tasks:
            return

        self.monitoring_tasks[device_id] = asyncio.create_task(
            self._monitor_device(device_id)
        )
        logger.info(f"Started monitoring device {device_id}")

    async def stop_monitoring(self, device_id: str) -> None:
        """Stop monitoring a device"""
        if device_id in self.monitoring_tasks:
            self.monitoring_tasks[device_id].cancel()
            del self.monitoring_tasks[device_id]
            logger.info(f"Stopped monitoring device {device_id}")

    async def _monitor_device(self, device_id: str) -> None:
        """Monitor device health and collect metrics"""
        while True:
            try:
                # Check device connection
                if not await self._check_device_connection(device_id):
                    await self._update_device_status(device_id, "offline")
                    await asyncio.sleep(5)  # Wait before retrying
                    continue

                # Collect metrics
                metrics = await self._collect_device_metrics(device_id)
                if metrics:
                    await self._save_metrics(device_id, metrics)

                # Update device status
                await self._update_device_status(device_id, "online")

                # Check for anomalies
                await self._check_anomalies(device_id, metrics)

                await asyncio.sleep(self.metrics_interval)

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error monitoring device {device_id}: {str(e)}")
                await asyncio.sleep(5)

    async def _check_device_connection(self, device_id: str) -> bool:
        """Check if device is connected and responsive"""
        try:
            result = await self.adb.run_adb_command(f"devices | grep {device_id}")
            return result.success and device_id in result.stdout
        except Exception as e:
            logger.error(f"Error checking device connection: {str(e)}")
            return False

    async def _collect_device_metrics(self, device_id: str) -> Optional[Dict]:
        """Collect device metrics using ADB"""
        try:
            metrics = {}
            
            # CPU usage
            cpu_result = await self.adb.run_adb_command(
                f"-s {device_id} shell top -n 1 | grep -i 'cpu'"
            )
            if cpu_result.success:
                metrics["cpu_usage"] = self._parse_cpu_usage(cpu_result.stdout)

            # Memory usage
            mem_result = await self.adb.run_adb_command(
                f"-s {device_id} shell dumpsys meminfo | grep 'Total RAM'"
            )
            if mem_result.success:
                metrics["memory_usage"] = self._parse_memory_usage(mem_result.stdout)

            # Battery level
            battery_result = await self.adb.run_adb_command(
                f"-s {device_id} shell dumpsys battery | grep 'level'"
            )
            if battery_result.success:
                metrics["battery_level"] = self._parse_battery_level(battery_result.stdout)

            # Temperature
            temp_result = await self.adb.run_adb_command(
                f"-s {device_id} shell cat /sys/class/thermal/thermal_zone0/temp"
            )
            if temp_result.success:
                metrics["temperature"] = float(temp_result.stdout.strip()) / 1000.0

            return metrics

        except Exception as e:
            logger.error(f"Error collecting device metrics: {str(e)}")
            return None

    async def _save_metrics(self, device_id: str, metrics: Dict) -> None:
        """Save device metrics to database"""
        try:
            device_metrics = DeviceMetrics(
                device_id=device_id,
                timestamp=datetime.utcnow(),
                cpu_usage=metrics.get("cpu_usage"),
                memory_usage=metrics.get("memory_usage"),
                battery_level=metrics.get("battery_level"),
                temperature=metrics.get("temperature"),
                network_usage=metrics.get("network_usage"),
                custom_metrics=metrics.get("custom_metrics")
            )
            self.db.add(device_metrics)
            self.db.commit()
        except Exception as e:
            logger.error(f"Error saving device metrics: {str(e)}")
            self.db.rollback()

    async def _update_device_status(self, device_id: str, status: str) -> None:
        """Update device status in database"""
        try:
            device = self.db.query(Device).filter(Device.id == device_id).first()
            if device:
                device.status = status
                device.last_seen = datetime.utcnow()
                self.db.commit()
        except Exception as e:
            logger.error(f"Error updating device status: {str(e)}")
            self.db.rollback()

    async def _check_anomalies(self, device_id: str, metrics: Dict) -> None:
        """Check for anomalies in device metrics"""
        if not metrics:
            return

        # Define thresholds
        thresholds = {
            "cpu_usage": 90.0,  # 90% CPU usage
            "memory_usage": 90.0,  # 90% memory usage
            "battery_level": 10.0,  # 10% battery
            "temperature": 45.0  # 45°C
        }

        # Check each metric
        for metric, value in metrics.items():
            if metric in thresholds and value is not None:
                if value > thresholds[metric]:
                    logger.warning(
                        f"Anomaly detected for device {device_id}: "
                        f"{metric} = {value} (threshold: {thresholds[metric]})"
                    )
                    # TODO: Implement alerting system

    def _parse_cpu_usage(self, output: str) -> float:
        """Parse CPU usage from top command output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0

    def _parse_memory_usage(self, output: str) -> float:
        """Parse memory usage from dumpsys meminfo output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0

    def _parse_battery_level(self, output: str) -> float:
        """Parse battery level from dumpsys battery output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0 
from datetime import datetime
from typing import Dict, Optional
from sqlalchemy.orm import Session
from models.database_models import Device, DeviceMetrics
import logging
from .adb_controller import AdbController

logger = logging.getLogger(__name__)

class DeviceMonitor:
    def __init__(self, db: Session):
        self.db = db
        self.adb = AdbController()
        self.monitoring_tasks: Dict[str, asyncio.Task] = {}
        self.metrics_interval = 60  # seconds

    async def start_monitoring(self, device_id: str) -> None:
        """Start monitoring a device"""
        if device_id in self.monitoring_tasks:
            return

        self.monitoring_tasks[device_id] = asyncio.create_task(
            self._monitor_device(device_id)
        )
        logger.info(f"Started monitoring device {device_id}")

    async def stop_monitoring(self, device_id: str) -> None:
        """Stop monitoring a device"""
        if device_id in self.monitoring_tasks:
            self.monitoring_tasks[device_id].cancel()
            del self.monitoring_tasks[device_id]
            logger.info(f"Stopped monitoring device {device_id}")

    async def _monitor_device(self, device_id: str) -> None:
        """Monitor device health and collect metrics"""
        while True:
            try:
                # Check device connection
                if not await self._check_device_connection(device_id):
                    await self._update_device_status(device_id, "offline")
                    await asyncio.sleep(5)  # Wait before retrying
                    continue

                # Collect metrics
                metrics = await self._collect_device_metrics(device_id)
                if metrics:
                    await self._save_metrics(device_id, metrics)

                # Update device status
                await self._update_device_status(device_id, "online")

                # Check for anomalies
                await self._check_anomalies(device_id, metrics)

                await asyncio.sleep(self.metrics_interval)

            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Error monitoring device {device_id}: {str(e)}")
                await asyncio.sleep(5)

    async def _check_device_connection(self, device_id: str) -> bool:
        """Check if device is connected and responsive"""
        try:
            result = await self.adb.run_adb_command(f"devices | grep {device_id}")
            return result.success and device_id in result.stdout
        except Exception as e:
            logger.error(f"Error checking device connection: {str(e)}")
            return False

    async def _collect_device_metrics(self, device_id: str) -> Optional[Dict]:
        """Collect device metrics using ADB"""
        try:
            metrics = {}
            
            # CPU usage
            cpu_result = await self.adb.run_adb_command(
                f"-s {device_id} shell top -n 1 | grep -i 'cpu'"
            )
            if cpu_result.success:
                metrics["cpu_usage"] = self._parse_cpu_usage(cpu_result.stdout)

            # Memory usage
            mem_result = await self.adb.run_adb_command(
                f"-s {device_id} shell dumpsys meminfo | grep 'Total RAM'"
            )
            if mem_result.success:
                metrics["memory_usage"] = self._parse_memory_usage(mem_result.stdout)

            # Battery level
            battery_result = await self.adb.run_adb_command(
                f"-s {device_id} shell dumpsys battery | grep 'level'"
            )
            if battery_result.success:
                metrics["battery_level"] = self._parse_battery_level(battery_result.stdout)

            # Temperature
            temp_result = await self.adb.run_adb_command(
                f"-s {device_id} shell cat /sys/class/thermal/thermal_zone0/temp"
            )
            if temp_result.success:
                metrics["temperature"] = float(temp_result.stdout.strip()) / 1000.0

            return metrics

        except Exception as e:
            logger.error(f"Error collecting device metrics: {str(e)}")
            return None

    async def _save_metrics(self, device_id: str, metrics: Dict) -> None:
        """Save device metrics to database"""
        try:
            device_metrics = DeviceMetrics(
                device_id=device_id,
                timestamp=datetime.utcnow(),
                cpu_usage=metrics.get("cpu_usage"),
                memory_usage=metrics.get("memory_usage"),
                battery_level=metrics.get("battery_level"),
                temperature=metrics.get("temperature"),
                network_usage=metrics.get("network_usage"),
                custom_metrics=metrics.get("custom_metrics")
            )
            self.db.add(device_metrics)
            self.db.commit()
        except Exception as e:
            logger.error(f"Error saving device metrics: {str(e)}")
            self.db.rollback()

    async def _update_device_status(self, device_id: str, status: str) -> None:
        """Update device status in database"""
        try:
            device = self.db.query(Device).filter(Device.id == device_id).first()
            if device:
                device.status = status
                device.last_seen = datetime.utcnow()
                self.db.commit()
        except Exception as e:
            logger.error(f"Error updating device status: {str(e)}")
            self.db.rollback()

    async def _check_anomalies(self, device_id: str, metrics: Dict) -> None:
        """Check for anomalies in device metrics"""
        if not metrics:
            return

        # Define thresholds
        thresholds = {
            "cpu_usage": 90.0,  # 90% CPU usage
            "memory_usage": 90.0,  # 90% memory usage
            "battery_level": 10.0,  # 10% battery
            "temperature": 45.0  # 45°C
        }

        # Check each metric
        for metric, value in metrics.items():
            if metric in thresholds and value is not None:
                if value > thresholds[metric]:
                    logger.warning(
                        f"Anomaly detected for device {device_id}: "
                        f"{metric} = {value} (threshold: {thresholds[metric]})"
                    )
                    # TODO: Implement alerting system

    def _parse_cpu_usage(self, output: str) -> float:
        """Parse CPU usage from top command output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0

    def _parse_memory_usage(self, output: str) -> float:
        """Parse memory usage from dumpsys meminfo output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0

    def _parse_battery_level(self, output: str) -> float:
        """Parse battery level from dumpsys battery output"""
        try:
            # TODO: Implement proper parsing
            return 0.0
        except Exception:
            return 0.0 