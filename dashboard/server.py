#!/usr/bin/env python3
"""Claude Code LaunchAgent Dashboard Server

Python 3 標準ライブラリのみ使用 (http.server + subprocess + file I/O)。
port: 8765
"""

import http.server
import json
import os
import subprocess
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

PORT = 8765
HTML_PATH = Path(__file__).parent / "index.html"
LAUNCHD_LOG_DIR = Path.home() / ".claude" / "logs" / "launchd"
LAUNCHD_JOBS = ("sleep-review", "memory-clean", "retrospective", "daily-report")
LAUNCHD_SCHEDULES = {
    "sleep-review": "毎日 02:03",
    "memory-clean": "毎週日曜 03:07",
    "retrospective": "毎週日曜 04:11",
    "daily-report": "毎日 10:07 (Slack)",
}


def _launchctl_list(label: str) -> dict:
    try:
        result = subprocess.run(
            ["launchctl", "list", label],
            capture_output=True, text=True, timeout=5,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {"loaded": False, "pid": None, "last_exit": None}

    if result.returncode != 0:
        return {"loaded": False, "pid": None, "last_exit": None}

    pid = None
    last_exit = None
    for line in result.stdout.splitlines():
        stripped = line.strip().rstrip(";").rstrip(",")
        if stripped.startswith('"PID" = '):
            try:
                pid = int(stripped.split("=", 1)[1].strip())
            except ValueError:
                pid = None
        elif stripped.startswith('"LastExitStatus" = '):
            try:
                last_exit = int(stripped.split("=", 1)[1].strip())
            except ValueError:
                last_exit = None
    return {"loaded": True, "pid": pid, "last_exit": last_exit}


def _tail_lines(path: Path, max_lines: int, max_bytes: int = 8192) -> str:
    if not path.exists():
        return ""
    try:
        size = path.stat().st_size
        with path.open("rb") as fh:
            if size > max_bytes:
                fh.seek(-max_bytes, os.SEEK_END)
            data = fh.read()
    except OSError:
        return ""
    text = data.decode("utf-8", errors="replace")
    lines = text.splitlines()
    return "\n".join(lines[-max_lines:])


def _file_mtime_iso(path: Path) -> str | None:
    if not path.exists():
        return None
    try:
        ts = path.stat().st_mtime
    except OSError:
        return None
    return datetime.fromtimestamp(ts, tz=timezone.utc).astimezone().isoformat(timespec="seconds")


def api_launchd(params: dict) -> dict:
    jobs = []
    for name in LAUNCHD_JOBS:
        label = f"com.claude.{name}"
        plist_dst = Path.home() / "Library" / "LaunchAgents" / f"{label}.plist"
        log_path = LAUNCHD_LOG_DIR / f"{name}.log"
        err_path = LAUNCHD_LOG_DIR / f"{name}.err.log"

        state = _launchctl_list(label)
        jobs.append({
            "name": name,
            "label": label,
            "schedule": LAUNCHD_SCHEDULES.get(name, ""),
            "installed": plist_dst.exists(),
            "loaded": state["loaded"],
            "pid": state["pid"],
            "last_exit": state["last_exit"],
            "log_mtime": _file_mtime_iso(log_path),
            "err_mtime": _file_mtime_iso(err_path),
            "log_size": log_path.stat().st_size if log_path.exists() else 0,
            "err_size": err_path.stat().st_size if err_path.exists() else 0,
            "log_tail": _tail_lines(log_path, 30),
            "err_tail": _tail_lines(err_path, 20),
        })
    return {"jobs": jobs}


ROUTES = {
    "/api/launchd": api_launchd,
}


class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/", "/index.html"):
            self._serve_file()
            return

        if path in ROUTES:
            self._serve_api(ROUTES[path])
            return

        self._send_json({"error": "Not Found"}, 404)

    def _serve_file(self):
        try:
            content = HTML_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self._send_json({"error": "index.html not found"}, 404)

    def _serve_api(self, handler):
        try:
            parsed = urllib.parse.urlparse(self.path)
            params = dict(urllib.parse.parse_qsl(parsed.query))
            data = handler(params)
            self._send_json(data)
        except Exception as e:
            self._send_json({"error": str(e)}, 500)

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), DashboardHandler)
    print(f"LaunchAgent dashboard: http://127.0.0.1:{PORT}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()
