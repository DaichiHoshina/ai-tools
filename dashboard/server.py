#!/usr/bin/env python3
"""Claude Code Analytics Dashboard Server

Python 3 標準ライブラリのみ使用（http.server + sqlite3）
ポート: 8765
"""

import http.server
import json
import os
import sqlite3
import urllib.parse
from datetime import datetime, timedelta, timezone
from pathlib import Path

PORT = 8765
DB_PATH = Path.home() / ".claude" / "analytics" / "analytics.db"
HTML_PATH = Path(__file__).parent / "index.html"

MODEL_PRICING = {
    "claude-sonnet-4-6": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-opus-4-6": {"input": 15.0, "output": 75.0, "cache_read": 1.50, "cache_write": 18.75},
    "claude-haiku-4-5": {"input": 0.80, "output": 4.0, "cache_read": 0.08, "cache_write": 1.0},
}  # per 1M tokens


def get_db_connection():
    """DBへの接続を返す。DBが存在しない場合は None を返す。"""
    if not DB_PATH.exists():
        return None
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def parse_query_params(path: str) -> dict:
    """クエリパラメータをパース。"""
    parsed = urllib.parse.urlparse(path)
    params = urllib.parse.parse_qs(parsed.query)
    return {k: v[0] for k, v in params.items()}


def get_date_filter(days_str: str) -> str | None:
    """days パラメータから WHERE 句用の日付文字列を返す。"""
    if days_str == "all":
        return None
    try:
        days = int(days_str)
    except (ValueError, TypeError):
        days = 30
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    return cutoff.strftime("%Y-%m-%dT%H:%M:%SZ")


def build_where(cutoff_date: str | None, project: str, date_col: str, project_col: str = "project") -> tuple[str, list]:
    """WHERE句とパラメータを構築。"""
    conditions = []
    params = []
    if cutoff_date:
        conditions.append(f"{date_col} >= ?")
        params.append(cutoff_date)
    if project and project != "all":
        conditions.append(f"{project_col} = ?")
        params.append(project)
    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    return where, params


def calc_cost(model: str, input_tokens: int, output_tokens: int, cache_read_tokens: int, cache_write_tokens: int) -> float:
    """モデルごとのコストを計算（USD）。"""
    pricing = MODEL_PRICING.get(model)
    if not pricing:
        # 未知モデルは sonnet の料金で概算
        pricing = MODEL_PRICING["claude-sonnet-4-6"]
    cost = (
        input_tokens * pricing["input"] / 1_000_000
        + output_tokens * pricing["output"] / 1_000_000
        + cache_read_tokens * pricing["cache_read"] / 1_000_000
        + cache_write_tokens * pricing["cache_write"] / 1_000_000
    )
    return round(cost, 4)


# --------------------------------------------------------------------------- #
# API ハンドラ
# --------------------------------------------------------------------------- #

def api_overview(params: dict) -> dict:
    conn = get_db_connection()
    if conn is None:
        return _empty_overview()

    days_str = params.get("days", "all")
    project = params.get("project", "all")
    cutoff = get_date_filter(days_str)

    try:
        # セッション数
        where_s, p_s = build_where(cutoff, project, "start_time")
        row = conn.execute(f"SELECT COUNT(*) FROM sessions {where_s}", p_s).fetchone()
        total_sessions = row[0]

        # ツール使用数
        where_t, p_t = build_where(cutoff, project, "timestamp")
        row = conn.execute(f"SELECT COUNT(*) FROM tool_events {where_t}", p_t).fetchone()
        total_tool_uses = row[0]

        # エージェント数
        where_a, p_a = build_where(cutoff, project, "start_time")
        row = conn.execute(f"SELECT COUNT(*) FROM agent_events {where_a}", p_a).fetchone()
        total_agent_runs = row[0]

        # トークン合計
        row = conn.execute(
            f"SELECT SUM(input_tokens), SUM(output_tokens), SUM(cache_read_tokens), SUM(cache_write_tokens) FROM sessions {where_s}",
            p_s,
        ).fetchone()
        total_tokens = {
            "input": row[0] or 0,
            "output": row[1] or 0,
            "cache_read": row[2] or 0,
            "cache_write": row[3] or 0,
        }

        # アクティブ日数
        row = conn.execute(
            f"SELECT COUNT(DISTINCT DATE(start_time)) FROM sessions {where_s}",
            p_s,
        ).fetchone()
        active_days = row[0] or 0

        # プロジェクト一覧
        rows = conn.execute("SELECT DISTINCT project FROM sessions ORDER BY project").fetchall()
        projects = [r[0] for r in rows]

        return {
            "total_sessions": total_sessions,
            "total_tool_uses": total_tool_uses,
            "total_agent_runs": total_agent_runs,
            "total_tokens": total_tokens,
            "active_days": active_days,
            "projects": projects,
        }
    finally:
        conn.close()


