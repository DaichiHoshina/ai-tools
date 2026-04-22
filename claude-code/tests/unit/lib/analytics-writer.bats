#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/analytics-writer.sh (cleanup関数中心)
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/analytics-writer.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # 本番 DB を汚染しないよう HOME を差し替え
  export HOME="$TEST_TMPDIR"
  export ANALYTICS_DB_DIR="${HOME}/.claude/analytics"
  export ANALYTICS_DB="${ANALYTICS_DB_DIR}/analytics.db"

  mkdir -p "$ANALYTICS_DB_DIR"

  # 重複読み込みフラグをリセット
  unset _ANALYTICS_WRITER_LOADED 2>/dev/null || true

  # shellcheck disable=SC1090
  source "$LIB_FILE"
  analytics_init >/dev/null
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  unset _ANALYTICS_WRITER_LOADED 2>/dev/null || true
}

# =============================================================================
# Cleanup 基本動作
# =============================================================================

@test "cleanup: 90日超の tool_events が削除される" {
  # 100日前と1日前のレコードを直接 INSERT
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's1', 'p', 'Read', 'builtin');
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-1 days'), 's2', 'p', 'Read', 'builtin');
  "

  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]

  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM tool_events;")
  [ "$count" = "1" ]

  local session
  session=$(sqlite3 "$ANALYTICS_DB" "SELECT session_id FROM tool_events;")
  [ "$session" = "s2" ]
}

@test "cleanup: 90日超の agent_events が削除される" {
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO agent_events (agent_id, agent_type, project, start_time)
    VALUES ('a1', 'dev', 'p', datetime('now', '-100 days'));
    INSERT INTO agent_events (agent_id, agent_type, project, start_time)
    VALUES ('a2', 'dev', 'p', datetime('now', '-1 days'));
  "

  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]

  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM agent_events;")
  [ "$count" = "1" ]
}

@test "cleanup: end_time IS NULL の孤児 sessions も start_time 基準で削除される" {
  # 修正前は end_time IS NULL の行が永遠に残っていた（Warning 2 の再発防止テスト）
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO sessions (session_id, start_time, end_time, project)
    VALUES ('orphan', datetime('now', '-100 days'), NULL, 'p');
    INSERT INTO sessions (session_id, start_time, end_time, project)
    VALUES ('closed-old', datetime('now', '-100 days'), datetime('now', '-99 days'), 'p');
    INSERT INTO sessions (session_id, start_time, end_time, project)
    VALUES ('recent', datetime('now', '-1 days'), datetime('now'), 'p');
  "

  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]

  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM sessions;")
  [ "$count" = "1" ]

  local remaining
  remaining=$(sqlite3 "$ANALYTICS_DB" "SELECT session_id FROM sessions;")
  [ "$remaining" = "recent" ]
}

@test "cleanup: 同日2回目の実行はフラグでスキップ" {
  # 1回目実行でフラグ作成
  analytics_cleanup_old_records 90

  # 古いレコード追加
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's1', 'p', 'Read', 'builtin');
  "

  # 2回目実行 → フラグがあるのでスキップ（削除されない）
  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]

  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM tool_events;")
  [ "$count" = "1" ]
}

@test "cleanup: DB 不在時は no-op で return 0" {
  rm -f "$ANALYTICS_DB"

  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]
}

@test "cleanup: VACUUM は閾値超のみ実行（少量削除時はスキップ）" {
  # 閾値 1000、削除は1行のみ → VACUUM スキップされる
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's1', 'p', 'Read', 'builtin');
  "

  run analytics_cleanup_old_records 90 1000
  [ "$status" -eq 0 ]

  # ここでは VACUUM 実行有無の直接検出は難しいため、少なくとも削除成功を確認
  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM tool_events;")
  [ "$count" = "0" ]
}

# =============================================================================
# WAL mode 確認
# =============================================================================

@test "init: journal_mode が WAL に設定される" {
  local mode
  mode=$(sqlite3 "$ANALYTICS_DB" "PRAGMA journal_mode;")
  [ "$mode" = "wal" ]
}
