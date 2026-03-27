#!/usr/bin/env python3
"""
Claude Code 利用状況分析スクリプト

使用方法:
    python3 analytics-report.py --mode brief   # session-start用（3-5行）
    python3 analytics-report.py --mode full    # /analytics用（詳細Markdown）
    python3 analytics-report.py --mode report  # 週次レポート生成
"""

import argparse
import csv
import os
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


# =====================================================================
# 定数
# =====================================================================

DB_PATH = Path.home() / ".claude" / "analytics" / "analytics.db"
REPORTS_DIR = Path.home() / ".claude" / "analytics" / "reports"

MODEL_PRICING: dict[str, dict[str, float]] = {
    "claude-sonnet-4-6": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-opus-4-6": {"input": 15.0, "output": 75.0, "cache_read": 1.50, "cache_write": 18.75},
    "claude-haiku-4-5": {"input": 0.80, "output": 4.0, "cache_read": 0.08, "cache_write": 1.0},
}
DEFAULT_PRICING = {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75}

KNOWN_SKILLS = [
    "dev", "flow", "review", "test", "refactor", "commit",
    "git-push", "debug", "plan", "docs",
]

MAX_REPORT_WEEKS = 4


# =====================================================================
# DB接続ユーティリティ
# =====================================================================

def open_db() -> Optional[sqlite3.Connection]:
    """DBを読み取り専用で開く。存在しない場合は None を返す。"""
    if not DB_PATH.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.OperationalError:
        return None


def now_utc() -> datetime:
    return datetime.now(tz=timezone.utc)


def iso_range(days_ago: int, base: Optional[datetime] = None) -> tuple[str, str]:
    """
    (start_iso, end_iso) を返す。
    start = base - days_ago日, end = base
    """
    end = base or now_utc()
    start = end - timedelta(days=days_ago)
    return start.isoformat(), end.isoformat()


# =====================================================================
# コスト計算
# =====================================================================

def calc_cost(
    model: Optional[str],
    input_tokens: int,
    cache_read_tokens: int,
    cache_write_tokens: int,
    output_tokens: int,
) -> float:
    """モデルとトークン数からコスト（USD）を計算する。"""
    pricing = MODEL_PRICING.get(model or "", DEFAULT_PRICING)
    cost = (
        input_tokens * pricing["input"]
        + cache_read_tokens * pricing["cache_read"]
        + cache_write_tokens * pricing["cache_write"]
        + output_tokens * pricing["output"]
    ) / 1_000_000
    return cost


# =====================================================================
# 共通集計クエリ
# =====================================================================

def fetch_session_stats(conn: sqlite3.Connection, start_iso: str, end_iso: str) -> dict:
    """セッション統計を返す。"""
    row = conn.execute(
        """
        SELECT
            COUNT(*) AS session_count,
            SUM(input_tokens) AS input_tokens,
            SUM(cache_read_tokens) AS cache_read_tokens,
            SUM(cache_write_tokens) AS cache_write_tokens,
            SUM(output_tokens) AS output_tokens,
            AVG(duration_sec) AS avg_duration_sec
        FROM sessions
        WHERE start_time >= ? AND start_time < ?
          AND (session_id NOT IN (SELECT DISTINCT agent_id FROM agent_events))
        """,
        (start_iso, end_iso),
    ).fetchone()

    rows_model = conn.execute(
        """
        SELECT model, COUNT(*) AS cnt,
               SUM(input_tokens) AS inp,
               SUM(cache_read_tokens) AS cr,
               SUM(cache_write_tokens) AS cw,
               SUM(output_tokens) AS out
        FROM sessions
        WHERE start_time >= ? AND start_time < ?
          AND model IS NOT NULL
        GROUP BY model
        ORDER BY cnt DESC
        """,
        (start_iso, end_iso),
    ).fetchall()

    total_cost = sum(
        calc_cost(r["model"], r["inp"] or 0, r["cr"] or 0, r["cw"] or 0, r["out"] or 0)
        for r in rows_model
    )

    return {
        "session_count": row["session_count"] or 0,
        "input_tokens": row["input_tokens"] or 0,
        "cache_read_tokens": row["cache_read_tokens"] or 0,
        "cache_write_tokens": row["cache_write_tokens"] or 0,
        "output_tokens": row["output_tokens"] or 0,
        "avg_duration_sec": row["avg_duration_sec"] or 0,
        "total_cost": total_cost,
        "model_breakdown": [dict(r) for r in rows_model],
    }