def _empty_overview() -> dict:
    return {
        "total_sessions": 0,
        "total_tool_uses": 0,
        "total_agent_runs": 0,
        "total_tokens": {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0},
        "active_days": 0,
        "projects": [],
    }


def api_tools(params: dict) -> dict:
    conn = get_db_connection()
    if conn is None:
        return {"by_name": [], "by_category": [], "daily_trend": []}

    days_str = params.get("days", "30")
    project = params.get("project", "all")
    cutoff = get_date_filter(days_str)

    try:
        where, p = build_where(cutoff, project, "timestamp")

        # ツール名別
        rows = conn.execute(
            f"SELECT tool_name, tool_category, COUNT(*) as cnt FROM tool_events {where} GROUP BY tool_name ORDER BY cnt DESC LIMIT 50",
            p,
        ).fetchall()
        by_name = [{"name": r["tool_name"], "count": r["cnt"], "category": r["tool_category"]} for r in rows]

        # カテゴリ別
        rows = conn.execute(
            f"SELECT tool_category, COUNT(*) as cnt FROM tool_events {where} GROUP BY tool_category ORDER BY cnt DESC",
            p,
        ).fetchall()
        by_category = [{"category": r["tool_category"], "count": r["cnt"]} for r in rows]

        # 日次トレンド
        rows = conn.execute(
            f"SELECT DATE(timestamp) as day, COUNT(*) as cnt FROM tool_events {where} GROUP BY day ORDER BY day",
            p,
        ).fetchall()
        daily_trend = [{"date": r["day"], "count": r["cnt"]} for r in rows]

        return {"by_name": by_name, "by_category": by_category, "daily_trend": daily_trend}
    finally:
        conn.close()


def api_sessions(params: dict) -> dict:
    conn = get_db_connection()
    if conn is None:
        return {"sessions": [], "daily_trend": []}

    days_str = params.get("days", "30")
    project = params.get("project", "all")
    cutoff = get_date_filter(days_str)

    try:
        where, p = build_where(cutoff, project, "start_time")

        rows = conn.execute(
            f"""SELECT session_id, project, model, start_time, duration_sec,
                       total_messages, input_tokens, output_tokens
                FROM sessions {where}
                ORDER BY start_time DESC LIMIT 100""",
            p,
        ).fetchall()
        sessions = [
            {
                "session_id": r["session_id"],
                "project": r["project"],
                "model": r["model"] or "unknown",
                "start_time": r["start_time"],
                "duration_sec": r["duration_sec"] or 0,
                "total_messages": r["total_messages"] or 0,
                "input_tokens": r["input_tokens"] or 0,
                "output_tokens": r["output_tokens"] or 0,
            }
            for r in rows
        ]

        # 日次トレンド
        rows = conn.execute(
            f"""SELECT DATE(start_time) as day, COUNT(*) as cnt, AVG(duration_sec) as avg_dur
                FROM sessions {where}
                GROUP BY day ORDER BY day""",
            p,
        ).fetchall()
        daily_trend = [
            {"date": r["day"], "count": r["cnt"], "avg_duration": round(r["avg_dur"] or 0)}
            for r in rows
        ]

        return {"sessions": sessions, "daily_trend": daily_trend}
    finally:
        conn.close()


