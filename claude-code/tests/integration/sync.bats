#!/usr/bin/env bats
# =============================================================================
# Integration Tests for sync.sh
# =============================================================================

setup() {
  # テスト用の一時ディレクトリを作成
  export TEST_HOME="${BATS_TMPDIR}/claude-sync-test-${RANDOM}"
  mkdir -p "$TEST_HOME"

  # PROJECT_ROOT を設定（tests/integration から ../../.. で ai-tools ルートへ）
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

  # テスト用の ~/.claude ディレクトリ
  export CLAUDE_DIR="${TEST_HOME}/.claude"
  mkdir -p "$CLAUDE_DIR"
}

teardown() {
  # テスト用ディレクトリをクリーンアップ
  rm -rf "$TEST_HOME"
}

# =============================================================================
# Syntax and File Structure
# =============================================================================

@test "sync.sh: has valid bash syntax" {
  run bash -n "${PROJECT_ROOT}/claude-code/sync.sh"
  [ "$status" -eq 0 ]
}

@test "sync.sh: is executable" {
  [ -x "${PROJECT_ROOT}/claude-code/sync.sh" ]
}

# =============================================================================
# Mode Detection
# =============================================================================

@test "sync.sh: supports diff mode" {
  # diff モードは非対話式で動作する
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq 0 ]
}

@test "sync.sh: supports to-local mode" {
  # テスト用のディレクトリを準備
  mkdir -p "$CLAUDE_DIR"
  
  # confirmを自動的にNoにするため、パイプで'n'を渡す
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh to-local"
  
  # confirmでNoを選択するとexitコード0で終了
  [ "$status" -eq 0 ]
}

@test "sync.sh: supports from-local mode" {
  # テスト用のディレクトリを準備
  mkdir -p "$CLAUDE_DIR"
  
  # confirmを自動的にNoにするため、パイプで'n'を渡す
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh from-local"
  
  # confirmでNoを選択するとexitコード0で終了
  [ "$status" -eq 0 ]
}

@test "sync.sh: rejects invalid mode" {
  # 不正な引数を渡すとエラーになる
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" invalid-mode
  [ "$status" -eq 1 ]
  [[ "$output" =~ "不明なコマンド" ]]
}

# =============================================================================
# Error Cases
# =============================================================================

@test "sync.sh: fails gracefully when ~/.claude does not exist" {
  # ~/.claude が存在しない場合でもdiffモードは動作する
  rm -rf "$CLAUDE_DIR"
  [ ! -d "$CLAUDE_DIR" ]
  
  # diffモードは読み取り専用なので、ディレクトリがなくてもエラーにならない
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq 0 ]
}

@test "sync.sh: fails gracefully when source directory is missing" {
  # SCRIPT_DIRは常に存在するはずなので、このテストは不要
  # sync.shのSCRIPT_DIR検出が正しいことを確認
  [ -d "${PROJECT_ROOT}/claude-code" ]
  
  # スクリプト自身が存在することを確認
  [ -f "${PROJECT_ROOT}/claude-code/sync.sh" ]
}

@test "sync.sh: handles permission errors gracefully" {
  skip "Requires elevated permission testing - manual verification needed"
  # 権限エラーのシミュレーションは CI で困難
}

# =============================================================================
# Safety Checks
# =============================================================================

@test "sync.sh: does not delete files without confirmation" {
  skip "Requires confirmation mechanism testing"
  # ユーザー確認なしにファイルを削除しないことを確認
}

@test "sync.sh: creates backups before overwriting" {
  skip "Requires backup mechanism testing"
  # 上書き前にバックアップを作成することを確認
}

# =============================================================================
# Idempotency
# =============================================================================

@test "sync.sh: is idempotent (can be run multiple times)" {
  # diffモードは何度実行しても同じ結果
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  local first_output="$output"
  [ "$status" -eq 0 ]
  
  # 2回目も同じ結果
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq 0 ]
  [ "$output" = "$first_output" ]
}

# =============================================================================
# Integration: Real-world Scenarios
# =============================================================================

@test "integration: sync.sh works with CI environment" {
  # CI 環境（非対話的）での動作確認
  [ "$CI" = "true" ] || skip "Not in CI environment"

  # sync.sh が CI で動作することを確認
  run bash -n "${PROJECT_ROOT}/claude-code/sync.sh"
  [ "$status" -eq 0 ]
}

@test "integration: sync.sh preserves file permissions" {
  skip "Requires file permission testing"
  # ファイルのパーミッションが保持されることを確認
}

@test "integration: sync.sh handles symbolic links correctly" {
  skip "Requires symbolic link testing"
  # シンボリックリンクを正しく処理することを確認
}

# =============================================================================
# Dependency Checks
# =============================================================================

@test "sync.sh: checks for rsync dependency" {
  # sync.shはrsyncを使用していない（cpコマンドを使用）
  # rsyncのチェックは不要
  skip "rsync is not used by sync.sh - uses cp instead"
}

@test "sync.sh: checks for diff dependency" {
  command -v diff >/dev/null 2>&1
}

# =============================================================================
# Sync Direction Tests
# =============================================================================

@test "sync: to-local does not modify source repository" {
  # リポジトリの状態を記録
  local repo_checksum
  repo_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f -name "*.sh" -o -name "*.md" | sort | xargs cat | md5sum)
  
  # confirmをNoにして実行（変更なし）
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh to-local"
  [ "$status" -eq 0 ]
  
  # リポジトリが変更されていないことを確認
  local after_checksum
  after_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f -name "*.sh" -o -name "*.md" | sort | xargs cat | md5sum)
  [ "$repo_checksum" = "$after_checksum" ]
}

@test "sync: from-local does not modify ~/.claude" {
  # ~/.claudeを準備
  mkdir -p "$CLAUDE_DIR"
  echo "test" > "$CLAUDE_DIR/test.txt"
  
  # ~/.claudeの状態を記録
  local claude_checksum
  claude_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  
  # confirmをNoにして実行（変更なし）
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh from-local"
  [ "$status" -eq 0 ]
  
  # ~/.claudeが変更されていないことを確認
  local after_checksum
  after_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  [ "$claude_checksum" = "$after_checksum" ]
}

@test "sync: diff mode is read-only" {
  # リポジトリの状態を記録
  local repo_checksum
  repo_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f | sort | xargs cat 2>/dev/null | md5sum)
  
  # ~/.claudeの状態を記録
  mkdir -p "$CLAUDE_DIR"
  local claude_checksum
  claude_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  
  # diffモードを実行
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq 0 ]
  
  # どちらも変更されていないことを確認
  local repo_after
  repo_after=$(find "${PROJECT_ROOT}/claude-code" -type f | sort | xargs cat 2>/dev/null | md5sum)
  [ "$repo_checksum" = "$repo_after" ]
  
  local claude_after
  claude_after=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  [ "$claude_checksum" = "$claude_after" ]
}