def fetch_tool_stats(conn: sqlite3.Connection, start_iso: str, end_iso: str) -> dict:
    """ツール使用統計を返す。"""
    total_row = conn.execute(
        """
        SELECT COUNT(*) AS total FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        """,
        (start_iso, end_iso),
    ).fetchone()
    total = total_row["total"] or 0

    top_tools = conn.execute(
        """
        SELECT tool_name, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY tool_name
        ORDER BY cnt DESC
        LIMIT 10
        """,
        (start_iso, end_iso),
    ).fetchall()

    category_rows = conn.execute(
        """
        SELECT tool_category, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY tool_category
        ORDER BY cnt DESC
        """,
        (start_iso, end_iso),
    ).fetchall()

    skill_rows = conn.execute(
        """
        SELECT tool_input_summary AS skill, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
          AND tool_category = 'skill'
          AND tool_input_summary != ''
        GROUP BY tool_input_summary
        ORDER BY cnt DESC
        """,
        (start_iso, end_iso),
    ).fetchall()

    agent_rows = conn.execute(
        """
        SELECT tool_input_summary AS agent_type, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
          AND tool_category = 'agent'
          AND tool_input_summary != ''
        GROUP BY tool_input_summary
        ORDER BY cnt DESC
        """,
        (start_iso, end_iso),
    ).fetchall()

    mcp_rows = conn.execute(
        """
        SELECT tool_name, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
          AND tool_category = 'mcp'
        GROUP BY tool_name
        ORDER BY cnt DESC
        LIMIT 5
        """,
        (start_iso, end_iso),
    ).fetchall()

    return {
        "total": total,
        "top_tools": [dict(r) for r in top_tools],
        "category_breakdown": {r["tool_category"]: r["cnt"] for r in category_rows},
        "skill_breakdown": [dict(r) for r in skill_rows],
        "agent_breakdown": [dict(r) for r in agent_rows],
        "mcp_breakdown": [dict(r) for r in mcp_rows],
    }


def fetch_tool_trend(
    conn: sqlite3.Connection,
    start_iso: str,
    end_iso: str,
    prev_start_iso: str,
    prev_end_iso: str,
) -> list[dict]:
    """
    前期・今期で使用回数が大きく変化したツールを返す（上位5件）。
    """
    curr_rows = conn.execute(
        """
        SELECT tool_name, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY tool_name
        """,
        (start_iso, end_iso),
    ).fetchall()
    prev_rows = conn.execute(
        """
        SELECT tool_name, COUNT(*) AS cnt
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY tool_name
        """,
        (prev_start_iso, prev_end_iso),
    ).fetchall()

    curr_map = {r["tool_name"]: r["cnt"] for r in curr_rows}
    prev_map = {r["tool_name"]: r["cnt"] for r in prev_rows}

    all_tools = set(curr_map) | set(prev_map)
    trends = []
    for tool in all_tools:
        curr = curr_map.get(tool, 0)
        prev = prev_map.get(tool, 0)
        if prev == 0:
            change = curr
            pct = None
        else:
            change = curr - prev
            pct = (curr - prev) / prev * 100
        trends.append({"tool": tool, "curr": curr, "prev": prev, "change": change, "pct": pct})

    trends.sort(key=lambda x: abs(x["change"]), reverse=True)
    return trends[:5]


def calc_pct_change(curr: float, prev: float) -> Optional[float]:
    if prev == 0:
        return None
    return (curr - prev) / prev * 100


def fmt_pct(pct: Optional[float]) -> str:
    if pct is None:
        return "N/A"
    sign = "+" if pct >= 0 else ""
    return f"{sign}{pct:.0f}%"


# =====================================================================
# brief モード
# =====================================================================

def run_brief(conn: sqlite3.Connection) -> str:
    end = now_utc()
    start_iso, end_iso = iso_range(7, end)
    prev_start_iso, prev_end_iso = iso_range(14, end - timedelta(days=7))

    sess = fetch_session_stats(conn, start_iso, end_iso)
    prev_sess = fetch_session_stats(conn, prev_start_iso, prev_end_iso)
    tools = fetch_tool_stats(conn, start_iso, end_iso)

    session_count = sess["session_count"]
    prev_session_count = prev_sess["session_count"]
    session_diff = session_count - prev_session_count
    session_diff_str = f"+{session_diff}" if session_diff >= 0 else str(session_diff)

    tool_total = tools["total"]
    top3 = ", ".join(
        f"{t['tool_name']}({t['cnt']})" for t in tools["top_tools"][:3]
    )

    # Skill利用率
    skill_count = tools["category_breakdown"].get("skill", 0)
    skill_rate = (skill_count / tool_total * 100) if tool_total > 0 else 0.0

    lines = [
        "先週のClaude Code利用状況:",
        f"  セッション: {session_count}回（前週比 {session_diff_str}）| ツール使用: {tool_total:,}回",
        f"  よく使うツール: {top3}",
    ]

    suggestions = _build_suggestions(tools, tool_total, sess["model_breakdown"])
    if suggestions:
        lines.append(f"  {suggestions[0]}")

    return "\n".join(lines)


