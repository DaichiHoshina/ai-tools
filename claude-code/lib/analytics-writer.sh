#!/usr/bin/env bash
# =============================================================================
# analytics-writer.sh - Claude Code利用状況分析用SQLite書き込みライブラリ
# フック等から呼び出し、セッション・ツール・エージェント情報をSQLiteに記録
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/analytics-writer.sh
#   analytics_init          # DB初期化（初回自動実行）
#   analytics_insert_tool_event "$session_id" "$project" "$tool_name" "$tool_category"
#   analytics_insert_session "$session_id" "$project" ...
#   analytics_insert_agent_start "$agent_id" "$agent_type" "$project"
#   analytics_update_agent_stop "$agent_id"
#
# 設計方針:
#   - 書き込み失敗は stderr に warn 出力して続行（本処理を止めない）
#   - DB未存在時は自動作成（マイグレーション込み）
# =============================================================================

set -euo pipefail

# --- 定数 ---
ANALYTICS_DB_DIR="${HOME}/.claude/analytics"
ANALYTICS_DB="${ANALYTICS_DB_DIR}/analytics.db"

# --- 重複読み込み防止 ---
if [[ "${_ANALYTICS_WRITER_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_ANALYTICS_WRITER_LOADED=true

# --- 前提条件チェック ---
_analytics_check_deps() {
    if ! command -v sqlite3 &>/dev/null; then
        echo "WARNING: sqlite3 not found, analytics disabled" >&2
        return 1
    fi
    return 0
}

# --- DB初期化 ---
analytics_init() {
    _analytics_check_deps || return 1

    mkdir -p "$ANALYTICS_DB_DIR"

    # 並列セッション対応: WAL mode + busy_timeout で同時書き込み競合を回避
    # stdout は全て破棄（PRAGMA 出力が hook の JSON レスポンスに混入するのを防ぐ）
    sqlite3 "$ANALYTICS_DB" >/dev/null <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=3000;
CREATE TABLE IF NOT EXISTS tool_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    session_id TEXT NOT NULL,
    project TEXT NOT NULL,
    tool_name TEXT NOT NULL,
    tool_category TEXT NOT NULL DEFAULT 'builtin',
    tool_input_summary TEXT,
    duration_ms INTEGER,
    exit_code INTEGER
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    start_time TEXT NOT NULL,
    end_time TEXT,
    project TEXT NOT NULL,
    model TEXT,
    git_branch TEXT,
    input_tokens INTEGER DEFAULT 0,
    cache_read_tokens INTEGER DEFAULT 0,
    cache_write_tokens INTEGER DEFAULT 0,
    output_tokens INTEGER DEFAULT 0,
    total_messages INTEGER DEFAULT 0,
    duration_sec INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS agent_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    agent_type TEXT NOT NULL,
    project TEXT NOT NULL,
    start_time TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    end_time TEXT,
    duration_sec INTEGER
);

CREATE INDEX IF NOT EXISTS idx_tool_events_session ON tool_events(session_id);
CREATE INDEX IF NOT EXISTS idx_tool_events_timestamp ON tool_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_tool_events_tool_name ON tool_events(tool_name);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_agent_events_agent_id ON agent_events(agent_id);
SQL
    return $?
}

# --- 安全なSQLite実行ラッパー ---
# busy_timeout 3秒を SQL 内で設定（-cmd 指定は PRAGMA 値を stdout に出力するため使わない）
# stdout は全て破棄（hook の JSON レスポンス汚染防止）。INSERT/UPDATE しか呼ばれない設計
_analytics_exec() {
    local sql="$1"
    if ! sqlite3 "$ANALYTICS_DB" "PRAGMA busy_timeout=3000; ${sql}" >/dev/null 2>/dev/null; then
        echo "WARNING: analytics write failed" >&2
        return 1
    fi
    return 0
}

# --- ツールカテゴリ判定 ---
_analytics_tool_category() {
    local tool_name="$1"
    case "$tool_name" in
        Skill|SlashCommand) echo "skill" ;;
        Agent|Task*)        echo "agent" ;;
        mcp__*)             echo "mcp" ;;
        Read|Write|Edit|Glob|Grep|Bash|WebFetch|WebSearch) echo "builtin" ;;
        *)                  echo "builtin" ;;
    esac
}

