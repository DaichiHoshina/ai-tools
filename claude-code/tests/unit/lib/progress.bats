#!/usr/bin/env bats
# =============================================================================
# BATS Tests for progress.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROGRESS_DIR="${BATS_TMPDIR}/progress-$$"
  export PROGRESS_MAX_OUTPUT_BYTES=1024
}

teardown() {
  rm -rf "$PROGRESS_DIR"
}

# =============================================================================
# ディレクトリ管理
# =============================================================================

@test "progress: init_progress_dir creates directory" {
  run bash -c "source '$PROJECT_ROOT/lib/progress.sh' && init_progress_dir && [[ -d '$PROGRESS_DIR/sessions' ]]"
  [ "$status" -eq 0 ]
}

@test "progress: init_progress_dir creates .gitignore" {
  run bash -c "source '$PROJECT_ROOT/lib/progress.sh' && init_progress_dir && [[ -f '$PROGRESS_DIR/.gitignore' ]]"
  [ "$status" -eq 0 ]
}

# =============================================================================
# セッションIDサニタイズ
# =============================================================================

@test "progress: sanitize_session_id removes path traversal" {
  run bash -c "source '$PROJECT_ROOT/lib/progress.sh' && sanitize_session_id '../../../etc/passwd'"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "/" ]]
  [[ ! "$output" =~ "\.\." ]]
}

# =============================================================================
# 進捗更新・読み取り
# =============================================================================

@test "progress: update_session_progress creates file" {
  run bash -c "
    source '$PROJECT_ROOT/lib/progress.sh'
    update_session_progress 'test-123' 'implementation' 50 'Test progress'
    [[ -f \$(get_session_progress_path 'test-123') ]]
  "
  [ "$status" -eq 0 ]
}

@test "progress: read_session_progress returns content" {
  run bash -c "
    source '$PROJECT_ROOT/lib/progress.sh'
    update_session_progress 'test-123' 'implementation' 50 'Test progress'
    read_session_progress 'test-123'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test-123" ]]
  [[ "$output" =~ "implementation" ]]
  [[ "$output" =~ "50%" ]]
}

@test "progress: read_session_progress fails for non-existent session" {
  run bash -c "source '$PROJECT_ROOT/lib/progress.sh' && read_session_progress 'non-existent' 2>&1"
  [ "$status" -eq 1 ]
}

# =============================================================================
# クリーンアップ
# =============================================================================

@test "progress: cleanup_session_progress removes file" {
  run bash -c "
    source '$PROJECT_ROOT/lib/progress.sh'
    update_session_progress 'test-123' 'implementation' 50 'Test progress'
    cleanup_session_progress 'test-123'
    [[ ! -f \$(get_session_progress_path 'test-123') ]]
  "
  [ "$status" -eq 0 ]
}
