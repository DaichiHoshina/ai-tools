#!/usr/bin/env bats
# =============================================================================
# sync.sh 拡張機能テスト: --dry-run / --only / backup / rollback / lock / status
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export TEST_HOME="$(mktemp -d)"
  export CLAUDE_DIR="${TEST_HOME}/.claude"
  mkdir -p "$CLAUDE_DIR"
}

teardown() {
  [ -n "$TEST_HOME" ] && rm -rf "$TEST_HOME"
}

run_sync() {
  run env HOME="$TEST_HOME" CLAUDE_DIR="$CLAUDE_DIR" SKIP_GIT_CHECK=true \
    bash "${PROJECT_ROOT}/claude-code/sync.sh" "$@"
}

sync_once() {
  env HOME="$TEST_HOME" CLAUDE_DIR="$CLAUDE_DIR" SKIP_GIT_CHECK=true \
    bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes > /dev/null 2>&1
}

# =============================================================================
# --dry-run
# =============================================================================

@test "dry-run: to-local が何も反映しない" {
  run_sync to-local --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dry-run" ]]
  [ ! -d "$CLAUDE_DIR/commands" ]
  [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]
}

@test "dry-run: from-local が何も反映しない" {
  sync_once
  echo "LOCAL ONLY" >> "$CLAUDE_DIR/CLAUDE.md"
  run_sync from-local --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dry-run のため反映しない" ]]
  # repo 側 CLAUDE.global.md は変更されない
  ! grep -q "LOCAL ONLY" "${PROJECT_ROOT}/claude-code/CLAUDE.global.md"
}

# =============================================================================
# --only
# =============================================================================

@test "only: 指定 item だけ同期する" {
  run_sync to-local --yes --only=commands
  [ "$status" -eq 0 ]
  [[ "$output" =~ "--only: 同期対象を限定 (commands)" ]]
  [ -d "$CLAUDE_DIR/commands" ]
  [ ! -d "$CLAUDE_DIR/hooks" ]
  [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]
}

@test "only: 不明な item 名は fail-fast する" {
  run_sync to-local --yes --only=bogus
  [ "$status" -eq 1 ]
  [[ "$output" =~ "不明な item" ]]
}

@test "only: settings / Codex / Cursor 同期を skip する" {
  run_sync to-local --yes --only=commands
  [ "$status" -eq 0 ]
  [[ "$output" =~ "--only 指定のため" ]]
  [ ! -f "$CLAUDE_DIR/settings.json" ]
}

# =============================================================================
# Backup / Rollback
# =============================================================================

@test "backup: 2 回目以降の to-local で backup が作られる" {
  sync_once
  sync_once
  [ -d "$CLAUDE_DIR/.sync-backups" ]
  local count
  count=$(ls -1 "$CLAUDE_DIR/.sync-backups" | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "backup: --no-backup で作成を抑制する" {
  sync_once
  rm -rf "$CLAUDE_DIR/.sync-backups"
  run_sync to-local --yes --no-backup
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "backup 作成" ]]
  [ ! -d "$CLAUDE_DIR/.sync-backups" ]
}

@test "rollback: 直近 backup からローカル編集を復元する" {
  sync_once
  echo "LOCAL EDIT" >> "$CLAUDE_DIR/rules/plain-jp.md"
  sync_once
  ! grep -q "LOCAL EDIT" "$CLAUDE_DIR/rules/plain-jp.md"
  run_sync rollback --yes
  [ "$status" -eq 0 ]
  [[ "$output" =~ "rollback 完了" ]]
  grep -q "LOCAL EDIT" "$CLAUDE_DIR/rules/plain-jp.md"
}

@test "rollback: backup が無ければ exit 1" {
  run_sync rollback --yes
  [ "$status" -eq 1 ]
  [[ "$output" =~ "backup が存在しない" ]]
}

# =============================================================================
# Concurrency Lock
# =============================================================================

@test "lock: 死んだ process の stale lock は自動回収して続行する" {
  mkdir -p "$CLAUDE_DIR/.sync.lock"
  echo "999999" > "$CLAUDE_DIR/.sync.lock/pid"
  run_sync to-local --yes
  [ "$status" -eq 0 ]
  [[ "$output" =~ "stale lock" ]]
  [ ! -d "$CLAUDE_DIR/.sync.lock" ]
}

@test "lock: 生きている process の lock 中は実行を拒否する" {
  sleep 30 &
  local live_pid=$!
  mkdir -p "$CLAUDE_DIR/.sync.lock"
  echo "$live_pid" > "$CLAUDE_DIR/.sync.lock/pid"
  run_sync to-local --yes
  kill "$live_pid" 2>/dev/null || true
  [ "$status" -eq 1 ]
  [[ "$output" =~ "別の sync が実行中" ]]
}

# =============================================================================
# status
# =============================================================================

@test "status: version / last sync / backup / 差分をまとめて表示する" {
  sync_once
  run_sync status
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
  [[ "$output" =~ "repo VERSION" ]]
  [[ "$output" =~ "last sync" ]]
  [[ "$output" =~ "backups" ]]
  [[ "$output" =~ "to-local" ]]
}

# =============================================================================
# usage
# =============================================================================

@test "usage: 新 flag / mode が文書化されている" {
  run_sync
  [[ "$output" =~ "--dry-run" ]]
  [[ "$output" =~ "--only" ]]
  [[ "$output" =~ "--no-backup" ]]
  [[ "$output" =~ "status" ]]
  [[ "$output" =~ "rollback" ]]
}