# =====================================================================
# full モード
# =====================================================================

def run_full(conn: sqlite3.Connection) -> str:
    end = now_utc()
    start_iso, end_iso = iso_range(30, end)
    prev_start_iso = (end - timedelta(days=60)).isoformat()
    prev_end_iso = (end - timedelta(days=30)).isoformat()

    sess = fetch_session_stats(conn, start_iso, end_iso)
    prev_sess = fetch_session_stats(conn, prev_start_iso, prev_end_iso)
    tools = fetch_tool_stats(conn, start_iso, end_iso)
    prev_tools = fetch_tool_stats(conn, prev_start_iso, prev_end_iso)
    trends = fetch_tool_trend(conn, start_iso, end_iso, prev_start_iso, prev_end_iso)

    tool_total = tools["total"]

    # 前期比
    sess_pct = fmt_pct(calc_pct_change(sess["session_count"], prev_sess["session_count"]))
    tool_pct = fmt_pct(calc_pct_change(tool_total, prev_tools["total"]))
    cost_pct = fmt_pct(calc_pct_change(sess["total_cost"], prev_sess["total_cost"]))
    avg_dur = sess["avg_duration_sec"]
    prev_avg_dur = prev_sess["avg_duration_sec"]
    dur_diff = int((avg_dur - prev_avg_dur) / 60) if prev_avg_dur else 0
    dur_diff_str = f"{dur_diff:+d}分" if dur_diff != 0 else "±0分"

    # ツール上位
    builtin_top = [
        t for t in tools["top_tools"] if not t["tool_name"].startswith("mcp__")
        and t["tool_name"] not in ("Skill", "Agent", "Task")
    ][:3]
    builtin_str = ", ".join(
        f"**{t['tool_name']}** ({t['cnt']:,}回, {t['cnt']/tool_total*100:.0f}%)"
        for t in builtin_top
    ) if builtin_top and tool_total > 0 else "（データなし）"

    mcp_count = tools["category_breakdown"].get("mcp", 0)
    mcp_pct = mcp_count / tool_total * 100 if tool_total > 0 else 0.0
    mcp_top = ", ".join(t["tool_name"] for t in tools["mcp_breakdown"][:3])
    mcp_str = f"serena系ツールが全体の{mcp_pct:.0f}%（{mcp_top} が主）" if mcp_top else f"MCP全体 {mcp_pct:.0f}%"

    skill_top = ", ".join(f"{s['skill']}({s['cnt']})" for s in tools["skill_breakdown"][:3])
    agent_top = ", ".join(f"{a['agent_type']}({a['cnt']})" for a in tools["agent_breakdown"][:3])

    # トレンド
    trend_lines = []
    for t in trends:
        arrow = "up" if t["change"] > 0 else "down"
        icon = "📈" if arrow == "up" else "📉"
        pct_str = f"（{fmt_pct(t['pct'])}）" if t["pct"] is not None else ""
        trend_lines.append(f"- {icon} **{t['tool']}** {t['prev']}→{t['curr']} {pct_str}")

    trend_section = "\n".join(trend_lines) if trend_lines else "- トレンドデータなし"

    # 提案
    suggestions = _build_suggestions(tools, tool_total, sess["model_breakdown"])
    suggestion_lines = "\n".join(
        f"{i+1}. {s}" for i, s in enumerate(suggestions)
    ) if suggestions else "1. 特に問題なし"

    cost_str = f"${sess['total_cost']:.2f}" if sess["total_cost"] > 0 else "N/A"
    avg_min = int(avg_dur / 60) if avg_dur else 0

    lines = [
        "## Claude Code 利用分析レポート",
        "",
        f"### サマリー（直近30日）",
        "| 指標 | 値 | 前期比 |",
        "|------|-----|--------|",
        f"| セッション数 | {sess['session_count']} | {sess_pct} |",
        f"| ツール使用数 | {tool_total:,} | {tool_pct} |",
        f"| 推定コスト | {cost_str} | {cost_pct} |",
        f"| 平均セッション時間 | {avg_min}分 | {dur_diff_str} |",
        "",
        "### ツール使用パターン",
        f"- **最頻出**: {builtin_str}",
        f"- **MCP**: {mcp_str}",
        f"- **Skill**: {skill_top or '（未使用）'} が上位",
        f"- **Agent**: {agent_top or '（未使用）'}",
        "",
        "### トレンド",
        trend_section,
        "",
        "### 提案",
        suggestion_lines,
    ]

    return "\n".join(lines)


