import logging
import os
import secrets
import signal
import socket
import sys

import psycopg
from flask import Flask, abort, redirect, render_template, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("shorty")

APP_TITLE = os.environ.get("APP_TITLE", "shorty")
DB = {
    "host": os.environ.get("DB_HOST", "localhost"),
    "port": os.environ.get("DB_PORT", "5432"),
    "dbname": os.environ.get("DB_NAME", "shorty"),
    "user": os.environ.get("DB_USER", "shorty"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "connect_timeout": 2,
}
HOSTNAME = socket.gethostname()

CREATED = Counter("shorty_links_created_total", "Links created")
REDIRECTS = Counter("shorty_redirects_total", "Redirects served")

app = Flask(__name__)


def db():
    return psycopg.connect(**DB)


def init_db():
    with db() as conn:
        conn.execute(
            """CREATE TABLE IF NOT EXISTS links (
                   code TEXT PRIMARY KEY,
                   url TEXT NOT NULL,
                   hits INTEGER NOT NULL DEFAULT 0,
                   created_at TIMESTAMPTZ NOT NULL DEFAULT now()
               )"""
        )


def create_link(url):
    code = secrets.token_urlsafe(4)
    with db() as conn:
        conn.execute("INSERT INTO links (code, url) VALUES (%s, %s)", (code, url))
    CREATED.inc()
    log.info("created %s -> %s", code, url)
    return code


@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        url = request.form.get("url", "").strip()
        if not url.startswith(("http://", "https://")):
            abort(400, "url must start with http:// or https://")
        create_link(url)
        return redirect("/")
    with db() as conn:
        links = conn.execute(
            "SELECT code, url, hits FROM links ORDER BY created_at DESC LIMIT 20"
        ).fetchall()
    return render_template("index.html", title=APP_TITLE, links=links, pod=HOSTNAME)


@app.post("/api/links")
def api_create():
    url = (request.get_json(silent=True) or {}).get("url", "")
    if not url.startswith(("http://", "https://")):
        return {"error": "url must start with http:// or https://"}, 400
    code = create_link(url)
    return {"code": code, "short": f"{request.host_url}{code}", "pod": HOSTNAME}, 201


@app.get("/<code>")
def follow(code):
    with db() as conn:
        row = conn.execute(
            "UPDATE links SET hits = hits + 1 WHERE code = %s RETURNING url", (code,)
        ).fetchone()
    if row is None:
        abort(404)
    REDIRECTS.inc()
    return redirect(row[0], code=302)


# liveness: процесс жив и отвечает. База тут НЕ проверяется.
@app.get("/healthz")
def healthz():
    return {"status": "ok", "pod": HOSTNAME}


# readiness: готов принимать трафик = база доступна.
@app.get("/readyz")
def readyz():
    try:
        init_db()
    except psycopg.OperationalError as e:
        log.warning("not ready: %s", e)
        return {"status": "db unavailable", "pod": HOSTNAME}, 503
    return {"status": "ready", "pod": HOSTNAME}


@app.get("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


def on_sigterm(signum, frame):
    log.info("got SIGTERM, shutting down")
    sys.exit(0)


signal.signal(signal.SIGTERM, on_sigterm)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
