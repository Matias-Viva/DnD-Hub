"""DnD Hub Flask application factory."""

from flask import Flask
from flask_cors import CORS

from app.config import Config


def create_app(config: Config | None = None) -> Flask:
    """Create and configure the Flask application.

    Args:
        config: Optional configuration object. Defaults to Config().

    Returns:
        Configured Flask application instance.
    """
    app = Flask(__name__)
    app.config.from_object(config or Config())

    CORS(app, origins=app.config["CORS_ORIGINS"])

    from app.api import bp as api_bp

    app.register_blueprint(api_bp, url_prefix="/api")

    return app
