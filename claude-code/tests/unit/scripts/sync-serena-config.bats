#!/usr/bin/env bats
# =============================================================================
# BATS Tests for scripts/sync-serena-config.sh
# claude.json の alwaysLoad 削除 / serena_config.yml の excluded_tools union
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT="${PROJECT_ROOT}/scripts/sync-serena-config.sh"
  TEST_DIR=$(mktemp -d)
  export CLAUDE_JSON="${TEST_DIR}/claude.json"
  export SERENA_CONFIG="${TEST_DIR}/serena_config.yml"
}

teardown() {
  rm -rf "$TEST_DIR"
}

_make_claude_json_with_always_load() {
  cat > "$CLAUDE_JSON" <<'EOF'
{
  "someKey": "keep",
  "mcpServers": {
    "serena": {
      "type": "stdio",
      "command": "uv",
      "alwaysLoad": true
    }
  }
}
EOF
}

_make_yml() {
  # $1: excluded_tools 部分の行 (複数行可)
  cat > "$SERENA_CONFIG" <<EOF
tool_timeout: 240

# list of tools to be globally excluded
$1

included_optional_tools: []
EOF
}

@test "claude.json: alwaysLoad が削除され他 key は保持される" {
  _make_yml "excluded_tools: []"
  _make_claude_json_with_always_load
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run jq -e '.mcpServers.serena | has("alwaysLoad")' "$CLAUDE_JSON"
  [ "$output" = "false" ]
  run jq -r '.someKey' "$CLAUDE_JSON"
  [ "$output" = "keep" ]
  run jq -r '.mcpServers.serena.command' "$CLAUDE_JSON"
  [ "$output" = "uv" ]
}

@test "claude.json: alwaysLoad なしなら無変更 (idempotent)" {
  _make_yml "excluded_tools: []"
  _make_claude_json_with_always_load
  "$SCRIPT"
  local before; before=$(cat "$CLAUDE_JSON")
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_JSON")" = "$before" ]
}

@test "claude.json: file 不在でも exit 0" {
  _make_yml "excluded_tools: []"
  rm -f "$CLAUDE_JSON"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "yml: inline 空 [] に管理対象 4 tool が追加される" {
  _make_yml "excluded_tools: []"
  _make_claude_json_with_always_load
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qxF -- "- write_memory" "$SERENA_CONFIG"
  grep -qxF -- "- edit_memory" "$SERENA_CONFIG"
  grep -qxF -- "- delete_memory" "$SERENA_CONFIG"
  grep -qxF -- "- execute_shell_command" "$SERENA_CONFIG"
  # 周辺 key が壊れていない
  grep -qxF "tool_timeout: 240" "$SERENA_CONFIG"
  grep -qxF "included_optional_tools: []" "$SERENA_CONFIG"
}

@test "yml: 既存 entry は保持して不足分だけ union される" {
  _make_yml "excluded_tools:
- custom_tool
- write_memory"
  _make_claude_json_with_always_load
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qxF -- "- custom_tool" "$SERENA_CONFIG"
  # write_memory が重複していない
  [ "$(grep -cxF -- '- write_memory' "$SERENA_CONFIG")" -eq 1 ]
  grep -qxF -- "- execute_shell_command" "$SERENA_CONFIG"
}

@test "yml: 管理対象が揃っていれば無変更 (idempotent)" {
  _make_yml "excluded_tools: []"
  _make_claude_json_with_always_load
  "$SCRIPT"
  local before; before=$(cat "$SERENA_CONFIG")
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$SERENA_CONFIG")" = "$before" ]
}

@test "yml: inline 非空は壊さず warn して skip" {
  _make_yml "excluded_tools: [foo, bar]"
  _make_claude_json_with_always_load
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qxF "excluded_tools: [foo, bar]" "$SERENA_CONFIG"
  [[ "$output" == *"inline 非空"* ]] || [[ "${stderr:-}" == *"inline 非空"* ]] || {
    run bash -c "\"$SCRIPT\" 2>&1"
    [[ "$output" == *"inline 非空"* ]]
  }
}

@test "yml: file 不在でも exit 0" {
  rm -f "$SERENA_CONFIG"
  _make_claude_json_with_always_load
  run "$SCRIPT"
  [ "$status" -eq 0 ]
}
