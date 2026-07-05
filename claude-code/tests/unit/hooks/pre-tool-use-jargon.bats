#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — AI 定型語 / NG-DICTIONARY block
# 難読漢語 / 非日常英語 / 中間漢語 / ng-dict-inject / gap1-3 (Write/gh/Notion/Slack)
# 分割元: tests/unit/hooks/pre-tool-use.bats
# =============================================================================

setup() {
  load "../../helpers/common"
  load "../../helpers/hook-invoke"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir
}

teardown() {
  teardown_test_tmpdir
}

_DEFAULT_INPUT="{}"

run_hook() {
  invoke_hook "$1" "${2:-$_DEFAULT_INPUT}"
}

# session_id 付き run_hook ヘルパー (ng-dict-inject 用)
# CLAUDE_CODE_SESSION_ID を unset して stdin の session_id を優先させる
_run_hook_with_session() {
  local tool_name="$1"
  local tool_input="${2:-$_DEFAULT_INPUT}"
  local session_id="${3:-test-session-$$}"
  local input
  input=$(jq -n \
    --arg name "$tool_name" \
    --argjson inp "$tool_input" \
    --arg sid "$session_id" \
    '{tool_name: $name, tool_input: $inp, session_id: $sid}')
  # session_id を stdin から優先させるため env の CLAUDE_CODE_SESSION_ID を落とす
  # (共有 helper の invoke_hook_stdin は env 制御しないので直接展開)
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

# =============================================================================
# 難読漢語 block テスト
# =============================================================================

_run_bash_jargon() {
  local input
  input=$(jq -n --arg c "$1" '{command:$c}')
  invoke_hook_run "Bash" "$input"
}

@test "pre-tool-use: 難読漢語 commit message は block (exit 2)" {
  _run_bash_jargon 'git commit -m "鑑みると修正する"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
  [[ "$output" =~ "鑑みる" ]]
}

@test "pre-tool-use: 難読漢語 喫緊 commit message は block" {
  _run_bash_jargon 'git commit -m "喫緊の課題を修正"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "pre-tool-use: 難読漢語 踏襲 commit message は block" {
  _run_bash_jargon 'git commit -m "既存方針を踏襲する"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

# =============================================================================
# 非日常英語 block テスト
# =============================================================================

@test "pre-tool-use: 非日常英語 leverage commit message は block (exit 2)" {
  _run_bash_jargon 'git commit -m "leverage existing infra"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
  [[ "$output" =~ "leverage" ]]
}

@test "pre-tool-use: 非日常英語 utilize commit message は block" {
  _run_bash_jargon 'git commit -m "utilize the cache layer"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
}

@test "pre-tool-use: 非日常英語 mitigate commit message は block" {
  _run_bash_jargon 'git commit -m "mitigate performance degradation"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
}

# =============================================================================
# 中間漢語 regression テスト (block されないこと)
# =============================================================================

@test "pre-tool-use: 中間漢語 網羅 commit message は block されない" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"網羅的に整合性を担保\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "難読漢語" ]]
  [[ ! "$msg" =~ "非日常英語" ]]
}

@test "pre-tool-use: 中間漢語 整合 担保 是正 commit message は block されない" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"整合性担保と是正\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "難読漢語" ]]
}

# =============================================================================
# PRINCIPLES.md required_keys coverage テスト
# hook の _assert_required_keys が exact-match 参照する 5 key が
# PRINCIPLES.md に **<key>**: 形式で存在することを検証する。
# key を改名すると hook が silent pass するため、この test で早期検出する。
# =============================================================================

@test "principles-keys: PRINCIPLES.md に hook required_keys が全件存在する" {
  local principles_file="${PROJECT_ROOT}/guidelines/writing/NG-DICTIONARY.md"
  [[ -f "$principles_file" ]] || skip "NG-DICTIONARY.md not found at $principles_file"

  # pre-tool-use.sh:98 の required_keys と同一 (test fixture 例外 — 整合検証が目的)
  local required_keys=(
    "AI定型語"
    "カタカナ造語禁止"
    "断定語 (warn-only)"
    "難読漢語 (block)"
    "非日常英語 (block)"
  )

  local key
  for key in "${required_keys[@]}"; do
    run grep -qF "**${key}**:" "$principles_file"
    [[ "$status" -eq 0 ]] || {
      echo "FAIL: key '${key}' not found in PRINCIPLES.md" >&2
      return 1
    }
  done
}

