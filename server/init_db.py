from core.database import Base, engine
from models.database_models import User
from core.security import get_password_hash

def init_db():
    # Create tables
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully!") 
 