"""Health check endpoint."""

from flask import jsonify

from app.api import bp


@bp.get("/health")
def health_check() -> dict:
    """Return service health status.

    Returns:
        JSON response with status and service name.
    """
    return jsonify({"status": "ok", "service": "dnd-hub-backend"})
