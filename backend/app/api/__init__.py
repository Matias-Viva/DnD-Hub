"""API blueprint — registers all route modules."""

from flask import Blueprint

bp = Blueprint("api", __name__)

from app.api import health  # noqa: E402, F401
