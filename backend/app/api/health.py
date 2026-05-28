"""Health check endpoints."""

from flask import Response, current_app, jsonify
from supabase import create_client

from app.api import bp


@bp.get("/health")
def health_check() -> Response:
    """Return service health status.

    Returns:
        JSON response with status and service name.
    """
    return jsonify({"status": "ok", "service": "dnd-hub-backend"})


@bp.get("/health/db")
def health_check_db() -> Response | tuple[Response, int]:
    """Verify database connectivity by calling the health_check RPC.

    Returns:
        JSON response with database connection status. 503 on failure.
    """
    try:
        client = create_client(
            current_app.config["SUPABASE_URL"],
            current_app.config["SUPABASE_SERVICE_ROLE_KEY"],
        )
        client.rpc("health_check").execute()
    except Exception as exc:
        return jsonify({"status": "error", "error": str(exc)}), 503
    return jsonify({"status": "ok"})
