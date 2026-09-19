import os
from pathlib import Path

# pyrefly: ignore [missing-import]
from flask import Flask

app = Flask(__name__)

GREETING = os.environ.get("GREETING", "hello")
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
COUNTER = DATA_DIR / "visits.txt"


@app.route("/")
def index():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    visits = int(COUNTER.read_text()) if COUNTER.exists() else 0
    visits += 1
    COUNTER.write_text(str(visits))
    return f"{GREETING}! visits: {visits}\n"


@app.route("/health")
def health():
    return "ok\n"


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port)
