#!/usr/bin/env bats
# =============================================================================
# worktree-remove.sh のユニットテスト
# 検証項目:
#   1. worktree_path あり → systemMessage に wt path と project root が含まれる
#   2. worktree_path なし → systemMessage に warn が含まれる
#   3. worktree_path あり + ~/.claude/projects 掃除 → 空ディレクトリが削除される
#   4. log ファイルにエントリが記録される
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK="${PROJECT_ROOT}/hooks/worktree-remove.sh"
  setup_test_tmpdir

  # HOME を一時ディレクトリにして本番環境を汚染しない
  export ORIGINAL_HOME="$HOME"
  export HOME="$TEST_TMPDIR"
  mkdir -p "$HOME/.claude/logs"

  # CLAUDE_PROJECT_DIR を設定
  export CLAUDE_PROJECT_DIR="$TEST_TMPDIR/main-repo"
  mkdir -p "$CLAUDE_PROJECT_DIR"
}

teardown() {
  export HOME="$ORIGINAL_HOME"
  teardown_test_tmpdir
}

# =============================================================================
# helper
# =============================================================================

# wt パス形式の worktree_path を持つ stdin JSON を生成
_make_wt_input() {
  local wt_path="${1:-/tmp/wt-test-abc}"
  jq -n --arg p "$wt_path" '{worktree_path: $p}'
}

# =============================================================================
# case 1: worktree_path あり → systemMessage に wt path と project root が含まれる
# =============================================================================
@test "worktree-remove: worktree_path あり → systemMessage に removed wt path が含まれる" {
  local wt_path="/tmp/wt-test-abc"
  local input
  input=$(_make_wt_input "$wt_path")

  run bash -c "echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 0 ]
  # stdout は JSON で systemMessage を含む
  echo "$output" | jq -e '.systemMessage' > /dev/null
  [[ "$output" =~ "wt-test-abc" ]]
}

@test "worktree-remove: worktree_path あり → systemMessage に CLAUDE_PROJECT_DIR が含まれる" {
  local wt_path="/tmp/wt-test-abc"
  local input
  input=$(_make_wt_input "$wt_path")

  run bash -c "echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage' > /dev/null
  # project root が systemMessage に含まれる
  [[ "$output" =~ "main-repo" ]]
}

# =============================================================================
# case 2: worktree_path なし → systemMessage に warn が含まれる
# =============================================================================
@test "worktree-remove: worktree_path なし → systemMessage を出力する" {
  local input='{}'

  run bash -c "echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage' > /dev/null
}

# =============================================================================
# case 3: wt パターン + 空 project dir → rmdir で削除される
# =============================================================================
@test "worktree-remove: 空の project dir は削除される" {
  local wt_path="/tmp/wt-clean-test"
  # 対応する project dir を作成 (空、jsonl なし)
  local sanitized="${wt_path//\//-}"
  local project_dir="$HOME/.claude/projects/${sanitized}"
  mkdir -p "$project_dir"

  local input
  input=$(_make_wt_input "$wt_path")

  run bash -c "echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 0 ]
  # 空 project dir が削除されていること
  [ ! -d "$project_dir" ]
}

# =============================================================================
# case 4: log ファイルへの記録
# =============================================================================
@test "worktree-remove: worktree_path あり → log ファイルにエントリが記録される" {
  local wt_path="/tmp/wt-test-log"
  local input
  input=$(_make_wt_input "$wt_path")

  run bash -c "echo '${input}' | bash '${HOOK}'"
  [ "$status" -eq 0 ]

  local log_file="$HOME/.claude/logs/worktree-cleanup.log"
  [ -f "$log_file" ]
  grep -q "wt-test-log" "$log_file"
}
