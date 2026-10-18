# Учебный API для nginx-лабы. Ответов к заданиям тут нет, читать можно.
# Запуск: python api.py <файл настроек>
import signal
import socket
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

conf = {"listen": "0.0.0.0", "port": "8080", "report_delay": "20"}
with open(sys.argv[1]) as f:
    for line in f:
        line = line.split("#")[0].strip()
        if "=" in line:
            key, value = line.split("=", 1)
            conf[key.strip()] = value.strip()


def log(msg):
    print("api:", msg, flush=True)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        # путь берём из сырой строки запроса: http.server сам склеивает // в /
        path = self.requestline.split()[1]
        if path == "/health":
            self.reply(path, 200, "ok\n")
        elif path == "/v1/orders":
            self.reply(path, 200, '{"orders": [101, 102, 103]}\n')
        elif path == "/v1/report":
            time.sleep(int(conf["report_delay"]))
            self.reply(path, 200, "report ready\n")
        elif path == "/v1/stuck":
            time.sleep(600)
            self.reply(path, 200, "stuck: done\n")
        else:
            self.reply(path, 404, f"api: no route for {path}\n")

    def reply(self, path, code, body):
        if self.client_gone():
            log(f"GET {path} -> {code}, но клиент уже ушёл, ответ некому отдать")
            return
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode())
        log(f"GET {path} -> {code}")

    def client_gone(self):
        self.connection.setblocking(False)
        try:
            return self.connection.recv(1, socket.MSG_PEEK) == b""
        except BlockingIOError:
            return False
        finally:
            self.connection.setblocking(True)

    def log_message(self, *args):
        pass


# процесс тут PID 1: без своего обработчика он игнорирует SIGTERM, и docker stop ждёт 10 секунд
signal.signal(signal.SIGTERM, lambda *args: sys.exit(0))

log(f"started, port {conf['port']}")
ThreadingHTTPServer((conf["listen"], int(conf["port"])), Handler).serve_forever()
