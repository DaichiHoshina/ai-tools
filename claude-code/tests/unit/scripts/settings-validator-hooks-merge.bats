#!/usr/bin/env bats
# =============================================================================
# Regression: sync_settings_hooks の matcher 単位 dedup 動作確認
#
#   `[[sync-hooks-merge-duplicate-bug]]` (2026-06-20 Stop hook 3 重複事故) の
#   再発防止 net。template と live を mock 配置し、merge 後の Stop entry が
#   matcher 単位で 1 件に正規化されることを確認する。
# =============================================================================

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/settings-validator.sh"

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  export CLAUDE_DIR="${TEST_TMPDIR}/.claude"
  export SCRIPT_DIR="${TEST_TMPDIR}/repo"

  mkdir -p "$CLAUDE_DIR" "$SCRIPT_DIR/templates"
  export TEMPLATE_FILE="${SCRIPT_DIR}/templates/settings.json.template"
  export LIVE_FILE="${CLAUDE_DIR}/settings.json"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# 共通: 関数の source helper (stub 関数も含めて bash -c に流す)
run_sync_hooks() {
  bash -c "
    check_jq()      { return 0; }
    print_warning() { :; }
    print_error()   { :; }
    print_info()    { :; }
    print_success() { :; }
    export -f check_jq print_warning print_error print_info print_success

    export SCRIPT_DIR='${SCRIPT_DIR}'
    export CLAUDE_DIR='${CLAUDE_DIR}'

    unset _SETTINGS_VALIDATOR_LOADED
    # shellcheck disable=SC1090
    source '${SCRIPT_FILE}'
    sync_settings_hooks
  "
}

@test "matcher='*' が template/live 両方に存在しても merge 後 1 件に dedup される" {
  cat > "$TEMPLATE_FILE" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "~/.claude/hooks/stop.sh"}
        ]
      }
    ]
  }
}
EOF
  # live: 古い (誤った) Stop block を含む状態を再現
  cat > "$LIVE_FILE" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/stop.sh"}
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "/old/stale/stop.sh"}
        ]
      }
    ]
  }
}
EOF

  run_sync_hooks
  [ "$?" -eq 0 ]

  # 結果: matcher='*' は 1 件のみ、command は template の値で上書き
  local n
  n=$(jq '[.hooks.Stop[] | select(.matcher == "*")] | length' "$LIVE_FILE")
  [ "$n" -eq 1 ]

  local cmd
  cmd=$(jq -r '.hooks.Stop[] | select(.matcher == "*") | .hooks[0].command' "$LIVE_FILE")
  [ "$cmd" = "~/.claude/hooks/stop.sh" ]
}

@test "live 独自 matcher (template 未定義) は merge 後も保持される" {
  cat > "$TEMPLATE_FILE" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/stop.sh"}]
      }
    ]
  }
}
EOF
  cat > "$LIVE_FILE" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/custom-bash.sh"}]
      }
    ]
  }
}
EOF

  run_sync_hooks
  [ "$?" -eq 0 ]

  # template の '*' + live 独自 'Bash' で 2 件
  local n
  n=$(jq '.hooks.Stop | length' "$LIVE_FILE")
  [ "$n" -eq 2 ]

  jq -e '.hooks.Stop[] | select(.matcher == "Bash")' "$LIVE_FILE" >/dev/null
  jq -e '.hooks.Stop[] | select(.matcher == "*")'    "$LIVE_FILE" >/dev/null
}

@test "matcher なし hook: template と command が異なる live 独自 hook は merge 後も残る" {
  cat > "$TEMPLATE_FILE" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      }
    ]
  }
}
EOF
  cat > "$LIVE_FILE" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      },
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/custom-user-hook.sh"}]
      }
    ]
  }
}
EOF

  run_sync_hooks
  [ "$?" -eq 0 ]

  # template の matcher なし entry + live 独自の matcher なし entry で 2 件
  local n
  n=$(jq '.hooks.SessionStart | length' "$LIVE_FILE")
  [ "$n" -eq 2 ]

  jq -e '.hooks.SessionStart[] | select(.hooks[0].command == "~/.claude/hooks/custom-user-hook.sh")' "$LIVE_FILE" >/dev/null
}

@test "matcher なし hook: template と完全同一 entry の重複は従来どおり排除される" {
  cat > "$TEMPLATE_FILE" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      }
    ]
  }
}
EOF
  # live に template と完全同一 (matcher なし + 同一 command) の entry が重複している状態
  cat > "$LIVE_FILE" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      },
      {
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      }
    ]
  }
}
EOF

  run_sync_hooks
  [ "$?" -eq 0 ]

  # template 側 1 件のみ残り、live 側の重複は dedup される
  local n
  n=$(jq '.hooks.SessionStart | length' "$LIVE_FILE")
  [ "$n" -eq 1 ]
}

@test "live に hooks section がなくても template から initial populate される" {
  cat > "$TEMPLATE_FILE" <<'EOF'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/stop.sh"}]
      }
    ]
  }
}
EOF
  echo '{}' > "$LIVE_FILE"

  run_sync_hooks
  [ "$?" -eq 0 ]

  local n
  n=$(jq '.hooks.Stop | length' "$LIVE_FILE")
  [ "$n" -eq 1 ]
}
