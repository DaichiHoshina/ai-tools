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

@test "cleanup: 同日2回目の実行は cleanup_runs テーブルでスキップ" {
  # 1回目実行で cleanup_runs に今日のレコードが INSERT される
  analytics_cleanup_old_records 90

  # 古いレコード追加
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's1', 'p', 'Read', 'builtin');
  "

  # 2回目実行 → INSERT OR IGNORE が 0 件で取得失敗、削除されない
  run analytics_cleanup_old_records 90
  [ "$status" -eq 0 ]

  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM tool_events;")
  [ "$count" = "1" ]

  # cleanup_runs に今日のレコードが1件だけ存在することも確認
  local run_count
  run_count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM cleanup_runs WHERE run_date = date('now', 'utc');")
  [ "$run_count" = "1" ]
}

@test "cleanup: 並列実行でも DELETE は1回だけ、cleanup_runs の一意性が保証される" {
  # Warning 1/2 回帰テスト: 並列 session-end 同時発火しても INSERT OR IGNORE の
  # 原子性により 1 プロセスのみが実行権を取得する（ファイルフラグ race 回避）

  # 古いレコード追加
  sqlite3 "$ANALYTICS_DB" "
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's1', 'p', 'Read', 'builtin');
    INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
    VALUES (datetime('now', '-100 days'), 's2', 'p', 'Read', 'builtin');
  "

  # 4プロセス並列起動
  (analytics_cleanup_old_records 90 &)
  (analytics_cleanup_old_records 90 &)
  (analytics_cleanup_old_records 90 &)
  analytics_cleanup_old_records 90
  wait

  # cleanup_runs に今日のレコードは必ず 1 件のみ
  local run_count
  run_count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM cleanup_runs WHERE run_date = date('now', 'utc');")
  [ "$run_count" = "1" ]

  # 削除結果も正しい（古い 2 件が消えて 0 件）
  local count
  count=$(sqlite3 "$ANALYTICS_DB" "SELECT COUNT(*) FROM tool_events;")
  [ "$count" = "0" ]
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

@test "cleanup: VACUUM 発火で DB サイズが縮小する" {
  # Warning 4 回帰テスト: 大量 INSERT で DB を膨張させ、cleanup + VACUUM 発火で
  # サイズが縮小することを直接 assert する

  # 200 行の古いレコードを INSERT（十分な膨張を得るため input_summary に長い文字列を入れる）
  local i padding
  padding=$(printf '%0.sx' {1..200})  # 200文字の pad
  sqlite3 "$ANALYTICS_DB" "BEGIN;"
  for i in $(seq 1 200); do
    sqlite3 "$ANALYTICS_DB" "INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category, tool_input_summary)
      VALUES (datetime('now', '-100 days'), 's${i}', 'p', 'Read', 'builtin', '${padding}');"
  done

  # WAL チェックポイントでメインファイルに反映させてサイズ測定
  sqlite3 "$ANALYTICS_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null
  local size_before
  size_before=$(wc -c < "$ANALYTICS_DB")

  # 閾値 1 で VACUUM を確実に発火（削除 200 行 > 1）
  run analytics_cleanup_old_records 90 1
  [ "$status" -eq 0 ]

  sqlite3 "$ANALYTICS_DB" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null
  local size_after
  size_after=$(wc -c < "$ANALYTICS_DB")

  # VACUUM 後のサイズが膨張前より小さいことを確認
  [ "$size_after" -lt "$size_before" ]

  # 削除結果も正しい
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

# =============================================================================
# stdout 汚染防止（codex レビュー指摘の回帰テスト）
# hook は JSON レスポンス返すため、sqlite3 の PRAGMA 値が stdout に漏れると壊れる
# =============================================================================

@test "stdout: analytics_init は何も stdout に出力しない" {
  rm -f "$ANALYTICS_DB"
  unset _ANALYTICS_WRITER_LOADED 2>/dev/null || true
  local out
  out=$(analytics_init)
  [ -z "$out" ]
}

@test "stdout: analytics_insert_tool_event は何も stdout に出力しない" {
  local out
  out=$(analytics_insert_tool_event "s1" "p" "Read" "summary")
  [ -z "$out" ]
}

@test "stdout: analytics_start_session は何も stdout に出力しない" {
  local out
  out=$(analytics_start_session "s2" "p")
  [ -z "$out" ]
}

@test "stdout: analytics_insert_agent_start は何も stdout に出力しない" {
  local out
  out=$(analytics_insert_agent_start "a1" "dev" "p")
  [ -z "$out" ]
}

@test "stdout: cleanup 実行時にも何も stdout に出力しない（VACUUM 閾値超でも）" {
  # 大量の古いレコードを追加して VACUUM を発火させる
  local i
  for i in $(seq 1 5); do
    sqlite3 "$ANALYTICS_DB" "INSERT INTO tool_events (timestamp, session_id, project, tool_name, tool_category)
      VALUES (datetime('now', '-100 days'), 's${i}', 'p', 'Read', 'builtin');"
  done

  local out
  # 閾値 1 にして VACUUM を確実に発火
  out=$(analytics_cleanup_old_records 90 1)
  [ -z "$out" ]
}
