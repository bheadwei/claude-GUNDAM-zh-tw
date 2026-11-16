#!/usr/bin/env python3
"""overview-serve.py — 專案圖解的本機靜態伺服器（ADR-2026-11-12-003 第 1 節；token 固定見 ADR-2026-11-16-001）。

用法：overview-serve.py <overview 資料夾>
環境變數：
  OVERVIEW_SERVE_IDLE_MIN   閒置幾分鐘後自行結束，接受小數，預設 30
  OVERVIEW_SERVE_PORT_BASE  起始 port，預設 8765（最多往後試 20 個；測試用來避開真的伺服器）

只綁 127.0.0.1、只服務 /<token>/ 底下的路徑，其他一律 404。起停由 overview-serve.sh 負責。
token 與 port 記在 overview/.serve-keep，重起時沿用；閒置結束不刪它。
最低 Python 3.7。
"""
import functools
import hmac
import json
import os
import re
import secrets
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote

PORT_TRIES = 20
TOKEN_RE = re.compile(r"^[A-Za-z0-9_-]{20,64}$")


def env_float(name, default):
    try:
        v = float(os.environ.get(name, ""))
        return v if v > 0 else default
    except ValueError:
        return default


class Handler(SimpleHTTPRequestHandler):
    token = ""
    activity = None

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        super().end_headers()

    def log_message(self, *args):
        pass

    def list_directory(self, path):
        self.send_error(404)
        return None

    def _route(self):
        """回傳 token 之後的相對路徑；token 不對、或碰到點開頭的檔案則回 None 並已回 404。"""
        raw = self.path.split("?", 1)[0].split("#", 1)[0]
        parts = raw.split("/", 2)
        if (len(parts) < 3 or parts[0] != ""
                or not hmac.compare_digest(parts[1].encode("utf-8", "replace"), self.token.encode())):
            self.send_error(404)
            return None
        Handler.activity[0] = time.monotonic()
        return parts[2]

    def _reply(self, body=b""):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body and self.command != "HEAD":
            self.wfile.write(body)
        self.wfile.flush()

    def _serve_file(self, rest, method):
        if rest == ".serve-id":
            return self._reply(b"ok")
        if any(seg.startswith(".") for seg in unquote(rest).split("/") if seg):
            return self.send_error(404)
        self.path = "/" + rest
        method(self)

    def do_GET(self):
        rest = self._route()
        if rest is not None:
            self._serve_file(rest, SimpleHTTPRequestHandler.do_GET)

    def do_HEAD(self):
        rest = self._route()
        if rest is not None:
            self._serve_file(rest, SimpleHTTPRequestHandler.do_HEAD)

    def do_POST(self):
        rest = self._route()
        if rest != ".shutdown":
            if rest is not None:
                self.send_error(404)
            return
        self._reply()
        threading.Thread(target=self.server.shutdown, daemon=True).start()


def bind(handler, base, preferred=None):
    last = None
    ports = list(range(base, base + PORT_TRIES))
    if preferred is not None and 1024 <= preferred <= 65535:
        ports.insert(0, preferred)
    for port in ports:
        try:
            return ThreadingHTTPServer(("127.0.0.1", port), handler)
        except OSError as e:
            last = e
    sys.stderr.write("從 %d 起的 %d 個 port 都不能用（%s）\n" % (base, PORT_TRIES, last))
    return None


def write_serve(serve_file, info):
    tmp = "%s.%d.tmp" % (serve_file, os.getpid())
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(info, f)
    os.replace(tmp, serve_file)


def load_keep(keep_file):
    """回傳 (token, port)；檔案不存在、壞掉、token 不合格、或權限有 group／other 位元就回 (None, None)。"""
    try:
        if os.name != "nt" and os.stat(keep_file).st_mode & 0o077:
            return None, None
        with open(keep_file, encoding="utf-8") as f:
            data = json.load(f)
        token, port = data["token"], data["port"]
    except (OSError, ValueError, KeyError, TypeError):
        return None, None
    if not isinstance(token, str) or not TOKEN_RE.match(token):
        return None, None
    return token, port if isinstance(port, int) and not isinstance(port, bool) else None


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.stderr.write("用法：overview-serve.py <overview 資料夾>\n")
        return 2
    directory = os.path.abspath(sys.argv[1])
    serve_file = os.path.join(directory, ".serve")
    keep_file = os.path.join(directory, ".serve-keep")
    os.umask(0o077)

    token, keep_port = load_keep(keep_file)
    token = token or secrets.token_urlsafe(16)
    Handler.token = token
    Handler.activity = [time.monotonic()]
    server = bind(functools.partial(Handler, directory=directory),
                  int(env_float("OVERVIEW_SERVE_PORT_BASE", 8765)), keep_port)
    if server is None:
        return 3

    port = server.server_address[1]
    write_serve(keep_file, {"token": token, "port": port})
    info = {"port": port, "token": token, "pid": os.getpid(),
            "started": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    write_serve(serve_file, info)

    idle = env_float("OVERVIEW_SERVE_IDLE_MIN", 30.0) * 60
    interval = min(1.0, max(0.05, idle / 4))

    def watch_idle():
        while time.monotonic() - Handler.activity[0] < idle:
            time.sleep(interval)
        server.shutdown()

    threading.Thread(target=watch_idle, daemon=True).start()
    try:
        server.serve_forever(poll_interval=min(0.5, interval))
    finally:
        server.server_close()
        try:
            with open(serve_file, encoding="utf-8") as f:
                mine = json.load(f).get("pid") == os.getpid()
            if mine:
                os.remove(serve_file)
        except (OSError, ValueError):
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
