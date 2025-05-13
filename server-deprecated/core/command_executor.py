import asyncio
import logging
import os
import json
import subprocess
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Union, Any

from config.settings import DRONO_CONTROL_SCRIPT, PRESETS
from .adb_controller import adb_controller
from models.database_models import Command, Device
from .alerting import alert_manager

logger = logging.getLogger(__name__)

class CommandResult:
    def __init__(self, success: bool, output: str, error: str = None):
        self.success = success
        self.output = output
        self.error = error
        self.timestamp = datetime.now().isoformat()

    def to_dict(self):
        return {
            "success": self.success,
            "output": self.output,
            "error": self.error,
            "timestamp": self.timestamp
        }

class CommandExecutor:
    def __init__(self):
        self.adb = adb_controller
        self.script_path = DRONO_CONTROL_SCRIPT
        self._verify_script_exists()
        self.execution_tasks: Dict[str, asyncio.Task] = {}
        self.command_timeouts: Dict[str, int] = {
            "start": 300,  # 5 minutes
            "stop": 60,    # 1 minute
            "pause": 30,   # 30 seconds
            "resume": 30,  # 30 seconds
            "status": 10,  # 10 seconds
        }
        
    def _verify_script_exists(self):
        """Verify that the drono_control.sh script exists"""
        if not os.path.isfile(self.script_path):
            logger.warning(f"Drono control script not found at {self.script_path}, attempting to continue without it")
        elif not os.access(self.script_path, os.X_OK):
            raise PermissionError(f"Drono control script is not executable at {self.script_path}")
        else:
            logger.info(f"Drono control script verified at {self.script_path}")

    async def execute_command(self, command: Command) -> bool:
        """Execute a command on a device"""
        try:
            device_id = command.device_id
            command_type = command.type
            params = command.parameters or {}

            if not device_id:
                logger.error("Missing device_id")
                return False

            if command_type == "shell":
                # Execute shell command
                cmd_str = params.get("command", "")
                if not cmd_str:
                    logger.error("Missing shell command")
                    return False
                
                # Execute the command using ADB
                result = self.adb.execute_command(device_id, cmd_str)
                logger.info(f"Shell command executed successfully: {result}")
                return True
            else:
                # Handle other command types in specific methods
                return await self._execute_with_timeout(command, self.command_timeouts.get(command_type, 60))

        except Exception as e:
            logger.error(f"Failed to execute command: {e}")
            return False

    async def execute_command_with_retries(self, command: Command) -> bool:
        """Execute a command with retries and timeout"""
        device_id = command.device_id
        command_type = command.type
        parameters = command.parameters or {}

        # Get timeout for command type
        timeout = self.command_timeouts.get(command_type, 60)

        for attempt in range(3):
            try:
                # Execute with timeout
                result = await self._execute_with_timeout(command, timeout)
                
                if result:
                    logger.info(f"Command {command.id} executed successfully")
                    return True
                
                if attempt < 2:
                    logger.warning(
                        f"Command {command.id} failed, attempt {attempt + 1}/3. "
                        f"Retrying in 5 seconds..."
                    )
                    await asyncio.sleep(5)
                else:
                    logger.error(f"Command {command.id} failed after 3 attempts")
                    await alert_manager.send_alert(
                        "error",
                        f"Command {command_type} failed after 3 attempts",
                        device_id,
                        {"command_id": command.id, "parameters": parameters}
                    )
                    return False

            except asyncio.TimeoutError:
                logger.error(f"Command {command.id} timed out after {timeout} seconds")
                await alert_manager.send_alert(
                    "error",
                    f"Command {command_type} timed out",
                    device_id,
                    {"command_id": command.id, "timeout": timeout}
                )
                return False

            except Exception as e:
                logger.error(f"Error executing command {command.id}: {str(e)}")
                await alert_manager.send_alert(
                    "error",
                    f"Error executing command {command_type}",
                    device_id,
                    {"command_id": command.id, "error": str(e)}
                )
                return False

    async def _execute_with_timeout(self, command: Command, timeout: int) -> bool:
        """Execute a command with specific implementation"""
        command_type = command.type
        parameters = command.parameters or {}

        try:
            if command_type == "start":
                return await self._execute_start_command(command, parameters)
            elif command_type == "stop":
                return await self._execute_stop_command(command, parameters)
            elif command_type == "pause":
                return await self._execute_pause_command(command, parameters)
            elif command_type == "resume":
                return await self._execute_resume_command(command, parameters)
            elif command_type == "status":
                return await self._execute_status_command(command, parameters)
            else:
                logger.error(f"Unknown command type: {command_type}")
                return False

        except Exception as e:
            logger.error(f"Error in command execution: {str(e)}")
            return False

    async def _execute_start_command(self, command: Command, parameters: Dict[str, Any]) -> bool:
        """Execute start command"""
        try:
            # Build command for drono_control.sh
            script_cmd = [self.script_path]
            
            # Add -settings flag to ensure app is force-stopped before applying settings
            script_cmd.append("-settings")
            
            # Check for dismiss_restore flag
            if parameters.get("dismiss_restore"):
                script_cmd.append("dismiss_restore")
                
            # Add core parameters in key-value format
            url = parameters.get("url")
            if url:
                script_cmd.extend(["url", url])
                
            iterations = parameters.get("iterations")
            if iterations:
                script_cmd.extend(["iterations", str(iterations)])
                
            min_interval = parameters.get("min_interval")
            if min_interval:
                script_cmd.extend(["min_interval", str(min_interval)])
                
            max_interval = parameters.get("max_interval")
            if max_interval:
                script_cmd.extend(["max_interval", str(max_interval)])
            
            # Add toggle parameters in correct format: toggle <feature> <true|false>
            webview_mode = parameters.get("webview_mode")
            if webview_mode is not None:
                script_cmd.extend(["toggle", "webview_mode", str(webview_mode).lower()])
                
            rotate_ip = parameters.get("rotate_ip")
            if rotate_ip is not None:
                script_cmd.extend(["toggle", "rotate_ip", str(rotate_ip).lower()])
                
            random_devices = parameters.get("random_devices")
            if random_devices is not None:
                script_cmd.extend(["toggle", "random_devices", str(random_devices).lower()])
                
            aggressive_clearing = parameters.get("aggressive_clearing")
            if aggressive_clearing is not None:
                script_cmd.extend(["toggle", "aggressive_clearing", str(aggressive_clearing).lower()])
            
            # Add the start command at the end
            script_cmd.append("start")
            
            # Log the full command
            logger.info(f"Executing command: {' '.join(script_cmd)}")
            
            # Execute the script
            process = await asyncio.create_subprocess_exec(
                *script_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            # Check if the script ran successfully
            success = process.returncode == 0
            if success:
                logger.info(f"Start command executed successfully: {stdout.decode()}")
            else:
                logger.error(f"Start command failed: {stderr.decode()}")
                
            return success
        except Exception as e:
            logger.error(f"Error in start command: {str(e)}")
            return False

    async def _execute_stop_command(self, command: Command, parameters: Dict[str, Any]) -> bool:
        """Execute stop command"""
        try:
            cmd = ["shell", "am", "broadcast", "-a", "com.example.imtbf.STOP_SIMULATION"]
            result = await self.adb.run_adb_command(command.device_id, cmd)
            return result["success"]

        except Exception as e:
            logger.error(f"Error in stop command: {str(e)}")
            return False

    async def _execute_pause_command(self, command: Command, parameters: Dict[str, Any]) -> bool:
        """Execute pause command"""
        try:
            cmd = ["shell", "am", "broadcast", "-a", "com.example.imtbf.PAUSE_SIMULATION"]
            result = await self.adb.run_adb_command(command.device_id, cmd)
            return result["success"]

        except Exception as e:
            logger.error(f"Error in pause command: {str(e)}")
            return False

    async def _execute_resume_command(self, command: Command, parameters: Dict[str, Any]) -> bool:
        """Execute resume command"""
        try:
            cmd = ["shell", "am", "broadcast", "-a", "com.example.imtbf.RESUME_SIMULATION"]
            result = await self.adb.run_adb_command(command.device_id, cmd)
            return result["success"]

        except Exception as e:
            logger.error(f"Error in resume command: {str(e)}")
            return False

    async def _execute_status_command(self, command: Command, parameters: Dict[str, Any]) -> bool:
        """Execute status command"""
        try:
            cmd = ["shell", "am", "broadcast", "-a", "com.example.imtbf.GET_STATUS"]
            result = await self.adb.run_adb_command(command.device_id, cmd)
            return result["success"]

        except Exception as e:
            logger.error(f"Error in status command: {str(e)}")
            return False

    async def cancel_command(self, command_id: str) -> bool:
        """Cancel a running command"""
        if command_id in self.execution_tasks:
            task = self.execution_tasks[command_id]
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                logger.info(f"Command {command_id} cancelled successfully")
                return True
        return False

    async def start_simulation(self, device_id: str, preset: str = None, 
                              custom_params: Dict[str, Any] = None,
                              dryrun: bool = False) -> CommandResult:
        """Start a simulation using either a preset or custom parameters"""
        params = {}
        
        # Apply preset if specified
        if preset and preset in PRESETS:
            preset_config = PRESETS[preset]
            params.update({
                "url": preset_config["url"],
                "iterations": preset_config["iterations"],
                "min_interval": preset_config["min_interval"],
                "max_interval": preset_config["max_interval"]
            })
            
            # Add feature flags
            for feature, enabled in preset_config["features"].items():
                if enabled:
                    params[feature] = True
        
        # Override with custom parameters if provided
        if custom_params:
            params.update(custom_params)
        
        # Always add settings flag and dismiss_restore flag
        params["settings"] = True
        params["dismiss_restore"] = True
        
        # Create command and execute
        cmd = Command(
            id=f"sim_{device_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            device_id=device_id,
            type="start",
            parameters=params
        )
        
        success = await self.execute_command_with_retries(cmd)
        return CommandResult(success, "Simulation started" if success else "Failed to start simulation")

    async def stop_simulation(self, device_id: str) -> CommandResult:
        """Stop a running simulation"""
        cmd = Command(
            id=f"stop_{device_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            device_id=device_id,
            type="stop",
            parameters={}
        )
        
        success = await self.execute_command_with_retries(cmd)
        return CommandResult(success, "Simulation stopped" if success else "Failed to stop simulation")

    async def pause_simulation(self, device_id: str) -> CommandResult:
        """Pause a running simulation"""
        cmd = Command(
            id=f"pause_{device_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            device_id=device_id,
            type="pause",
            parameters={}
        )
        
        success = await self.execute_command_with_retries(cmd)
        return CommandResult(success, "Simulation paused" if success else "Failed to pause simulation")

    async def resume_simulation(self, device_id: str) -> CommandResult:
        """Resume a paused simulation"""
        cmd = Command(
            id=f"resume_{device_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            device_id=device_id,
            type="resume",
            parameters={}
        )
        
        success = await self.execute_command_with_retries(cmd)
        return CommandResult(success, "Simulation resumed" if success else "Failed to resume simulation")

    async def get_status(self, device_id: str) -> CommandResult:
        """Get the status of the simulation"""
        cmd = Command(
            id=f"status_{device_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            device_id=device_id,
            type="status",
            parameters={}
        )
        
        success = await self.execute_command_with_retries(cmd)
        return CommandResult(success, "Status requested" if success else "Failed to request status")

# Create a singleton instance
command_executor = CommandExecutor()
