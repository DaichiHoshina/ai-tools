#!/usr/bin/env bats
# NG pre-sweep inject log + MCP 分岐配線テスト
# 関連 commit: 2026-06-25 V 改善 (retrospective 2026-06-24 P2)

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HOOK="${REPO_ROOT}/hooks/pre-tool-use.sh"
  export TMP_HOME="$(mktemp -d)"
  export HOME="$TMP_HOME"
  mkdir -p "$HOME/.claude/guidelines/writing" "$HOME/.claude/logs"
  # 本番 NG-DICTIONARY をコピー (PRINCIPLES key sanity check 通過のため fixture 自作不可)
  cp "${REPO_ROOT}/guidelines/writing/NG-DICTIONARY.md" "$HOME/.claude/guidelines/writing/NG-DICTIONARY.md"
  SID="ngsweep-test-$$-${RANDOM}"
  SWEEP_LOG="$HOME/.claude/logs/ng-pre-sweep-inject.log"
}

teardown() {
  rm -rf "$TMP_HOME"
}

@test "ng-pre-sweep: git commit Bash で inject log 記録" {
  INPUT=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "Bash", tool_input: {command: "git commit -m \"feat: add foo\""}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  [ -f "$SWEEP_LOG" ]
  grep -q "pre-tool-use | trigger=Bash" "$SWEEP_LOG"
}

@test "ng-pre-sweep: MCP Notion で inject log 記録 (新規配線)" {
  INPUT=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "mcp__claude_ai_Notion__notion-create-pages", tool_input: {content: "safe text"}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  [ -f "$SWEEP_LOG" ]
  grep -q "pre-tool-use | trigger=mcp__claude_ai_Notion__notion-create-pages" "$SWEEP_LOG"
}

@test "ng-pre-sweep: MCP Slack で inject log 記録 (新規配線)" {
  INPUT=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "mcp__claude_ai_Slack__slack_send_message", tool_input: {text: "safe text"}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  [ -f "$SWEEP_LOG" ]
  grep -q "pre-tool-use | trigger=mcp__claude_ai_Slack__slack_send_message" "$SWEEP_LOG"
}

@test "ng-pre-sweep: 1 session 1 回のみ inject (重複抑制)" {
  INPUT=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "Bash", tool_input: {command: "git commit -m \"first\""}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  # 2 回目発火 → flag file で skip
  INPUT2=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "Bash", tool_input: {command: "git commit -m \"second\""}}')
  echo "$INPUT2" | "$HOOK" >/dev/null 2>&1
  [ "$(wc -l < "$SWEEP_LOG" | tr -d ' ')" = "1" ]
}

@test "ng-pre-sweep: NG-DICTIONARY 不在 → silent skip + log なし" {
  rm -f "$HOME/.claude/guidelines/writing/NG-DICTIONARY.md"
  INPUT=$(jq -nc --arg sid "$SID" \
    '{session_id: $sid, tool_name: "Bash", tool_input: {command: "git commit -m \"test\""}}')
  echo "$INPUT" | "$HOOK" >/dev/null 2>&1
  [ ! -f "$SWEEP_LOG" ]
}
