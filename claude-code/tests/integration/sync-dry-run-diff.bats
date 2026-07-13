#!/usr/bin/env bats
# =============================================================================
# Regression: --dry-run が settings.json (hooks/root keys) merge 差分を表示する
#
#   show_diff は SYNC_ITEMS のみが対象で、settings.json の template merge 結果
#   (sync_settings_hooks ほか) を --dry-run が一切表示していなかった問題の修正確認。
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

@test "dry-run: template と live settings.json に model 差分があると diff に表示される" {
  sync_once
  [ -f "$CLAUDE_DIR/settings.json" ]

  # live 側 root key を template と乖離させる（実 sync では template canonical で上書きされるはずの差分）
  local tmp
  tmp=$(mktemp)
  jq '.model = "stale-model-name"' "$CLAUDE_DIR/settings.json" > "$tmp"
  mv "$tmp" "$CLAUDE_DIR/settings.json"

  run_sync to-local --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "settings.json" ]]
  [[ "$output" =~ "stale-model-name" ]]

  # 実 file は書き換わらない（dry-run のため）
  local live_model
  live_model=$(jq -r '.model' "$CLAUDE_DIR/settings.json")
  [ "$live_model" = "stale-model-name" ]
}

@test "dry-run: settings.json に merge 差分がなければ merge 予定 diff は表示されない" {
  sync_once
  [ -f "$CLAUDE_DIR/settings.json" ]

  run_sync to-local --dry-run
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "settings.json (merge 予定)" ]]
}
