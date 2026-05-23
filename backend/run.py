"""Development entry point. Use `uv run python run.py` to start locally."""

from app import create_app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True)
