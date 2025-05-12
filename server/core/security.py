from datetime import datetime, timedelta
from typing import Optional, List
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from models.database_models import User, TokenData
import os
from dotenv import load_dotenv

load_dotenv()

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a new JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """Get the current authenticated user from the token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    
    # Here you would typically query your database for the user
    # For now, we'll use a mock user
    user = User(
        id="1",
        username=token_data.username,
        email="user@example.com",
        hashed_password="",
        is_active=True
    )
    
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """Get the current active user"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

def check_permissions(required_permissions: List[str]):
    """Decorator to check user permissions"""
    async def permission_checker(current_user: User = Depends(get_current_active_user)):
        # Here you would typically check if the user has the required permissions
        # For now, we'll just check if the user is a superuser
        if not current_user.is_superuser:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not enough permissions"
            )
        return current_user
    return permission_checker

def rate_limit(max_requests: int, window_seconds: int):
    """Decorator to implement rate limiting"""
    from collections import defaultdict
    from datetime import datetime, timedelta
    
    # Store request counts
    request_counts = defaultdict(list)
    
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # Get client IP or user ID
            client_id = kwargs.get("client_id", "default")
            
            # Clean old requests
            now = datetime.utcnow()
            request_counts[client_id] = [
                req_time for req_time in request_counts[client_id]
                if now - req_time < timedelta(seconds=window_seconds)
            ]
            
            # Check if rate limit exceeded
            if len(request_counts[client_id]) >= max_requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded"
                )
            
            # Add current request
            request_counts[client_id].append(now)
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

def validate_device_access(device_id: str, current_user: User = Depends(get_current_active_user)) -> bool:
    """Validate if the user has access to the device"""
    # Here you would typically check if the user has access to the device
    # For now, we'll just return True
    return True

def validate_simulation_access(simulation_id: str, current_user: User = Depends(get_current_active_user)) -> bool:
    """Validate if the user has access to the simulation"""
    # Here you would typically check if the user has access to the simulation
    # For now, we'll just return True
    return True 
from typing import Optional, List
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from models.database_models import User, TokenData
import os
from dotenv import load_dotenv

load_dotenv()

# Security configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Generate password hash"""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a new JWT access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """Get the current authenticated user from the token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    
    # Here you would typically query your database for the user
    # For now, we'll use a mock user
    user = User(
        id="1",
        username=token_data.username,
        email="user@example.com",
        hashed_password="",
        is_active=True
    )
    
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """Get the current active user"""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

def check_permissions(required_permissions: List[str]):
    """Decorator to check user permissions"""
    async def permission_checker(current_user: User = Depends(get_current_active_user)):
        # Here you would typically check if the user has the required permissions
        # For now, we'll just check if the user is a superuser
        if not current_user.is_superuser:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not enough permissions"
            )
        return current_user
    return permission_checker

def rate_limit(max_requests: int, window_seconds: int):
    """Decorator to implement rate limiting"""
    from collections import defaultdict
    from datetime import datetime, timedelta
    
    # Store request counts
    request_counts = defaultdict(list)
    
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # Get client IP or user ID
            client_id = kwargs.get("client_id", "default")
            
            # Clean old requests
            now = datetime.utcnow()
            request_counts[client_id] = [
                req_time for req_time in request_counts[client_id]
                if now - req_time < timedelta(seconds=window_seconds)
            ]
            
            # Check if rate limit exceeded
            if len(request_counts[client_id]) >= max_requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded"
                )
            
            # Add current request
            request_counts[client_id].append(now)
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

def validate_device_access(device_id: str, current_user: User = Depends(get_current_active_user)) -> bool:
    """Validate if the user has access to the device"""
    # Here you would typically check if the user has access to the device
    # For now, we'll just return True
    return True

def validate_simulation_access(simulation_id: str, current_user: User = Depends(get_current_active_user)) -> bool:
    """Validate if the user has access to the simulation"""
    # Here you would typically check if the user has access to the simulation
    # For now, we'll just return True
    return True 