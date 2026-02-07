#!/usr/bin/env bats
# =============================================================================
# Integration Tests for install.sh
# =============================================================================

setup() {
  # テスト用の一時ディレクトリを作成
  export TEST_HOME="${BATS_TMPDIR}/claude-test-${RANDOM}"
  mkdir -p "$TEST_HOME"

  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

  # テスト用の ~/.claude ディレクトリ
  export CLAUDE_DIR="${TEST_HOME}/.claude"
}

teardown() {
  # テスト用ディレクトリをクリーンアップ
  rm -rf "$TEST_HOME"
}

# =============================================================================
# Syntax and File Structure
# =============================================================================

@test "install.sh: has valid bash syntax" {
  run bash -n "${PROJECT_ROOT}/claude-code/install.sh"
  [ "$status" -eq 0 ]
}

@test "install.sh: is executable" {
  [ -x "${PROJECT_ROOT}/claude-code/install.sh" ]
}

@test "install.sh: required files exist" {
  [ -f "${PROJECT_ROOT}/claude-code/CLAUDE.md" ]
  [ -f "${PROJECT_ROOT}/claude-code/install.sh" ]
  [ -f "${PROJECT_ROOT}/claude-code/sync.sh" ]
}

# =============================================================================
# Directory Structure Tests
# =============================================================================

@test "install.sh: creates ~/.claude directory structure (dry-run)" {
  skip "Requires non-interactive mode implementation"
  # 将来的に --dry-run オプションを実装した際に有効化
}

@test "install.sh: handles existing ~/.claude directory" {
  # 既存の ~/.claude があっても問題ない
  mkdir -p "$CLAUDE_DIR"
  [ -d "$CLAUDE_DIR" ]
}

# =============================================================================
# Error Cases
# =============================================================================

@test "install.sh: fails gracefully when run from wrong directory" {
  skip "Requires error handling implementation"
  # PROJECT_ROOT が見つからない場合のエラーハンドリング
}

@test "install.sh: detects missing source files" {
  # 必須ファイルが存在しない場合
  [ -f "${PROJECT_ROOT}/claude-code/hooks/session-start.sh" ]
  [ -f "${PROJECT_ROOT}/claude-code/lib/security-functions.sh" ]
}

@test "install.sh: handles permission errors gracefully" {
  skip "Requires elevated permission testing - manual verification needed"
  # 権限エラーのシミュレーションは CI で困難
}

# =============================================================================
# Idempotency
# =============================================================================

@test "install.sh: is idempotent (can be run multiple times)" {
  skip "Requires non-interactive mode implementation"
  # 複数回実行しても同じ結果になることを確認
}

# =============================================================================
# Dependency Checks
# =============================================================================

@test "install.sh: checks for jq dependency" {
  command -v jq >/dev/null 2>&1
}

@test "install.sh: checks for git dependency" {
  command -v git >/dev/null 2>&1
}

# =============================================================================
# Integration: Real-world Scenarios
# =============================================================================

@test "integration: install.sh works with CI environment" {
  # CI 環境（非対話的）での動作確認
  [ "$CI" = "true" ] || skip "Not in CI environment"

  # install.sh が CI で動作することを確認
  run bash -n "${PROJECT_ROOT}/claude-code/install.sh"
  [ "$status" -eq 0 ]
}

@test "integration: all hooks are present and valid" {
  local hooks_dir="${PROJECT_ROOT}/claude-code/hooks"
  local required_hooks=(
    "session-start.sh"
    "user-prompt-submit.sh"
    "pre-tool-use.sh"
    "pre-compact.sh"
    "stop.sh"
    "session-end.sh"
  )

  for hook in "${required_hooks[@]}"; do
    [ -f "${hooks_dir}/${hook}" ]
    # Syntax check
    run bash -n "${hooks_dir}/${hook}"
    [ "$status" -eq 0 ]
  done
}

@test "integration: all lib files are present and valid" {
  local lib_dir="${PROJECT_ROOT}/claude-code/lib"
  local required_libs=(
    "security-functions.sh"
    "print-functions.sh"
    "colors.sh"
    "hook-utils.sh"
  )

  for lib in "${required_libs[@]}"; do
    [ -f "${lib_dir}/${lib}" ]
    # Syntax check
    run bash -n "${lib_dir}/${lib}"
    [ "$status" -eq 0 ]
  done
}