# =============================================================================
# _inject_ng_dict_on_commit_compose テスト
# =============================================================================

@test "ng-dict-inject: git commit -m で block_terms が additionalContext に inject される" {
  local sid="ng-inject-test-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" \
    '{"command":"git commit -m \"feat: add new feature\""}' "$sid")

  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local ctx
  ctx=$(get_additional_context "$result")
  # block_terms が含まれること
  [[ "$ctx" =~ "block_terms" ]]
  # 難読漢語の代表例 (鑑みる) が含まれること
  [[ "$ctx" =~ "鑑みる" ]]
  # 非日常英語の代表例 (leverage) が含まれること
  [[ "$ctx" =~ "leverage" ]]
}

@test "ng-dict-inject: 同一 session_id で 2 回目は重複 inject なし" {
  local sid="ng-inject-dedup-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local result1
  result1=$(_run_hook_with_session "Bash" \
    '{"command":"git commit -m \"feat: first commit\""}' "$sid")
  local result2
  result2=$(_run_hook_with_session "Bash" \
    '{"command":"git commit -m \"feat: second commit\""}' "$sid")

  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  # 1 回目: inject あり
  [[ "$(get_additional_context "$result1")" =~ "block_terms" ]]
  # 2 回目: inject なし (session 重複抑制)
  [[ ! "$(get_additional_context "$result2")" =~ "block_terms" ]]
}

@test "ng-dict-inject: ls コマンドでは inject されない" {
  local sid="ng-inject-skip-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" \
    '{"command":"ls -la /tmp"}' "$sid")

  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local ctx
  ctx=$(get_additional_context "$result")
  # 無関係コマンドでは block_terms が含まれないこと
  [[ ! "$ctx" =~ "block_terms" ]]
}

@test "ng-dict-inject: gh pr create でも block_terms が inject される" {
  local sid="ng-inject-gh-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" \
    '{"command":"gh pr create --title \"feat: test\" --body \"description here\""}' "$sid")

  rm -f "/tmp/claude-ng-inject-${sid}-${today}" 2>/dev/null || true

  local ctx
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "block_terms" ]]
}

# =============================================================================
# gap 1: Write/Edit .md/.txt への AI定型語 block テスト (2026-06-14)
# =============================================================================

_run_write_jargon() {
  local input
  input=$(jq -n --arg p "$1" --arg c "$2" '{file_path:$p, content:$c}')
  invoke_hook_run "Write" "$input"
}

@test "gap1: 作業 repo .md に NG 語 leverage を Write → exit 2 block" {
  _run_write_jargon "/tmp/test-outside-repo/README.md" "leverage existing infra を使う"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap1: 作業 repo .md に NG 語 踏襲 を Write → exit 2 block" {
  _run_write_jargon "/tmp/test-outside-repo/doc.md" "既存方針を踏襲する"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "gap1: 作業 repo .txt に NG 語 leverage を Write → exit 2 block" {
  _run_write_jargon "/tmp/test-outside-repo/note.txt" "leverage the cache"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap1: ai-tools 配下 .md に NG 語を Write → block されない (誤爆防止)" {
  local aitools_path="${HOME}/ghq/github.com/DaichiHoshina/ai-tools/claude-code/guidelines/writing/test-ng.md"
  _run_write_jargon "$aitools_path" "leverage existing infra"
  # ai-tools 配下なので exit 2 にならない
  [ "$status" -ne 2 ]
}

@test "gap1: ai-tools symlink 配下 .md に NG 語を Write → block されない" {
  local aitools_path="${HOME}/ai-tools/claude-code/some-file.md"
  _run_write_jargon "$aitools_path" "踏襲する方針"
  [ "$status" -ne 2 ]
}

@test "gap1: 非 md ファイル (.sh) への Write は AI定型語 block されない" {
  _run_write_jargon "/tmp/test.sh" "leverage existing infra"
  # .sh は対象外
  [ "$status" -ne 2 ]
}

# =============================================================================
# gap 2: git commit -F / --amend / gh --body-file テスト (2026-06-14)
# =============================================================================

@test "gap2: git commit -F <tmpfile> で NG 語 leverage → exit 2 block" {
  local tmpfile
  tmpfile=$(mktemp)
  printf 'leverage existing infra を使う\n' > "$tmpfile"
  local input
  input=$(jq -n --arg c "git commit -F ${tmpfile}" '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  rm -f "$tmpfile"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap2: git commit --file <tmpfile> で NG 語 踏襲 → exit 2 block" {
  local tmpfile
  tmpfile=$(mktemp)
  printf '既存方針を踏襲する\n' > "$tmpfile"
  local input
  input=$(jq -n --arg c "git commit --file ${tmpfile}" '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  rm -f "$tmpfile"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "gap2: git commit -F 不存在ファイル → silent skip (block されない)" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"git commit -F /nonexistent/path/msg.txt"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  # ファイル不在なら block しない
  [ "$status" -ne 2 ]
}

@test "gap2: git commit --amend (-m/-F なし) → warn-only が additionalContext に入る" {
  local result
  result=$(run_hook "Bash" '{"command": "git commit --amend --no-edit"}')
  local ctx
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "--amend" ]] || [[ "$ctx" =~ "hook は本文を検査できません" ]]
}

@test "gap2: git commit --amend --message= で NG 語 踏襲 → exit 2 block (-m substring 誤マッチ regression)" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"git commit --amend --message='"'"'既存方針を踏襲する'"'"'"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "gap2: git commit --amend --message space 形式で NG 語 踏襲 → exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"git commit --amend --message '"'"'既存方針を踏襲する'"'"'"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "gap2: git commit --amend --message= が NG 語なし → block されず warn も出ない" {
  local result
  result=$(run_hook "Bash" '{"command": "git commit --amend --message='"'"'直近の修正'"'"'"}')
  local ctx
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "hook は本文を検査できません" ]]
}

