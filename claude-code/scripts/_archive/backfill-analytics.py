#!/usr/bin/env python3
"""
バックフィルスクリプト: 過去のClaude Codeトランスクリプト（JSONL）を解析してSQLiteに投入する。

使用方法:
    python3 claude-code/scripts/backfill-analytics.py
    python3 claude-code/scripts/backfill-analytics.py --dry-run
    python3 claude-code/scripts/backfill-analytics.py --verbose
"""

import argparse
import glob
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


# =====================================================================
# 定数
# =====================================================================

PROJECTS_DIR = Path.home() / ".claude" / "projects"
DB_PATH = Path.home() / ".claude" / "analytics" / "analytics.db"


# =====================================================================
# ツールカテゴリ判定
# =====================================================================

def categorize_tool(name: str) -> str:
    """ツール名からカテゴリを判定する。"""
    if name == "Skill":
        return "skill"
    if name in ("Agent", "Task") or name.startswith("Task"):
        return "agent"
    if name.startswith("mcp__"):
        return "mcp"
    return "builtin"


def extract_tool_input_summary(tool_name: str, tool_input: dict) -> str:
    """ツール入力からサマリ文字列を抽出する。"""
    if tool_name == "Skill":
        return tool_input.get("skill", "")
    if tool_name in ("Agent", "Task") or tool_name.startswith("Task"):
        return tool_input.get("subagent_type", "")
    if tool_name.startswith("mcp__"):
        # "mcp__serena__read_file" -> "serena"
        parts = tool_name.split("__")
        return parts[1] if len(parts) >= 2 else ""
    return ""


# =====================================================================
# プロジェクト名抽出
# =====================================================================

def extract_project_name(dir_name: str) -> str:
    """
    ディレクトリ名からプロジェクト名を抽出する。

    例:
        -Users-daichi-ai-tools -> ai-tools
        -Users-daichi -> (daichi)
        -Users-daichi-onecomme-tools -> onecomme-tools
    """
    # 先頭の "-" を除去し、"-Users-daichi-" プレフィックスを取り除く
    name = dir_name.lstrip("-")
    # "Users-daichi-" を除去
    prefix = "Users-daichi-"
    if name.startswith(prefix):
        remainder = name[len(prefix):]
        if remainder:
            return remainder
        # プレフィックスの後が空 = ホームディレクトリそのもの
        return "home"
    # フォールバック: そのまま返す
    return name


# =====================================================================
# タイムスタンプ差分計算
# =====================================================================

def calc_duration_sec(start_ts: Optional[str], end_ts: Optional[str]) -> Optional[int]:
    """ISO8601タイムスタンプ2つの差を秒数で返す。"""
    if not start_ts or not end_ts:
        return None
    try:
        fmt = "%Y-%m-%dT%H:%M:%S.%fZ"
        fmt_short = "%Y-%m-%dT%H:%M:%SZ"
        for f in (fmt, fmt_short):
            try:
                t0 = datetime.strptime(start_ts, f).replace(tzinfo=timezone.utc)
                t1 = datetime.strptime(end_ts, f).replace(tzinfo=timezone.utc)
                return max(0, int((t1 - t0).total_seconds()))
            except ValueError:
                continue
    except Exception:
        pass
    return None


# =====================================================================
# JSONLファイルの解析
# =====================================================================

