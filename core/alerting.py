import asyncio
from typing import Dict, List, Optional, Any
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging
import os
from dotenv import load_dotenv
from models.database_models import Alert, AlertType
from core.loop_utils import loop_manager

load_dotenv()

logger = logging.getLogger(__name__)

class AlertManager:
    def __init__(self):
        self.alert_levels = {
            "info": 0,
            "warning": 1,
            "error": 2,
            "critical": 3
        }
        self.alert_handlers: Dict[str, List[callable]] = {
            "info": [],
            "warning": [],
            "error": [],
            "critical": []
        }
        self.alert_history: List[Dict] = []
        self.max_history = 1000
        self.alert_handlers = []
        self.alert_queue = None
        self.processing_task = None
        self._loop = None

    def add_alert_handler(self, level: str, handler: callable) -> None:
        """Add an alert handler for a specific level"""
        if level in self.alert_levels:
            self.alert_handlers[level].append(handler)

    async def start(self):
        """Start the alert processing task"""
        if not self.processing_task:
            # Get the current event loop using loop_manager
            self._loop = loop_manager.get_loop()
            # Create queue in the same event loop
            self.alert_queue = await loop_manager.create_queue()
            self.processing_task = self._loop.create_task(self._process_alerts())
            logger.info("Alert processing task started")

    async def stop(self):
        """Stop the alert processing task"""
        if self.processing_task:
            self.processing_task.cancel()
            try:
                await self.processing_task
            except asyncio.CancelledError:
                pass
            self.processing_task = None
            logger.info("Alert processing task stopped")

    def register_handler(self, handler):
        """Register a new alert handler"""
        self.alert_handlers.append(handler)

    @loop_manager.ensure_same_loop
    async def send_alert(self, alert_type: str, message: str, device_id: Optional[str] = None,
                        details: Optional[Dict[str, Any]] = None):
        """Send an alert to all registered handlers"""
        if not self.alert_queue:
            logger.warning("Alert queue not initialized. Call start() first.")
            return
            
        alert = Alert(
            type=AlertType(alert_type),
            message=message,
            device_id=device_id,
            details=details or {},
            timestamp=datetime.utcnow()
        )
        
        try:
            await self.alert_queue.put(alert)
        except Exception as e:
            logger.error(f"Failed to put alert in queue: {e}")

    async def _process_alerts(self):
        """Process alerts from the queue"""
        logger.info("Starting alert processing loop")
        while True:
            try:
                alert = await self.alert_queue.get()
                for handler in self.alert_handlers:
                    try:
                        await handler.handle_alert(alert)
                    except Exception as e:
                        logger.error(f"Error in alert handler: {str(e)}")
                self.alert_queue.task_done()
            except asyncio.CancelledError:
                logger.info("Alert processing loop cancelled")
                break
            except Exception as e:
                logger.error(f"Error processing alert: {str(e)}")

    def get_alert_history(self, level: Optional[str] = None,
                         device_id: Optional[str] = None,
                         limit: int = 100) -> List[Dict]:
        """Get alert history with optional filtering"""
        filtered = self.alert_history

        if level:
            filtered = [a for a in filtered if a["level"] == level]
        if device_id:
            filtered = [a for a in filtered if a["device_id"] == device_id]

        return filtered[-limit:]

class EmailAlertHandler:
    def __init__(self, smtp_server: str, smtp_port: int,
                 username: str, password: str,
                 from_email: str, to_emails: List[str]):
        self.smtp_server = smtp_server
        self.smtp_port = smtp_port
        self.username = username
        self.password = password
        self.from_email = from_email
        self.to_emails = to_emails

    async def handle_alert(self, alert: Dict) -> None:
        """Handle an alert by sending an email"""
        try:
            msg = MIMEMultipart()
            msg["From"] = self.from_email
            msg["To"] = ", ".join(self.to_emails)
            msg["Subject"] = f"[{alert['level'].upper()}] Drono Alert"

            body = f"""
            Alert Level: {alert['level']}
            Time: {alert['timestamp']}
            Message: {alert['message']}
            Device ID: {alert['device_id']}
            Details: {alert['details']}
            """

            msg.attach(MIMEText(body, "plain"))

            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)

            logger.info(f"Alert email sent: {alert['message']}")

        except Exception as e:
            logger.error(f"Error sending alert email: {str(e)}")

class WebhookAlertHandler:
    def __init__(self, webhook_url: str):
        self.webhook_url = webhook_url

    async def handle_alert(self, alert: Dict) -> None:
        """Handle an alert by sending a webhook"""
        try:
            # TODO: Implement webhook sending
            pass
        except Exception as e:
            logger.error(f"Error sending webhook alert: {str(e)}")

class LoggingAlertHandler:
    """Alert handler that logs alerts to the system log"""
    async def handle_alert(self, alert: Alert):
        log_message = f"[{alert.type.value}] {alert.message}"
        if alert.device_id:
            log_message = f"[Device: {alert.device_id}] {log_message}"
        if alert.details:
            log_message = f"{log_message} Details: {alert.details}"

        if alert.type == AlertType.ERROR:
            logger.error(log_message)
        elif alert.type == AlertType.WARNING:
            logger.warning(log_message)
        else:
            logger.info(log_message)

class WebSocketAlertHandler:
    """Alert handler that broadcasts alerts to connected WebSocket clients"""
    def __init__(self, websocket_manager):
        self.websocket_manager = websocket_manager

    async def handle_alert(self, alert: Alert):
        await self.websocket_manager.broadcast_alert(alert)

# Create global alert manager instance
alert_manager = AlertManager()

# Initialize email handler if configured
if os.getenv("SMTP_SERVER"):
    email_handler = EmailAlertHandler(
        smtp_server=os.getenv("SMTP_SERVER"),
        smtp_port=int(os.getenv("SMTP_PORT", "587")),
        username=os.getenv("SMTP_USERNAME"),
        password=os.getenv("SMTP_PASSWORD"),
        from_email=os.getenv("ALERT_FROM_EMAIL"),
        to_emails=os.getenv("ALERT_TO_EMAILS", "").split(",")
    )
    alert_manager.add_alert_handler("warning", email_handler.handle_alert)
    alert_manager.add_alert_handler("error", email_handler.handle_alert)
    alert_manager.add_alert_handler("critical", email_handler.handle_alert)

# Initialize webhook handler if configured
if os.getenv("ALERT_WEBHOOK_URL"):
    webhook_handler = WebhookAlertHandler(os.getenv("ALERT_WEBHOOK_URL"))
    alert_manager.add_alert_handler("warning", webhook_handler.handle_alert)
    alert_manager.add_alert_handler("error", webhook_handler.handle_alert)
    alert_manager.add_alert_handler("critical", webhook_handler.handle_alert)

# Register default handlers
alert_manager.register_handler(LoggingAlertHandler()) 