# --- ツールイベント記録 ---
# Usage: analytics_insert_tool_event "$session_id" "$project" "$tool_name" ["$input_summary"]
analytics_insert_tool_event() {
    local session_id="${1:-unknown}"
    local project="${2:-unknown}"
    local tool_name="${3:-unknown}"
    local input_summary="${4:-}"
    local category
    category=$(_analytics_tool_category "$tool_name")

    # DB未初期化なら初期化
    [[ -f "$ANALYTICS_DB" ]] || analytics_init || return 1

    # シングルクォートのエスケープ
    input_summary="${input_summary//\'/\'\'}"

    _analytics_exec "INSERT INTO tool_events (session_id, project, tool_name, tool_category, tool_input_summary) VALUES ('${session_id}', '${project}', '${tool_name}', '${category}', '${input_summary}');"
}

# --- セッション開始記録 ---
# Usage: analytics_start_session "$session_id" "$project"
analytics_start_session() {
    local session_id="${1:-unknown}"
    local project="${2:-unknown}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    [[ -f "$ANALYTICS_DB" ]] || analytics_init || return 1

    _analytics_exec "INSERT OR IGNORE INTO sessions (session_id, start_time, project) VALUES ('${session_id}', '${now}', '${project}');"
}

# --- セッション終了記録 ---
# Usage: analytics_insert_session "$session_id" "$project" "$model" "$git_branch" \
#          "$input_tokens" "$cache_read" "$cache_write" "$output_tokens" "$total_messages" "$duration"
# start_timeが既に記録されていればそれを使い、なければ現在時刻をフォールバック
analytics_insert_session() {
    local session_id="${1:-unknown}"
    local project="${2:-unknown}"
    local model="${3:-unknown}"
    local git_branch="${4:-}"
    local input_tokens="${5:-0}"
    local cache_read="${6:-0}"
    local cache_write="${7:-0}"
    local output_tokens="${8:-0}"
    local total_messages="${9:-0}"
    local duration="${10:-0}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    [[ -f "$ANALYTICS_DB" ]] || analytics_init || return 1

    sqlite3 "$ANALYTICS_DB" "INSERT OR REPLACE INTO sessions (session_id, start_time, end_time, project, model, git_branch, input_tokens, cache_read_tokens, cache_write_tokens, output_tokens, total_messages, duration_sec) VALUES ('${session_id}', COALESCE((SELECT start_time FROM sessions WHERE session_id = '${session_id}'), '${now}'), '${now}', '${project}', '${model}', '${git_branch}', ${input_tokens}, ${cache_read}, ${cache_write}, ${output_tokens}, ${total_messages}, CAST((julianday('${now}') - julianday(COALESCE((SELECT start_time FROM sessions WHERE session_id = '${session_id}'), '${now}'))) * 86400 AS INTEGER));" 2>/dev/null || {
        echo "WARNING: analytics session write failed" >&2
        return 1
    }
}

# --- エージェント開始記録 ---
# Usage: analytics_insert_agent_start "$agent_id" "$agent_type" "$project"
analytics_insert_agent_start() {
    local agent_id="${1:-unknown}"
    local agent_type="${2:-unknown}"
    local project="${3:-unknown}"

    [[ -f "$ANALYTICS_DB" ]] || analytics_init || return 1

    _analytics_exec "INSERT INTO agent_events (agent_id, agent_type, project) VALUES ('${agent_id}', '${agent_type}', '${project}');"
}

