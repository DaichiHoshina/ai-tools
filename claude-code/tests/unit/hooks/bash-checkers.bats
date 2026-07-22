#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/bash-checkers.sh — _handle_bash_tool
# pre-tool-use.sh の "Bash") case 分岐から切り出した関数の挙動確認
# =============================================================================

setup() {
  load "../../helpers/common"
  load "../../helpers/hook-invoke"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir
  # hint 系の session dedup を test 単位で隔離 (bash-checkers.sh の flag file)
  export CLAUDE_CODE_SESSION_ID="bc-$$-${BATS_TEST_NUMBER}"
  rm -f "/tmp/claude-serena-hint-${CLAUDE_CODE_SESSION_ID}-"* \
        "/tmp/claude-cat-read-hint-${CLAUDE_CODE_SESSION_ID}-"* 2>/dev/null || true
}

teardown() {
  teardown_test_tmpdir
}

_run_bash_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{command: $c}')
  invoke_hook "Bash" "$input"
}

@test "bash-checkers: go build ./... 全体実行は Forbidden (exit 2)" {
  run bash -c 'echo "$1" | bash "$2" 2>/dev/null' _ \
    "$(jq -n --arg c 'go build ./...' '{tool_name: "Bash", tool_input: {command: $c}}')" \
    "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "bash-checkers: go build ./pkg/foo/... はブロックされない" {
  result=$(_run_bash_hook "go build ./pkg/foo/...")
  msg=$(get_system_message "$result")
  [[ "$msg" != *"go build/test"* ]]
}

@test "bash-checkers: cat で .md を読むと Read ツール推奨 hint が additionalContext に入る" {
  result=$(_run_bash_hook "cat README.md")
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "Read ツールを使うこと" ]]
}

@test "bash-checkers: 通常の ls コマンドは additionalContext / systemMessage 無し" {
  result=$(_run_bash_hook "ls -la")
  [ "$result" = "{}" ]
}

# =============================================================================
# migration 混在 warn (git commit): bash-checkers.sh:153-180
# staged に migration file と非 migration file が混在する commit を warn する。
# 対象 repo 判定は CLAUDE_TARGET_PROJECT_REPO_PATTERN (glob) と cwd の toplevel 一致。
# =============================================================================

# 対象 repo を作り、その toplevel を CLAUDE_TARGET_PROJECT_REPO_PATTERN に設定する。
# git rev-parse --show-toplevel は symlink 解決済み絶対パスを返す (macOS /tmp -> /private/tmp)。
# hook 側も同じ関数で正規化するため、ここで得た値をそのまま pattern に使えば一致する。
_setup_migration_repo() {
  MIG_REPO="${TEST_TMPDIR}/migration-repo"
  mkdir -p "$MIG_REPO"
  git -C "$MIG_REPO" init -q
  git -C "$MIG_REPO" -c user.name=test -c user.email=test@test commit -q --allow-empty -m init
  CLAUDE_TARGET_PROJECT_REPO_PATTERN=$(git -C "$MIG_REPO" rev-parse --show-toplevel)
  export CLAUDE_TARGET_PROJECT_REPO_PATTERN
}

_invoke_commit_hook_mig() {
  local cmd="$1"
  local input
  input=$(jq -n --arg name "Bash" --arg cmd "$cmd" --arg cwd "$MIG_REPO" \
    '{tool_name: $name, tool_input: {command: $cmd}, cwd: $cwd}')
  echo "$input" | bash "$HOOK_FILE"
}

@test "bash-checkers: migration file と非 migration file が混在 → warn injects" {
  _setup_migration_repo
  mkdir -p "${MIG_REPO}/migrations"
  echo "CREATE TABLE users();" > "${MIG_REPO}/migrations/0001_init.sql"
  echo "package main" > "${MIG_REPO}/main.go"
  git -C "$MIG_REPO" add migrations/0001_init.sql main.go

  result=$(_invoke_commit_hook_mig "git commit -m 'add users table'")
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "migration 混在 warn" ]]
}

@test "bash-checkers: .up.sql 拡張子 (migrations dir 外) でも混在検知する" {
  _setup_migration_repo
  echo "ALTER TABLE users ADD COLUMN age int;" > "${MIG_REPO}/0002_add_age.up.sql"
  echo "docs update" > "${MIG_REPO}/README.md"
  git -C "$MIG_REPO" add 0002_add_age.up.sql README.md

  result=$(_invoke_commit_hook_mig "git commit -m 'add age column'")
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "migration 混在 warn" ]]
}

@test "bash-checkers: migration file のみ (非 migration 混在なし) → warn 無し" {
  _setup_migration_repo
  mkdir -p "${MIG_REPO}/migrations"
  echo "CREATE TABLE users();" > "${MIG_REPO}/migrations/0001_init.sql"
  git -C "$MIG_REPO" add migrations/0001_init.sql

  result=$(_invoke_commit_hook_mig "git commit -m 'add migration'")
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "migration 混在 warn" ]]
}

@test "bash-checkers: 非 migration file のみ → warn 無し" {
  _setup_migration_repo
  echo "package main" > "${MIG_REPO}/main.go"
  git -C "$MIG_REPO" add main.go

  result=$(_invoke_commit_hook_mig "git commit -m 'update main'")
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "migration 混在 warn" ]]
}

@test "bash-checkers: 拡張子大文字 (.SQL) は migration 判定されない (case-sensitive)" {
  _setup_migration_repo
  echo "CREATE TABLE x();" > "${MIG_REPO}/0001_init.SQL"
  echo "package main" > "${MIG_REPO}/main.go"
  git -C "$MIG_REPO" add 0001_init.SQL main.go

  result=$(_invoke_commit_hook_mig "git commit -m 'add table'")
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "migration 混在 warn" ]]
}

@test "bash-checkers: CLAUDE_TARGET_PROJECT_REPO_PATTERN 未設定 → 混在があっても warn 無し (対象外 repo)" {
  MIG_REPO="${TEST_TMPDIR}/other-repo"
  mkdir -p "${MIG_REPO}/migrations"
  git -C "$MIG_REPO" init -q
  git -C "$MIG_REPO" -c user.name=test -c user.email=test@test commit -q --allow-empty -m init
  echo "CREATE TABLE x();" > "${MIG_REPO}/migrations/0001_init.sql"
  echo "package main" > "${MIG_REPO}/main.go"
  git -C "$MIG_REPO" add migrations/0001_init.sql main.go

  result=$(_invoke_commit_hook_mig "git commit -m 'add table'")
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "migration 混在 warn" ]]
}
