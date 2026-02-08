#!/usr/bin/env bats
# =============================================================================
# BATS Tests for task-lock.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LOCK_DIR="${BATS_TMPDIR}/locks-$$"
  export LOCK_TTL_SECONDS=5
}

teardown() {
  rm -rf "$LOCK_DIR"
}

# =============================================================================
# ロック状態確認
# =============================================================================

@test "task-lock: check_lock returns UNLOCKED for non-existent lock" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    check_lock 'task-123'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "UNLOCKED" ]
}

@test "task-lock: check_lock returns LOCKED for active lock" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    check_lock 'task-123'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "LOCKED" ]
}

@test "task-lock: check_lock returns EXPIRED for expired lock" {
  run bash -c "
    export LOCK_TTL_SECONDS=1
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    sleep 2
    check_lock 'task-123'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "EXPIRED" ]
}

# =============================================================================
# ロック取得
# =============================================================================

@test "task-lock: acquire_lock succeeds for unlocked task" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
  "
  [ "$status" -eq 0 ]
}

@test "task-lock: acquire_lock is idempotent for same agent" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    acquire_lock 'task-123' 'agent-1'
  "
  [ "$status" -eq 0 ]
}

@test "task-lock: acquire_lock fails for different agent" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    acquire_lock 'task-123' 'agent-2' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "task-lock: acquire_lock succeeds for expired lock" {
  run bash -c "
    export LOCK_TTL_SECONDS=1
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    sleep 2
    acquire_lock 'task-123' 'agent-2'
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# ロック解放
# =============================================================================

@test "task-lock: release_lock removes lock file" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    release_lock 'task-123' 'agent-1'
    [[ ! -f \$LOCK_DIR/task_task-123.lock ]]
  "
  [ "$status" -eq 0 ]
}

@test "task-lock: release_lock fails for wrong owner" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    release_lock 'task-123' 'agent-2' 2>&1
  "
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ERROR" ]]
}

@test "task-lock: release_lock is idempotent" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    source '$PROJECT_ROOT/lib/task-lock.sh'
    acquire_lock 'task-123' 'agent-1'
    release_lock 'task-123' 'agent-1'
    release_lock 'task-123' 'agent-1'
  "
  [ "$status" -eq 0 ]
}