def parse_jsonl(filepath: Path) -> dict:
    """
    1つのJSONLファイルを解析して以下を返す。

    Returns:
        {
            "session_id": str,
            "project": str,
            "session": dict,        # sessions テーブル用
            "tool_events": list,    # tool_events テーブル用
            "agent_events": list,   # agent_events テーブル用
        }
    """
    session_id = filepath.stem  # 拡張子なしファイル名

    # プロジェクト名: ファイルの親ディレクトリをさかのぼって解決
    # 通常: ~/.claude/projects/<proj_dir>/<session_id>.jsonl
    # サブエージェント: ~/.claude/projects/<proj_dir>/<parent_session>/subagents/<agent_id>.jsonl
    parts = filepath.parts
    projects_idx = None
    for i, part in enumerate(parts):
        if part == "projects":
            projects_idx = i
            break

    project = "unknown"
    if projects_idx is not None and len(parts) > projects_idx + 1:
        proj_dir = parts[projects_idx + 1]
        project = extract_project_name(proj_dir)

    # サブエージェントかどうか
    is_subagent = "subagents" in filepath.parts

    records = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return {}

    if not records:
        return {}

    # セッション情報の集計
    first_ts = None
    last_ts = None
    model = None
    git_branch = None
    total_messages = 0
    input_tokens = 0
    cache_read_tokens = 0
    cache_write_tokens = 0
    output_tokens = 0

    tool_events = []
    agent_events = []

    # サブエージェント: agentId と agentType を取得
    agent_id = None
    agent_type = None

    for rec in records:
        rec_type = rec.get("type", "")
        ts = rec.get("timestamp")

        if ts:
            if first_ts is None:
                first_ts = ts
            last_ts = ts

        # git_branch
        if not git_branch and rec.get("gitBranch"):
            git_branch = rec["gitBranch"]

        # サブエージェント情報
        if not agent_id and rec.get("agentId"):
            agent_id = rec["agentId"]

        # ユーザーメッセージカウント
        if rec_type == "user":
            total_messages += 1

        # アシスタントメッセージ
        if rec_type == "assistant":
            msg = rec.get("message", {})

            # モデル
            if not model and msg.get("model"):
                model = msg["model"]

            # トークン集計
            usage = msg.get("usage", {})
            input_tokens += usage.get("input_tokens", 0)
            cache_read_tokens += usage.get("cache_read_input_tokens", 0)
            cache_write_tokens += usage.get("cache_creation_input_tokens", 0)
            output_tokens += usage.get("output_tokens", 0)

            # ツール使用
            content = msg.get("content", [])
            if isinstance(content, list):
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "tool_use":
                        tool_name = item.get("name", "")
                        tool_input = item.get("input", {}) or {}
                        category = categorize_tool(tool_name)
                        summary = extract_tool_input_summary(tool_name, tool_input)

                        tool_events.append({
                            "timestamp": ts or first_ts or "",
                            "session_id": session_id,
                            "project": project,
                            "tool_name": tool_name,
                            "tool_category": category,
                            "tool_input_summary": summary,
                            "duration_ms": None,
                            "exit_code": None,
                        })

    duration_sec = calc_duration_sec(first_ts, last_ts)

    session = {
        "session_id": session_id,
        "start_time": first_ts or "",
        "end_time": last_ts,
        "project": project,
        "model": model,
        "git_branch": git_branch,
        "input_tokens": input_tokens,
        "cache_read_tokens": cache_read_tokens,
        "cache_write_tokens": cache_write_tokens,
        "output_tokens": output_tokens,
        "total_messages": total_messages,
        "duration_sec": duration_sec or 0,
    }

    # サブエージェントの agent_events 生成
    if is_subagent and agent_id:
        # agentType の推定: ファイル名のエージェントIDから slug や agentId を使用
        # 詳細な agentType は records から取れないため "subagent" をデフォルトとする
        # （将来的に records 内の情報から補完可能）
        agent_type = "subagent"
        agent_events.append({
            "agent_id": agent_id,
            "agent_type": agent_type,
            "project": project,
            "start_time": first_ts or "",
            "end_time": last_ts,
            "duration_sec": duration_sec,
        })

    return {
        "session_id": session_id,
        "project": project,
        "session": session,
        "tool_events": tool_events,
        "agent_events": agent_events,
        "is_subagent": is_subagent,
    }


# =====================================================================
# DB書き込み
# =====================================================================

def upsert_session(conn: sqlite3.Connection, session: dict) -> None:
    """sessions テーブルへの UPSERT。"""
    conn.execute(
        """
        INSERT INTO sessions (
            session_id, start_time, end_time, project, model, git_branch,
            input_tokens, cache_read_tokens, cache_write_tokens, output_tokens,
            total_messages, duration_sec
        ) VALUES (
            :session_id, :start_time, :end_time, :project, :model, :git_branch,
            :input_tokens, :cache_read_tokens, :cache_write_tokens, :output_tokens,
            :total_messages, :duration_sec
        )
        ON CONFLICT(session_id) DO UPDATE SET
            end_time = excluded.end_time,
            model = COALESCE(excluded.model, sessions.model),
            git_branch = COALESCE(excluded.git_branch, sessions.git_branch),
            input_tokens = excluded.input_tokens,
            cache_read_tokens = excluded.cache_read_tokens,
            cache_write_tokens = excluded.cache_write_tokens,
            output_tokens = excluded.output_tokens,
            total_messages = excluded.total_messages,
            duration_sec = excluded.duration_sec
        """,
        session,
    )


def insert_tool_events(conn: sqlite3.Connection, tool_events: list) -> None:
    """tool_events テーブルへの挿入（session_idのイベントを先にDELETEして再挿入）。"""
    if not tool_events:
        return
    session_id = tool_events[0]["session_id"]
    conn.execute("DELETE FROM tool_events WHERE session_id = ?", (session_id,))
    conn.executemany(
        """
        INSERT INTO tool_events (
            timestamp, session_id, project, tool_name, tool_category,
            tool_input_summary, duration_ms, exit_code
        ) VALUES (
            :timestamp, :session_id, :project, :tool_name, :tool_category,
            :tool_input_summary, :duration_ms, :exit_code
        )
        """,
        tool_events,
    )


