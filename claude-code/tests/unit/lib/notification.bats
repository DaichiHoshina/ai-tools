#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/hook-utils/notification.sh
# 方針: terminal-notifier / curl を stub 化して実送信を回避する
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils/notification.sh"
  export TEST_TMPDIR="$(mktemp -d)"
  export PATH="${TEST_TMPDIR}:${PATH}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}/.claude"
  export CLAUDE_STOP_NOTIFY_MIN_LEN=0
  unset CLAUDE_STOP_NOTIFY

  cat > "${TEST_TMPDIR}/terminal-notifier" << 'EOF'
#!/bin/bash
echo "$@" > "$TEST_TMPDIR/terminal-notifier.log"
EOF
  chmod +x "${TEST_TMPDIR}/terminal-notifier"

  cat > "${TEST_TMPDIR}/curl" << 'EOF'
#!/bin/bash
{
  echo "ARGS: $@"
  echo "STDIN: $(cat)"
} > "$TEST_TMPDIR/curl.log"
EOF
  chmod +x "${TEST_TMPDIR}/curl"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

_wait_for_file() {
  local f="$1" i=0
  while [ ! -f "$f" ] && [ "$i" -lt 500 ]; do
    sleep 0.01
    i=$((i + 1))
  done
}

@test "notification: sourcing does not produce output" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# send_stop_notification
# =============================================================================

@test "send_stop_notification: terminal-notifier に title/message を渡す" {
  local input='{"session_id":"s1","last_assistant_message":"test message","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '' 'Glass'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "test message" "${TEST_TMPDIR}/terminal-notifier.log"
}

@test "send_stop_notification: CLAUDE_STOP_NOTIFY=0 なら notify skip" {
  export CLAUDE_STOP_NOTIFY=0
  local input='{"session_id":"s1","last_assistant_message":"long enough message here","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
}

@test "send_stop_notification: session_id なし (fixture) は notify skip" {
  local input='{"last_assistant_message":"real event ではない fixture","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
}

@test "send_stop_notification: NTFY_TOPIC があれば curl で ntfy.sh を叩く" {
  export CLAUDE_NTFY_TOPIC="test-topic"
  local input='{"session_id":"s1","last_assistant_message":"hello","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/curl.log"
  [ -f "${TEST_TMPDIR}/curl.log" ]
  grep -q "ntfy.sh" "${TEST_TMPDIR}/curl.log"
}

@test "send_stop_notification: 空メッセージでも crash しない" {
  local input='{"session_id":"s1","last_assistant_message":"","cwd":"/tmp/project"}'
  run bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>&1
  [ "$status" -eq 0 ]
}

# =============================================================================
# build_terminal_sequence
# =============================================================================

@test "build_terminal_sequence: title を OSC 0 で埋め込む" {
  run bash -c "source '$LIB_FILE' && build_terminal_sequence 'MyTitle' '' 'false' | cat -v"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MyTitle" ]]
}

@test "build_terminal_sequence: include_bell=false なら末尾 BEL を含まない" {
  run bash -c "source '$LIB_FILE' && build_terminal_sequence 'T' 'B' 'false' | xxd | tail -1"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "07" ]] || true
}

@test "build_terminal_sequence: title/body 両方空でも crash しない" {
  run bash -c "source '$LIB_FILE' && build_terminal_sequence '' ''"
  [ "$status" -eq 0 ]
}