@test "gap2: gh pr create --body-file <tmpfile> で NG 語 leverage → exit 2 block" {
  local tmpfile
  tmpfile=$(mktemp)
  printf 'leverage existing infra の説明\n' > "$tmpfile"
  local input
  input=$(jq -n --arg c "gh pr create --title 'feat: test' --body-file ${tmpfile}" \
    '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  rm -f "$tmpfile"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap2: gh issue create --body-file 不存在ファイル → silent skip" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"gh issue create --title test --body-file /nonexistent/body.md"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}

# =============================================================================
# gap 3: Notion children / Slack blocks nested field block テスト (2026-06-14)
# =============================================================================

@test "gap3: Notion children paragraph に NG 語 leverage → exit 2 block" {
  local input
  input=$(jq -n '{
    tool_name: "mcp__claude_ai_Notion__notion-create-pages",
    tool_input: {
      children: [
        {
          paragraph: {
            rich_text: [
              { text: { content: "leverage existing infra の詳細" } }
            ]
          }
        }
      ]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap3: Notion children heading_2 に NG 語 踏襲 → exit 2 block" {
  local input
  input=$(jq -n '{
    tool_name: "mcp__claude_ai_Notion__notion-update-page",
    tool_input: {
      children: [
        {
          heading_2: {
            rich_text: [
              { text: { content: "既存方針を踏襲する" } }
            ]
          }
        }
      ]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "gap3: Notion children bulleted_list_item に NG 語 → exit 2 block" {
  local input
  input=$(jq -n '{
    tool_name: "mcp__claude_ai_Notion__notion-create-pages",
    tool_input: {
      children: [
        {
          bulleted_list_item: {
            rich_text: [
              { text: { content: "利用可能なリソースを最大限に活用し utilize する" } }
            ]
          }
        }
      ]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
}

@test "gap3: Slack blocks[].text.text に NG 語 leverage → exit 2 block" {
  local input
  input=$(jq -n '{
    tool_name: "mcp__claude_ai_Slack__slack_send_message",
    tool_input: {
      blocks: [
        {
          type: "section",
          text: { type: "mrkdwn", text: "leverage existing infra を使います" }
        }
      ]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]] || [[ "$output" =~ "leverage" ]]
}

@test "gap3: Notion children に NG 語なし → block されない" {
  local input
  input=$(jq -n '{
    tool_name: "mcp__claude_ai_Notion__notion-create-pages",
    tool_input: {
      children: [
        {
          paragraph: {
            rich_text: [
              { text: { content: "正常なコンテンツです" } }
            ]
          }
        }
      ]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}