# --- 古いレコードのクリーンアップ ---
# Usage: analytics_cleanup_old_records [days]
# デフォルト 90日超のレコードを削除。DB肥大化防止のため session-end から日次で呼ばれる。
# 設計:
#   - WAL + busy_timeout で並列セッションの INSERT と共存
#   - VACUUM は削除行数が閾値を超えたときのみ実行（排他ロック時間を最小化）
#   - end_time IS NULL の孤児 sessions も start_time 基準で削除（整合性維持）
#   - 失敗時もフラグを立てて翌日まで再試行抑制（ログ汚染防止）
#   - 失敗時の stderr は analytics-errors.log に追記（監視可能化）
analytics_cleanup_old_records() {
    local days="${1:-90}"
    local vacuum_threshold="${2:-1000}"  # 削除行数がこれを超えたら VACUUM
    [[ -f "$ANALYTICS_DB" ]] || return 0

    # 日次実行フラグ（同日複数回実行を抑制、成功/失敗問わず当日は再試行しない）
    local flag_file="${ANALYTICS_DB_DIR}/.cleanup-$(date -u +%Y%m%d)"
    [[ -f "$flag_file" ]] && return 0

    _analytics_check_deps || return 1

    local log_dir="${HOME}/.claude/logs"
    local err_log="${log_dir}/analytics-errors.log"
    mkdir -p "$log_dir" 2>/dev/null || true

    # 既存 DB への WAL 冪等適用（init 未経由でも WAL 化保証）。出力は捨てる
    sqlite3 -cmd "PRAGMA busy_timeout=3000;" "$ANALYTICS_DB" "PRAGMA journal_mode=WAL;" >/dev/null 2>>"$err_log" || true

    # 削除実行（busy_timeout は SQL 内で設定）
    local sqlite_out sqlite_status
    sqlite_out=$(sqlite3 "$ANALYTICS_DB" <<SQL 2>>"$err_log"
PRAGMA busy_timeout=5000;
DELETE FROM tool_events WHERE timestamp < datetime('now', '-${days} days');
DELETE FROM agent_events WHERE start_time < datetime('now', '-${days} days');
DELETE FROM sessions WHERE start_time < datetime('now', '-${days} days')
  AND (end_time IS NULL OR end_time < datetime('now', '-${days} days'));
SELECT total_changes();
SQL
    )
    sqlite_status=$?

    if [[ $sqlite_status -ne 0 ]]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] analytics cleanup DELETE failed (exit=${sqlite_status})" >>"$err_log"
        # 失敗時もフラグ立てて翌日まで抑制（無限リトライ防止）
        touch "$flag_file" 2>/dev/null || true
        return 1
    fi

    # sqlite3 バージョンによっては PRAGMA 設定時も値を stdout に出すため、
    # tail -n 1 で SELECT total_changes() の結果のみ抽出する
    local deleted
    deleted=$(printf '%s\n' "$sqlite_out" | tail -n 1)
    [[ "$deleted" =~ ^[0-9]+$ ]] || deleted=0

    # VACUUM は削除行数が閾値超のときのみ（排他ロック時間短縮）
    # stdout 破棄（PRAGMA 出力が session-end hook の JSON レスポンスに混入するのを防ぐ）
    if (( deleted > vacuum_threshold )); then
        if ! sqlite3 "$ANALYTICS_DB" "PRAGMA busy_timeout=10000; VACUUM;" >/dev/null 2>>"$err_log"; then
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] analytics VACUUM failed (deleted=${deleted})" >>"$err_log"
            # VACUUM 失敗は致命的ではない（次回再試行される）
        fi
    fi

    # 古いフラグファイル掃除（7日超）+ 今回フラグ作成
    find "$ANALYTICS_DB_DIR" -maxdepth 1 -name ".cleanup-*" -type f -mtime +7 -delete 2>/dev/null || true
    touch "$flag_file" 2>/dev/null || true
    return 0
}

# --- エージェント終了記録 ---
# Usage: analytics_update_agent_stop "$agent_id"
analytics_update_agent_stop() {
    local agent_id="${1:-unknown}"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    [[ -f "$ANALYTICS_DB" ]] || analytics_init || return 1

    _analytics_exec "UPDATE agent_events SET end_time='${now}', duration_sec=CAST((julianday('${now}') - julianday(start_time)) * 86400 AS INTEGER) WHERE agent_id='${agent_id}' AND end_time IS NULL;"
}