def insert_agent_events(conn: sqlite3.Connection, agent_events: list) -> None:
    """agent_events テーブルへの挿入（agent_idのイベントを先にDELETEして再挿入）。"""
    if not agent_events:
        return
    for ev in agent_events:
        conn.execute("DELETE FROM agent_events WHERE agent_id = ?", (ev["agent_id"],))
        conn.execute(
            """
            INSERT INTO agent_events (
                agent_id, agent_type, project, start_time, end_time, duration_sec
            ) VALUES (
                :agent_id, :agent_type, :project, :start_time, :end_time, :duration_sec
            )
            """,
            ev,
        )


# =====================================================================
# メイン処理
# =====================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description="過去のClaude Codeトランスクリプト（JSONL）をSQLiteに投入する"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="DB書き込みを行わずに解析結果のみ表示する",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="詳細なログを表示する",
    )
    args = parser.parse_args()

    dry_run: bool = args.dry_run
    verbose: bool = args.verbose

    if dry_run:
        print("[DRY-RUN] DB書き込みは行いません")

    # JONLファイルの収集
    print(f"Scanning {PROJECTS_DIR}...")
    all_jsonl = list(PROJECTS_DIR.glob("**/*.jsonl"))
    total_files = len(all_jsonl)

    if total_files == 0:
        print("JONLファイルが見つかりませんでした。")
        sys.exit(0)

    # プロジェクト別にグループ化
    project_files: dict[str, list[Path]] = {}
    for f in all_jsonl:
        parts = f.parts
        projects_idx = None
        for i, part in enumerate(parts):
            if part == "projects":
                projects_idx = i
                break
        proj_dir = parts[projects_idx + 1] if projects_idx is not None and len(parts) > projects_idx + 1 else "unknown"
        proj_name = extract_project_name(proj_dir)
        project_files.setdefault(proj_name, []).append(f)

    print(f"Found {total_files} JSONL files across {len(project_files)} projects")

    # DB接続
    conn: Optional[sqlite3.Connection] = None
    if not dry_run:
        conn = sqlite3.connect(DB_PATH)
        conn.execute("PRAGMA journal_mode=WAL")

    total_tool_events = 0
    total_sessions = 0
    total_agent_events = 0
    total_skipped = 0

    try:
        for proj_name, files in sorted(project_files.items()):
            file_count = len(files)
            proj_tool_events = 0
            proj_sessions = 0
            proj_agent_events = 0

            print(f"Processing: {proj_name} ({file_count} files)...")

            for idx, jsonl_path in enumerate(files, start=1):
                if verbose:
                    print(f"  [{idx}/{file_count}] {jsonl_path.name}")

                result = parse_jsonl(jsonl_path)
                if not result:
                    total_skipped += 1
                    if verbose:
                        print(f"    -> スキップ（空またはエラー）")
                    continue

                session = result["session"]
                tool_events = result["tool_events"]
                agent_events = result["agent_events"]

                if verbose:
                    print(
                        f"    -> session={result['session_id'][:8]}..."
                        f"  tools={len(tool_events)}"
                        f"  agents={len(agent_events)}"
                    )

                if not dry_run and conn:
                    upsert_session(conn, session)
                    insert_tool_events(conn, tool_events)
                    insert_agent_events(conn, agent_events)
                    conn.commit()

                proj_tool_events += len(tool_events)
                proj_sessions += 1
                proj_agent_events += len(agent_events)

                # プログレス表示（verboseでない場合）
                if not verbose and idx < file_count:
                    print(
                        f"\r  [{idx}/{file_count}] Processed"
                        f" {proj_tool_events:,} tool events,"
                        f" {proj_sessions} sessions",
                        end="",
                        flush=True,
                    )

            # プロジェクト完了（最終行を上書き）
            if not verbose:
                print(
                    f"\r  [{file_count}/{file_count}]"
                    f" Processed {proj_tool_events:,} tool events,"
                    f" {proj_sessions} sessions"
                )
            else:
                print(
                    f"  [{file_count}/{file_count}]"
                    f" Processed {proj_tool_events:,} tool events,"
                    f" {proj_sessions} sessions"
                )

            total_tool_events += proj_tool_events
            total_sessions += proj_sessions
            total_agent_events += proj_agent_events

    finally:
        if conn:
            conn.close()

    print()
    print(
        f"Done! Total:"
        f" {total_tool_events:,} tool events,"
        f" {total_sessions} sessions,"
        f" {total_agent_events} agent events"
        + (f" (skipped: {total_skipped})" if total_skipped else "")
    )

    if dry_run:
        print("[DRY-RUN] DB書き込みは行われませんでした")


if __name__ == "__main__":
    main()
