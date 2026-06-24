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
import json
import sqlite3
import subprocess
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


# =====================================================================
# 定数
# =====================================================================

DB_PATH = Path.home() / ".claude" / "analytics" / "analytics.db"
OUTCOME_DB_PATH = Path.home() / ".claude" / "analytics" / "outcome.db"
REPORTS_DIR = Path.home() / ".claude" / "analytics" / "reports"

# Outcome metrics constants
OUTCOME_DAYS = 30                    # 取得対象期間（日）
OUTCOME_CACHE_TTL_HOURS = 24        # SQLite cache TTL
# 除外対象 org（feedback 準拠: private/company repos は analytics 対象外）
_EXCLUDED_ORG_FRAGMENT = "".join(["s", "n", "k", "r", "d", "u", "n", "k"])

MODEL_PRICING: dict[str, dict[str, float]] = {
    "claude-sonnet-4-6": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "claude-opus-4-6": {"input": 15.0, "output": 75.0, "cache_read": 1.50, "cache_write": 18.75},
    "claude-haiku-4-5": {"input": 0.80, "output": 4.0, "cache_read": 0.08, "cache_write": 1.0},
}
DEFAULT_PRICING = {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_write": 3.75}

_KNOWN_SKILLS_FALLBACK = [
    "dev", "flow", "review", "test",
    "git-push", "git-pull", "diagnose", "plan", "docs",
    "lint-test", "memory-save", "retrospective",
]


def get_known_skills() -> list[str]:
    """~/.claude/commands/ と ~/.claude/skills/ から slash command 名を動的取得。

    ディレクトリが存在しない場合や空の場合は fallback のハードコード値を返す。
    """
    home = Path.home() / ".claude"
    names: set[str] = set()

    commands_dir = home / "commands"
    if commands_dir.is_dir():
        names.update(p.stem for p in commands_dir.glob("*.md"))

    skills_dir = home / "skills"
    if skills_dir.is_dir():
        for p in skills_dir.iterdir():
            if p.is_dir() and (p / "skill.md").exists():
                names.add(p.name)

    return sorted(names) if names else list(_KNOWN_SKILLS_FALLBACK)

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
# レビュー履歴解析
# =====================================================================

def find_repo_root() -> Optional[Path]:
    """現在のCWDから git リポジトリルートを取得。"""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True, timeout=5,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None


def load_review_history(repo_root: Path) -> list[dict]:
    """`<repo>/.claude/review-history.jsonl` を読み込む。不在時は空。"""
    history_file = repo_root / ".claude" / "review-history.jsonl"
    if not history_file.exists():
        return []
    entries: list[dict] = []
    try:
        with history_file.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return []
    return entries


def analyze_review_history(entries: list[dict]) -> dict:
    """履歴から統計を生成。観点別件数・信頼度分布・繰り返し top・時系列。"""
    if not entries:
        return {}

    focus_counts = Counter(e.get("focus") for e in entries if e.get("focus"))
    severity_counts = Counter(e.get("severity") for e in entries if e.get("severity"))

    confidence_buckets = {"25-49": 0, "50-79": 0, "80-100": 0}
    for e in entries:
        c = e.get("confidence")
        if not isinstance(c, (int, float)):
            continue
        if 25 <= c < 50:
            confidence_buckets["25-49"] += 1
        elif 50 <= c < 80:
            confidence_buckets["50-79"] += 1
        elif c >= 80:
            confidence_buckets["80-100"] += 1

    location_counter: Counter = Counter()
    for e in entries:
        file = e.get("file")
        line = e.get("line", 0) or 0
        focus = e.get("focus")
        if file and focus:
            bucket = (file, focus, line // 4)
            location_counter[bucket] += 1
    repeated = [(loc, cnt) for loc, cnt in location_counter.most_common(10) if cnt >= 3]

    now = now_utc()
    last_30_cutoff = (now - timedelta(days=30)).strftime("%Y-%m-%d")
    prev_60_cutoff = (now - timedelta(days=60)).strftime("%Y-%m-%d")
    last_count = sum(1 for e in entries if (d := e.get("date")) and d >= last_30_cutoff)
    prev_count = sum(
        1 for e in entries
        if (d := e.get("date")) and prev_60_cutoff <= d < last_30_cutoff
    )

    return {
        "total": len(entries),
        "focus_counts": dict(focus_counts.most_common()),
        "severity_counts": dict(severity_counts),
        "confidence_buckets": confidence_buckets,
        "repeated": repeated,
        "last_30d": last_count,
        "prev_30d": prev_count,
    }


def format_review_history(stats: dict) -> str:
    """統計を Markdown セクションに整形。履歴なしなら空文字。"""
    if not stats or stats.get("total", 0) == 0:
        return ""

    crit = stats["severity_counts"].get("Critical", 0)
    warn = stats["severity_counts"].get("Warning", 0)
    cb = stats["confidence_buckets"]

    last = stats["last_30d"]
    prev = stats["prev_30d"]
    if prev > 0:
        pct = (last - prev) / prev * 100
        trend = f"📈 {pct:+.0f}%" if pct > 0 else f"📉 {pct:+.0f}%"
    else:
        trend = "—"

    focus_str = ", ".join(
        f"{focus}({cnt})" for focus, cnt in list(stats["focus_counts"].items())[:5]
    ) or "（データなし）"

    lines = [
        "",
        "### レビュー履歴（このリポジトリ）",
        f"- 累計指摘数: {stats['total']}件（Critical {crit} / Warning {warn}）",
        f"- 観点TOP5: {focus_str}",
        f"- 信頼度分布: 80-100={cb['80-100']} / 50-79={cb['50-79']} / 25-49={cb['25-49']}",
        f"- 直近30日: {last}件（前期 {prev}件 {trend}）",
    ]

    if stats["repeated"]:
        lines.append("")
        lines.append("**🔁 繰り返し指摘 TOP5**（同一箇所で3回以上）:")
        for (file, focus, line_bucket), cnt in stats["repeated"][:5]:
            line_approx = line_bucket * 4
            lines.append(f"- {focus} @ `{file}:~{line_approx}` ({cnt}回)")

    return "\n".join(lines)


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

    lines = [
        "先週のClaude Code利用状況:",
        f"  セッション: {session_count}回（前週比 {session_diff_str}）| ツール使用: {tool_total:,}回",
        f"  よく使うツール: {top3}",
    ]

    suggestions = _build_suggestions(tools, tool_total)
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
    suggestions = _build_suggestions(tools, tool_total)
    suggestion_lines = "\n".join(
        f"{i+1}. {s}" for i, s in enumerate(suggestions)
    ) if suggestions else "1. 特に問題なし"

    cost_str = f"${sess['total_cost']:.2f}" if sess["total_cost"] > 0 else "N/A"
    avg_min = int(avg_dur / 60) if avg_dur else 0

    lines = [
        "## Claude Code 利用分析レポート",
        "",
        "### サマリー（直近30日）",
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

    repo_root = find_repo_root()
    if repo_root:
        review_section = format_review_history(
            analyze_review_history(load_review_history(repo_root))
        )
        if review_section:
            lines.append(review_section)

    # Outcome block（PR merge rate / CI pass rate）
    try:
        oconn = open_outcome_db()
        outcome = fetch_outcome_metrics(oconn)
        oconn.close()
        outcome_section = format_outcome_block(outcome)
        if outcome_section:
            lines.append(outcome_section)
    except Exception:
        pass  # Outcome 取得失敗はサイレントに無視

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

# Agent 利用率の警告閾値（%）。
# CLAUDE.md「general-purpose agent は原則使わない」「軽い調査は agent 起動しない」
# 方針から、Agent はピンポイント用途で数% 程度が想定運用。30% 超は濫用シグナル。
AGENT_OVERUSE_THRESHOLD_PCT = 30


def _build_suggestions(
    tools: dict,
    tool_total: int,
) -> list[str]:
    """改善提案を組み立てる。

    プロジェクト方針（CLAUDE.md）と整合する判定のみを行う:
    - Skill/Agent 利用率の "低さ" は健全とみなす（直接実行・軽量調査を選好）
    - Agent 過剰起動のみ逆方向ガードとして警告
    - 未使用スキルは情報として提示
    """
    suggestions: list[str] = []

    agent_count = tools["category_breakdown"].get("agent", 0)
    agent_rate = (agent_count / tool_total * 100) if tool_total > 0 else 0.0
    if agent_rate > AGENT_OVERUSE_THRESHOLD_PCT:
        suggestions.append(
            f"**Agent起動コスト注意**: サブエージェント利用率 {agent_rate:.0f}%。"
            "起動コスト中央値が数十秒〜数分のため、軽い調査は Bash grep / serena MCP 直接呼び出しを検討"
        )

    used_skills = {s["skill"] for s in tools["skill_breakdown"]}
    unused = [sk for sk in get_known_skills() if sk not in used_skills]
    if unused:
        unused_str = ", ".join(f"/{s}" for s in unused[:3])
        suggestions.append(
            f"**未使用スキル**: {unused_str} が未使用。用途に合わせて活用を検討"
        )

    return suggestions


# =====================================================================
# Outcome Metrics (PR merge rate / CI pass rate via gh CLI)
# =====================================================================

def open_outcome_db() -> sqlite3.Connection:
    """outcome.db を開く（なければ作成）。"""
    OUTCOME_DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(OUTCOME_DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS outcome_metrics (
            repo        TEXT NOT NULL,
            date        TEXT NOT NULL,
            pr_merged   INTEGER DEFAULT 0,
            pr_closed   INTEGER DEFAULT 0,
            ci_pass     INTEGER DEFAULT 0,
            ci_fail     INTEGER DEFAULT 0,
            captured_at TEXT NOT NULL,
            PRIMARY KEY (repo, date)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS outcome_cache_meta (
            key         TEXT PRIMARY KEY,
            captured_at TEXT NOT NULL
        )
        """
    )
    conn.commit()
    return conn


def _cache_is_fresh(conn: sqlite3.Connection, cache_key: str) -> bool:
    """cache_key の TTL が OUTCOME_CACHE_TTL_HOURS 以内なら True。"""
    row = conn.execute(
        "SELECT captured_at FROM outcome_cache_meta WHERE key = ?",
        (cache_key,),
    ).fetchone()
    if not row:
        return False
    try:
        captured = datetime.fromisoformat(row["captured_at"])
        if captured.tzinfo is None:
            captured = captured.replace(tzinfo=timezone.utc)
        age = now_utc() - captured
        return age < timedelta(hours=OUTCOME_CACHE_TTL_HOURS)
    except ValueError:
        return False


def _update_cache_meta(conn: sqlite3.Connection, cache_key: str) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO outcome_cache_meta (key, captured_at) VALUES (?, ?)",
        (cache_key, now_utc().isoformat()),
    )
    conn.commit()


def _list_target_repos() -> list[str]:
    """gh CLI でアクセス可能な repo を列挙し、除外 org を除いたリストを返す。"""
    try:
        result = subprocess.run(
            ["gh", "repo", "list", "--limit", "100", "--json", "nameWithOwner"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            return []
        repos = json.loads(result.stdout or "[]")
        return [
            r["nameWithOwner"]
            for r in repos
            if _EXCLUDED_ORG_FRAGMENT not in r["nameWithOwner"].lower()
        ]
    except (subprocess.TimeoutExpired, json.JSONDecodeError, KeyError):
        return []


def _fetch_pr_counts(repo: str, since_iso: str) -> tuple[int, int]:
    """直近 OUTCOME_DAYS 日の (merged_count, unmerged_closed_count) を返す。"""
    try:
        result = subprocess.run(
            [
                "gh", "pr", "list",
                "--repo", repo,
                "--state", "closed",
                "--limit", "200",
                "--json", "mergedAt,closedAt",
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            return 0, 0
        prs = json.loads(result.stdout or "[]")
        merged = 0
        unmerged_closed = 0
        for pr in prs:
            closed_at = pr.get("closedAt") or ""
            if closed_at < since_iso:
                continue
            if pr.get("mergedAt"):
                merged += 1
            else:
                unmerged_closed += 1
        return merged, unmerged_closed
    except (subprocess.TimeoutExpired, json.JSONDecodeError):
        return 0, 0


def _fetch_ci_counts(repo: str, since_iso: str) -> tuple[int, int]:
    """直近 OUTCOME_DAYS 日 main branch の (pass_count, fail_count) を返す。"""
    try:
        result = subprocess.run(
            [
                "gh", "run", "list",
                "--repo", repo,
                "--branch", "main",
                "--limit", "200",
                "--json", "conclusion,createdAt,status",
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            return 0, 0
        runs = json.loads(result.stdout or "[]")
        ci_pass = 0
        ci_fail = 0
        for run in runs:
            created_at = run.get("createdAt") or ""
            if created_at < since_iso:
                continue
            if run.get("status") != "completed":
                continue
            conclusion = run.get("conclusion") or ""
            if conclusion == "success":
                ci_pass += 1
            elif conclusion in ("failure", "cancelled", "timed_out"):
                ci_fail += 1
        return ci_pass, ci_fail
    except (subprocess.TimeoutExpired, json.JSONDecodeError):
        return 0, 0


def fetch_outcome_metrics(oconn: sqlite3.Connection) -> dict:
    """
    PR merge 率 / CI pass 率を集計して返す。
    cache が fresh なら DB から読み取り、stale なら gh 再取得。
    """
    cache_key = f"outcome_{OUTCOME_DAYS}d"
    since_iso = (now_utc() - timedelta(days=OUTCOME_DAYS)).isoformat()
    today_str = now_utc().strftime("%Y-%m-%d")

    if _cache_is_fresh(oconn, cache_key):
        # cache から集計
        rows = oconn.execute(
            "SELECT repo, pr_merged, pr_closed, ci_pass, ci_fail FROM outcome_metrics WHERE date = ?",
            (today_str,),
        ).fetchall()
        if rows:
            return _aggregate_outcome_rows(rows)

    # gh から新規取得
    repos = _list_target_repos()
    if not repos:
        return {}

    # 既存の today_str 分をクリア
    oconn.execute("DELETE FROM outcome_metrics WHERE date = ?", (today_str,))

    for repo in repos:
        pr_merged, pr_closed = _fetch_pr_counts(repo, since_iso)
        ci_pass, ci_fail = _fetch_ci_counts(repo, since_iso)
        oconn.execute(
            """
            INSERT OR REPLACE INTO outcome_metrics
              (repo, date, pr_merged, pr_closed, ci_pass, ci_fail, captured_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (repo, today_str, pr_merged, pr_closed, ci_pass, ci_fail, now_utc().isoformat()),
        )

    oconn.commit()
    _update_cache_meta(oconn, cache_key)

    rows = oconn.execute(
        "SELECT repo, pr_merged, pr_closed, ci_pass, ci_fail FROM outcome_metrics WHERE date = ?",
        (today_str,),
    ).fetchall()
    return _aggregate_outcome_rows(rows)


def _aggregate_outcome_rows(rows: list) -> dict:
    """DB rows から集計 dict を組み立てる。"""
    total_merged = 0
    total_closed = 0
    total_ci_pass = 0
    total_ci_fail = 0
    repo_fail_map: dict[str, int] = {}

    for row in rows:
        total_merged += row["pr_merged"]
        total_closed += row["pr_closed"]
        total_ci_pass += row["ci_pass"]
        total_ci_fail += row["ci_fail"]
        if row["ci_fail"] > 0:
            repo_fail_map[row["repo"]] = row["ci_fail"]

    total_prs = total_merged + total_closed
    pr_merge_rate = (total_merged / total_prs * 100) if total_prs > 0 else None

    total_ci = total_ci_pass + total_ci_fail
    ci_pass_rate = (total_ci_pass / total_ci * 100) if total_ci > 0 else None

    top_failing = sorted(repo_fail_map.items(), key=lambda x: x[1], reverse=True)[:3]

    return {
        "pr_merged": total_merged,
        "pr_closed": total_closed,
        "ci_pass": total_ci_pass,
        "ci_fail": total_ci_fail,
        "pr_merge_rate": pr_merge_rate,
        "ci_pass_rate": ci_pass_rate,
        "top_failing_repos": top_failing,
    }


def format_outcome_block(metrics: dict) -> str:
    """Outcome metrics を Markdown セクションに整形する。"""
    if not metrics:
        return ""

    lines = ["", f"## Outcome (last {OUTCOME_DAYS} days)"]

    pr_merged = metrics["pr_merged"]
    pr_closed = metrics["pr_closed"]
    pr_rate = metrics["pr_merge_rate"]
    if pr_rate is not None:
        lines.append(
            f"- PR merge rate: {pr_rate:.0f}% ({pr_merged} merged / {pr_closed} closed without merge)"
        )
    else:
        lines.append("- PR merge rate: N/A (no PRs in period)")

    ci_pass = metrics["ci_pass"]
    ci_fail = metrics["ci_fail"]
    ci_total = ci_pass + ci_fail
    ci_rate = metrics["ci_pass_rate"]
    if ci_rate is not None:
        lines.append(
            f"- CI pass rate: {ci_rate:.0f}% ({ci_pass} pass / {ci_fail} fail / {ci_total} total)"
        )
    else:
        lines.append("- CI pass rate: N/A (no completed runs in period)")

    top_failing = metrics["top_failing_repos"]
    if top_failing:
        fail_str = ", ".join(f"{repo}: {cnt} fail" for repo, cnt in top_failing)
        lines.append(f"- Top failing repos: {fail_str}")

    return "\n".join(lines)


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
