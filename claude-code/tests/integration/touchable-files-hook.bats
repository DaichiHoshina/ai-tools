#!/usr/bin/env bats
# touchable_files allowlist hook integration tests
# Subject: hooks/pre-tool-use.sh + hooks/lib/touchable-files-state.sh

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HOOK="${REPO_ROOT}/hooks/pre-tool-use.sh"
  export TMP_HOME="$(mktemp -d)"
  export HOME="$TMP_HOME"
  export CLAUDE_TOUCHABLE_ENFORCE=1
  mkdir -p "$HOME/.claude/state" "$HOME/.claude/logs"
  SID="touchable-test-$$-${RANDOM}"
}

teardown() {
  rm -rf "$TMP_HOME"
}

@test "touchable: state file 不在 → noop で通る" {
  INPUT=$(jq -nc --arg sid "$SID" --arg fp "/tmp/foo.txt" \
    '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $fp, content: "x"}}')
  run bash -c "echo '$INPUT' | '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "touchable: state file 内 path → 通る" {
  printf '/tmp/allowed.txt\n' > "$HOME/.claude/state/touchable-${SID}.txt"
  INPUT=$(jq -nc --arg sid "$SID" --arg fp "/tmp/allowed.txt" \
    '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $fp, content: "x"}}')
  run bash -c "echo '$INPUT' | '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "touchable: state file 外 path → exit 2 で block" {
  printf '/tmp/allowed.txt\n' > "$HOME/.claude/state/touchable-${SID}.txt"
  INPUT=$(jq -nc --arg sid "$SID" --arg fp "/tmp/forbidden.txt" \
    '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $fp, content: "x"}}')
  run bash -c "echo '$INPUT' | '$HOOK'"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "touchable-files-block" ]]
}

@test "touchable: opt-out env で block されない" {
  printf '/tmp/allowed.txt\n' > "$HOME/.claude/state/touchable-${SID}.txt"
  export CLAUDE_TOUCHABLE_ENFORCE=0
  INPUT=$(jq -nc --arg sid "$SID" --arg fp "/tmp/forbidden.txt" \
    '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $fp, content: "x"}}')
  run bash -c "CLAUDE_TOUCHABLE_ENFORCE=0 echo '$INPUT' | CLAUDE_TOUCHABLE_ENFORCE=0 '$HOOK'"
  [ "$status" -eq 0 ]
}

@test "touchable: TTL 超過 state file → noop + 自動削除" {
  STATE_FILE="$HOME/.claude/state/touchable-${SID}.txt"
  printf '/tmp/allowed.txt\n' > "$STATE_FILE"
  # 2 時間前に backdate (TTL=3600 超過)
  PAST=$(( $(date +%s) - 7200 ))
  touch -t "$(date -r $PAST '+%Y%m%d%H%M.%S' 2>/dev/null || date -d @$PAST '+%Y%m%d%H%M.%S')" "$STATE_FILE"
  INPUT=$(jq -nc --arg sid "$SID" --arg fp "/tmp/whatever.txt" \
    '{session_id: $sid, tool_name: "Write", tool_input: {file_path: $fp, content: "x"}}')
  run bash -c "echo '$INPUT' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ ! -f "$STATE_FILE" ]
}

@test "touchable: Task(developer-agent) fire で state file 生成" {
  PROMPT=$'task §1\n\ntouchable_files:\n  - /tmp/abc.go\n  - /tmp/def.go\n\nverify: go test'
  INPUT=$(jq -nc --arg sid "$SID" --arg p "$PROMPT" \
    '{session_id: $sid, tool_name: "Task", tool_input: {subagent_type: "developer-agent", prompt: $p}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  STATE_FILE="$HOME/.claude/state/touchable-${SID}.txt"
  [ -f "$STATE_FILE" ]
  grep -q '/tmp/abc.go' "$STATE_FILE"
  grep -q '/tmp/def.go' "$STATE_FILE"
}