# =====================================================================
# report モード
# =====================================================================

def run_report(conn: sqlite3.Connection) -> None:
    """週次レポートをファイル出力する。"""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    end = now_utc()
    # ISO週番号でファイル名を決定
    year, week, _ = end.isocalendar()
    base_name = f"weekly-{year}-W{week:02d}"
    md_path = REPORTS_DIR / f"{base_name}.md"
    csv_path = REPORTS_DIR / f"{base_name}.csv"

    start_iso, end_iso = iso_range(7, end)

    # Markdown
    md_content = run_full(conn)
    md_path.write_text(md_content, encoding="utf-8")
    print(f"Markdown: {md_path}")

    # CSV（ツール使用の生データ）
    rows = conn.execute(
        """
        SELECT timestamp, session_id, project, tool_name, tool_category, tool_input_summary
        FROM tool_events
        WHERE timestamp >= ? AND timestamp < ?
        ORDER BY timestamp
        """,
        (start_iso, end_iso),
    ).fetchall()

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["timestamp", "session_id", "project", "tool_name", "tool_category", "tool_input_summary"])
        for r in rows:
            writer.writerow([r["timestamp"], r["session_id"], r["project"],
                             r["tool_name"], r["tool_category"], r["tool_input_summary"]])
    print(f"CSV: {csv_path}")

    # 古いレポートを削除（直近4週分を保持）
    _cleanup_old_reports()


def _cleanup_old_reports() -> None:
    """REPORTS_DIR 内の古いファイルを削除（直近4週分を保持）。"""
    md_files = sorted(REPORTS_DIR.glob("weekly-*.md"), key=lambda p: p.name, reverse=True)
    csv_files = sorted(REPORTS_DIR.glob("weekly-*.csv"), key=lambda p: p.name, reverse=True)

    for files in (md_files, csv_files):
        for old_file in files[MAX_REPORT_WEEKS:]:
            old_file.unlink(missing_ok=True)


# =====================================================================
# 提案ロジック
# =====================================================================

def _build_suggestions(
    tools: dict,
    tool_total: int,
    model_breakdown: list[dict],
) -> list[str]:
    suggestions: list[str] = []

    skill_count = tools["category_breakdown"].get("skill", 0)
    skill_rate = (skill_count / tool_total * 100) if tool_total > 0 else 0.0
    if skill_rate < 10:
        suggestions.append(
            f"**Skill活用**: Skill利用率 {skill_rate:.0f}%。/dev, /flow を活用すると効率UP"
        )

    agent_count = tools["category_breakdown"].get("agent", 0)
    agent_rate = (agent_count / tool_total * 100) if tool_total > 0 else 0.0
    if agent_rate < 5:
        suggestions.append(
            f"**Agent活用**: サブエージェント利用率 {agent_rate:.0f}%。並列タスクで /flow を検討"
        )

    opus_count = sum(m["cnt"] for m in model_breakdown if "opus" in (m.get("model") or ""))
    if opus_count > 0:
        suggestions.append(
            f"**コスト最適化**: opus使用セッションが{opus_count}件。sonnetで十分な場面あり"
        )

    # Bashでgrep/find使用の検出（tool_input_summary への参照は困難なため category=builtin かつ Bash の推定）
    # tool_events をカテゴリ別で確認: bash_grep は別途クエリが必要なため省略し固定メッセージを使う
    # （実際の検出は full query が必要なため suggestion は tool_total に応じて出す）

    used_skills = {s["skill"] for s in tools["skill_breakdown"]}
    unused = [sk for sk in KNOWN_SKILLS if sk not in used_skills]
    if unused:
        unused_str = ", ".join(f"/{s}" for s in unused[:3])
        suggestions.append(
            f"**未使用スキル**: {unused_str} が未使用。用途に合わせて活用を検討"
        )

    return suggestions


# =====================================================================
# エントリーポイント
# =====================================================================

def main() -> None:
    parser = argparse.ArgumentParser(description="Claude Code 利用状況分析")
    parser.add_argument(
        "--mode",
        choices=["brief", "full", "report"],
        default="brief",
        help="出力モード",
    )
    args = parser.parse_args()

    conn = open_db()
    if conn is None:
        # DB未存在時は何も出力しない
        sys.exit(0)

    try:
        if args.mode == "brief":
            output = run_brief(conn)
            print(output)
        elif args.mode == "full":
            output = run_full(conn)
            print(output)
        elif args.mode == "report":
            run_report(conn)
    except Exception:
        # 分析失敗時もサイレントに終了（session-start を妨げない）
        sys.exit(0)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