def api_tokens(params: dict) -> dict:
    conn = get_db_connection()
    if conn is None:
        return {"daily": [], "by_model": [], "estimated_cost": {"total_usd": 0, "by_model": []}}

    days_str = params.get("days", "30")
    project = params.get("project", "all")
    cutoff = get_date_filter(days_str)

    try:
        where, p = build_where(cutoff, project, "start_time")

        # 日次トークン
        rows = conn.execute(
            f"""SELECT DATE(start_time) as day,
                       SUM(input_tokens) as inp,
                       SUM(output_tokens) as out,
                       SUM(cache_read_tokens) as cr,
                       SUM(cache_write_tokens) as cw
                FROM sessions {where}
                GROUP BY day ORDER BY day""",
            p,
        ).fetchall()
        daily = [
            {
                "date": r["day"],
                "input": r["inp"] or 0,
                "output": r["out"] or 0,
                "cache_read": r["cr"] or 0,
                "cache_write": r["cw"] or 0,
            }
            for r in rows
        ]

        # モデル別トークン
        rows = conn.execute(
            f"""SELECT model,
                       SUM(input_tokens) as inp,
                       SUM(output_tokens) as out,
                       SUM(cache_read_tokens) as cr,
                       SUM(cache_write_tokens) as cw
                FROM sessions {where}
                GROUP BY model""",
            p,
        ).fetchall()
        by_model = []
        total_cost = 0.0
        cost_by_model = []
        for r in rows:
            model = r["model"] or "unknown"
            inp = r["inp"] or 0
            out = r["out"] or 0
            cr = r["cr"] or 0
            cw = r["cw"] or 0
            by_model.append({"model": model, "input": inp, "output": out, "cache_read": cr, "cache_write": cw})
            cost = calc_cost(model, inp, out, cr, cw)
            total_cost += cost
            cost_by_model.append({"model": model, "cost_usd": cost})

        return {
            "daily": daily,
            "by_model": by_model,
            "estimated_cost": {
                "total_usd": round(total_cost, 4),
                "by_model": cost_by_model,
            },
        }
    finally:
        conn.close()


def api_agents(params: dict) -> dict:
    conn = get_db_connection()
    if conn is None:
        return {"by_type": [], "daily_trend": []}

    days_str = params.get("days", "30")
    project = params.get("project", "all")
    cutoff = get_date_filter(days_str)

    try:
        where, p = build_where(cutoff, project, "start_time")

        # エージェントタイプ別
        rows = conn.execute(
            f"""SELECT agent_type, COUNT(*) as cnt, AVG(duration_sec) as avg_dur
                FROM agent_events {where}
                GROUP BY agent_type ORDER BY cnt DESC""",
            p,
        ).fetchall()
        by_type = [
            {"type": r["agent_type"], "count": r["cnt"], "avg_duration_sec": round(r["avg_dur"] or 0)}
            for r in rows
        ]

        # 日次トレンド
        rows = conn.execute(
            f"""SELECT DATE(start_time) as day, COUNT(*) as cnt
                FROM agent_events {where}
                GROUP BY day ORDER BY day""",
            p,
        ).fetchall()
        daily_trend = [{"date": r["day"], "count": r["cnt"]} for r in rows]

        return {"by_type": by_type, "daily_trend": daily_trend}
    finally:
        conn.close()


# --------------------------------------------------------------------------- #
# HTTP ハンドラ
# --------------------------------------------------------------------------- #

ROUTES = {
    "/api/overview": api_overview,
    "/api/tools": api_tools,
    "/api/sessions": api_sessions,
    "/api/tokens": api_tokens,
    "/api/agents": api_agents,
}


class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):  # noqa: A002
        print(f"[{self.log_date_time_string()}] {format % args}")

    def do_GET(self):  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "/index.html":
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
            params = parse_query_params(self.path)
            result = handler(params)
            self._send_json(result)
        except Exception as e:
            self._send_json({"error": str(e)}, 500)

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# --------------------------------------------------------------------------- #
# エントリポイント
# --------------------------------------------------------------------------- #

if __name__ == "__main__":
    server = http.server.HTTPServer(("", PORT), DashboardHandler)
    db_status = "found" if DB_PATH.exists() else "NOT FOUND (empty data will be shown)"
    print(f"Claude Code Analytics Dashboard")
    print(f"  URL  : http://localhost:{PORT}")
    print(f"  DB   : {DB_PATH} [{db_status}]")
    print(f"  Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
