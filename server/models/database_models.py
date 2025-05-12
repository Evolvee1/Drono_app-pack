from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, JSON, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from core.database import Base
import uuid
from datetime import datetime
from typing import Dict, Any, Optional, List
from enum import Enum
from pydantic import BaseModel, Field

class User(Base):
    __tablename__ = "users"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_login = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    devices = relationship("Device", back_populates="owner")
    commands = relationship("Command", back_populates="user")

class Device(Base):
    __tablename__ = "devices"

    id = Column(String, primary_key=True, index=True)  # Device ID from ADB
    name = Column(String)
    model = Column(String)
    status = Column(String)  # online, offline, busy
    owner_id = Column(Integer, ForeignKey("users.id"))
    last_seen = Column(DateTime(timezone=True), server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    properties = Column(JSON)  # Store device properties as JSON
    
    # Relationships
    owner = relationship("User", back_populates="devices")
    commands = relationship("Command", back_populates="device")

class Command(Base):
    __tablename__ = "commands"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    type = Column(String)  # start, stop, pause, etc.
    parameters = Column(JSON)  # Command parameters as JSON
    status = Column(String)  # pending, running, completed, failed
    priority = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    error = Column(String, nullable=True)
    
    # Foreign keys
    user_id = Column(Integer, ForeignKey("users.id"))
    device_id = Column(String, ForeignKey("devices.id"))
    
    # Relationships
    user = relationship("User", back_populates="commands")
    device = relationship("Device", back_populates="commands")

class DeviceMetrics(Base):
    __tablename__ = "device_metrics"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, ForeignKey("devices.id"))
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    cpu_usage = Column(Float, nullable=True)
    memory_usage = Column(Float, nullable=True)
    battery_level = Column(Float, nullable=True)
    temperature = Column(Float, nullable=True)
    network_usage = Column(JSON, nullable=True)  # Store network metrics as JSON
    custom_metrics = Column(JSON, nullable=True)  # Store any additional metrics 

class AlertType(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"

class DeviceStatus(str, Enum):
    ONLINE = "online"
    OFFLINE = "offline"
    BUSY = "busy"
    ERROR = "error"

class SimulationStatus(str, Enum):
    IDLE = "idle"
    RUNNING = "running"
    PAUSED = "paused"
    COMPLETED = "completed"
    ERROR = "error"

class CommandType(str, Enum):
    START = "start"
    STOP = "stop"
    PAUSE = "pause"
    RESUME = "resume"
    STATUS = "status"

class Alert(BaseModel):
    type: AlertType
    message: str
    device_id: Optional[str] = None
    details: Dict[str, Any] = Field(default_factory=dict)
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        if 'timestamp' in data and isinstance(data['timestamp'], datetime):
            data['timestamp'] = data['timestamp'].isoformat()
        return data

class Device(BaseModel):
    id: str
    name: Optional[str] = None
    model: Optional[str] = None
    status: DeviceStatus = DeviceStatus.OFFLINE
    last_seen: datetime = Field(default_factory=datetime.utcnow)
    properties: Dict[str, str] = Field(default_factory=dict)
    battery: Optional[str] = "Unknown"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        if 'last_seen' in data and isinstance(data['last_seen'], datetime):
            data['last_seen'] = data['last_seen'].isoformat()
        return data

class Simulation(BaseModel):
    id: str
    device_id: str
    status: SimulationStatus = SimulationStatus.IDLE
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    current_iteration: int = 0
    total_iterations: int = 0
    url: str
    settings: Dict[str, Any] = Field(default_factory=dict)
    progress: float = 0.0
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        for field in ['start_time', 'end_time']:
            if field in data and isinstance(data[field], datetime):
                data[field] = data[field].isoformat()
        return data

class Command(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    device_id: Optional[str] = None
    type: CommandType
    parameters: Dict[str, Any] = Field(default_factory=dict)
    status: str = "pending"
    created_at: datetime = Field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        for field in ['created_at', 'completed_at']:
            if field in data and isinstance(data[field], datetime):
                data[field] = data[field].isoformat() 
        return data

class User(BaseModel):
    id: str
    username: str
    email: str
    hashed_password: str
    is_active: bool = True
    is_superuser: bool = False
    created_at: datetime = Field(default_factory=datetime.utcnow)
    last_login: Optional[datetime] = None

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime

class TokenData(BaseModel):
    username: Optional[str] = None
    scopes: List[str] = Field(default_factory=list)

class WebSocketMessage(BaseModel):
    type: str
    data: Dict[str, Any]

class DeviceStatusUpdate(BaseModel):
    device_id: str
    status: DeviceStatus
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    details: Dict[str, Any] = Field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        if 'timestamp' in data and isinstance(data['timestamp'], datetime):
            data['timestamp'] = data['timestamp'].isoformat()
        return data

class SimulationProgress(BaseModel):
    device_id: str
    simulation_id: str
    current_iteration: int
    total_iterations: int
    progress: float
    status: SimulationStatus
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    details: Dict[str, Any] = Field(default_factory=dict)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary with proper datetime serialization"""
        data = self.dict()
        # Convert datetime to ISO format string
        if 'timestamp' in data and isinstance(data['timestamp'], datetime):
            data['timestamp'] = data['timestamp'].isoformat()
        return data 