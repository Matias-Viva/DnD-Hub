"""Application configuration."""

import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    """Base configuration loaded from environment variables."""

    # Flask
    SECRET_KEY: str = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key")
    DEBUG: bool = os.environ.get("FLASK_ENV") == "development"

    # CORS
    CORS_ORIGINS: list[str] = os.environ.get("CORS_ORIGINS", "http://localhost:5173").split(",")

    # Supabase
    SUPABASE_URL: str = os.environ.get("SUPABASE_URL", "")
    SUPABASE_ANON_KEY: str = os.environ.get("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
