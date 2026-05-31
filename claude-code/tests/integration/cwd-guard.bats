#!/usr/bin/env bats
# =============================================================================
# cwd-guard: worktree session での main repo 直接 Edit ブロック検証
# 3 cases:
#   1. worktree session + worktree 内 path → pass (exit 0)
#   2. worktree session + worktree 外 path → block (exit 2)
#   3. worktree 外 session (main)         → pass  (exit 0)
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOK="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  export ORIG_PATH="$PATH"

  # テスト用 HOME（本番ログ汚染防止）
  export ORIGINAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude/logs"

  # 疑似 worktree ディレクトリを /tmp に作成
  export FAKE_WORKTREE="$(mktemp -d)/repo/.claude/worktrees/wt-test-abc"
  mkdir -p "$FAKE_WORKTREE"

  # 疑似 main repo ディレクトリ
  export FAKE_MAIN="$(mktemp -d)/main-repo"
  mkdir -p "$FAKE_MAIN"
}

teardown() {
  export PATH="$ORIG_PATH"
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# ------------------------------------------------------------------
# case 1: worktree session + worktree 内 path → pass
# ------------------------------------------------------------------
@test "cwd-guard: worktree session で worktree 内 path は pass する" {
  local file_path="${FAKE_WORKTREE}/src/foo.ts"
  local input
  input=$(jq -n \
    --arg tool "Edit" \
    --arg fp "$file_path" \
    '{tool_name: $tool, tool_input: {file_path: $fp, old_string: "a", new_string: "b"}}')

  run bash -c "export CLAUDE_PROJECT_DIR='${FAKE_WORKTREE}'; echo '${input}' | bash '${HOOK}'"
  # exit 2 (Forbidden) ではないこと
  [[ "$status" -ne 2 ]]
}

# ------------------------------------------------------------------
# case 2: worktree session + worktree 外 (main repo) path → block (exit 2)
# ------------------------------------------------------------------
@test "cwd-guard: worktree session で main repo path は exit 2 でブロックする" {
  local file_path="${FAKE_MAIN}/claude-code/templates/settings.json.template"
  mkdir -p "$(dirname "$file_path")"
  local input
  input=$(jq -n \
    --arg tool "Edit" \
    --arg fp "$file_path" \
    '{tool_name: $tool, tool_input: {file_path: $fp, old_string: "a", new_string: "b"}}')

  run bash -c "export CLAUDE_PROJECT_DIR='${FAKE_WORKTREE}'; echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "cwd-guard" ]]
}

# ------------------------------------------------------------------
# case 3: worktree 外 session (main repo CWD) → pass
# ------------------------------------------------------------------
@test "cwd-guard: worktree 外 session では guard が発動しない" {
  # main repo 内の path を指定
  local file_path="${FAKE_MAIN}/claude-code/templates/settings.json.template"
  mkdir -p "$(dirname "$file_path")"
  local input
  input=$(jq -n \
    --arg tool "Edit" \
    --arg fp "$file_path" \
    '{tool_name: $tool, tool_input: {file_path: $fp, old_string: "a", new_string: "b"}}')

  # CLAUDE_PROJECT_DIR は worktrees 以外 → guard 不発動
  run bash -c "export CLAUDE_PROJECT_DIR='${FAKE_MAIN}'; echo '${input}' | bash '${HOOK}'"
  [[ "$status" -ne 2 ]]
}
