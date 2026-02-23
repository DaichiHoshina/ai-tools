#!/usr/bin/env bats
# =============================================================================
# E2E Tests for sync.sh - 実際にファイルコピーを実行して検証
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export ORIGINAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude"
}

teardown() {
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# =============================================================================
# sync.sh to-local: 実ファイルコピー検証
# =============================================================================

@test "e2e: sync to-local copies CLAUDE.md" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -f "$HOME/.claude/CLAUDE.md" ]
  # 内容がリポジトリと一致
  diff -q "${PROJECT_ROOT}/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
}

@test "e2e: sync to-local copies commands directory" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/commands" ]
  [ -f "$HOME/.claude/commands/git-push.md" ]
  [ -f "$HOME/.claude/commands/flow.md" ]
  [ -f "$HOME/.claude/commands/dev.md" ]
}

@test "e2e: sync to-local copies hooks directory" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/hooks" ]
  [ -f "$HOME/.claude/hooks/session-start.sh" ]
  [ -f "$HOME/.claude/hooks/pre-tool-use.sh" ]
  [ -f "$HOME/.claude/hooks/pre-compact.sh" ]
  [ -f "$HOME/.claude/hooks/stop.sh" ]
}

@test "e2e: sync to-local copies agents without .archive" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/agents" ]
  [ -f "$HOME/.claude/agents/po-agent.md" ]
  # .archiveディレクトリ内のファイルはコピーされない
  [ ! -f "$HOME/.claude/agents/spec-agent.md" ]
}

@test "e2e: sync to-local copies guidelines" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/guidelines" ]
  [ -f "$HOME/.claude/guidelines/common/guardrails.md" ]
}

@test "e2e: sync to-local copies skills" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/skills" ]
}

@test "e2e: sync to-local copies lib" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local
  [ -d "$HOME/.claude/lib" ]
  [ -f "$HOME/.claude/lib/security-functions.sh" ]
  [ -f "$HOME/.claude/lib/hook-utils.sh" ]
}

# =============================================================================
# sync後のdiff検証
# =============================================================================

@test "e2e: no diff after sync to-local" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local

  # diff出力が差分なし（「差分なし」メッセージが含まれる）
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq 0 ]
  [[ "$output" =~ "差分なし" ]]
}

# =============================================================================
# 冪等性: 2回実行しても結果が同じ
# =============================================================================

@test "e2e: sync to-local is idempotent" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local

  # 1回目のCLAUDE.mdのチェックサム
  local first_checksum
  first_checksum=$(md5sum "$HOME/.claude/CLAUDE.md" | cut -d' ' -f1)

  # 2回目の実行
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local

  # 同じチェックサム
  local second_checksum
  second_checksum=$(md5sum "$HOME/.claude/CLAUDE.md" | cut -d' ' -f1)
  [ "$first_checksum" = "$second_checksum" ]
}

# =============================================================================
# hooks実行権限の検証
# =============================================================================

@test "e2e: synced hooks are executable" {
  echo "y" | bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local

  for hook in "$HOME/.claude/hooks/"*.sh; do
    [ -x "$hook" ] || fail "Hook not executable: $hook"
  done
}

# =============================================================================
# .env セキュリティ: source が使われていないことを確認
# =============================================================================

@test "e2e: sync.sh does not use 'source .env'" {
  run grep -n 'source.*\.env' "${PROJECT_ROOT}/claude-code/sync.sh"
  [ "$status" -eq 1 ]  # grepが見つからない（status=1）
}
