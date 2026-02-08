#!/usr/bin/env bats
# =============================================================================
# BATS Tests for timeout.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

# =============================================================================
# 基本関数テスト
# =============================================================================

@test "timeout: get_epoch returns valid epoch" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && get_epoch"
  [ "$status" -eq 0 ]
  # epoch秒は10桁の数値
  [[ "$output" =~ ^[0-9]{10}$ ]]
}

@test "timeout: is_timed_out detects timeout" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && is_timed_out 1000000000 100"
  [ "$status" -eq 0 ]  # タイムアウト
}

@test "timeout: is_timed_out detects no timeout" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    start=\$(get_epoch)
    is_timed_out \"\$start\" 100
  "
  [ "$status" -eq 1 ]  # 未タイムアウト
}

@test "timeout: get_remaining_seconds returns correct value" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    start=\$(get_epoch)
    sleep 1
    remaining=\$(get_remaining_seconds \"\$start\" 10)
    # 残り時間は8-9秒（9秒以下）
    [[ \$remaining -le 9 ]] && [[ \$remaining -ge 8 ]]
  "
  [ "$status" -eq 0 ]
}

@test "timeout: get_remaining_seconds returns 0 for expired" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && get_remaining_seconds 1000000000 100"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "timeout: format_remaining formats 0s" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && format_remaining 0"
  [ "$status" -eq 0 ]
  [ "$output" = "0s" ]
}

@test "timeout: format_remaining formats seconds only" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && format_remaining 45"
  [ "$status" -eq 0 ]
  [ "$output" = "45s" ]
}

@test "timeout: format_remaining formats minutes and seconds" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && format_remaining 125"
  [ "$status" -eq 0 ]
  [ "$output" = "2m05s" ]
}

@test "timeout: format_remaining formats hours, minutes, seconds" {
  run bash -c "source '$PROJECT_ROOT/lib/timeout.sh' && format_remaining 3661"
  [ "$status" -eq 0 ]
  [ "$output" = "1h01m01s" ]
}

# =============================================================================
# セッション・タスクタイムアウト
# =============================================================================

@test "timeout: check_session_timeout detects timeout" {
  run bash -c "
    export TIMEOUT_SESSION_SECONDS=1
    source '$PROJECT_ROOT/lib/timeout.sh'
    sleep 2
    check_session_timeout \$((\$(get_epoch) - 2))
  "
  [ "$status" -eq 0 ]  # タイムアウト
}

@test "timeout: check_task_timeout detects no timeout" {
  run bash -c "
    export TIMEOUT_TASK_SECONDS=100
    source '$PROJECT_ROOT/lib/timeout.sh'
    start=\$(get_epoch)
    check_task_timeout \"\$start\"
  "
  [ "$status" -eq 1 ]  # 未タイムアウト
}

# =============================================================================
# JSON出力
# =============================================================================

@test "timeout: timeout_status_json outputs valid JSON" {
  run bash -c "
    source '$PROJECT_ROOT/lib/timeout.sh'
    start=\$(get_epoch)
    timeout_status_json \"\$start\" \"\$start\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\"session\":" ]]
  [[ "$output" =~ "\"task\":" ]]
  [[ "$output" =~ "\"elapsed_seconds\":" ]]
  [[ "$output" =~ "\"remaining_seconds\":" ]]
  [[ "$output" =~ "\"timed_out\":" ]]
}
