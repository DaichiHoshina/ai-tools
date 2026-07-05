#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — memory path block / exclusion
# _check_legacy_auto_memory_path + memory-exclusion (NG-DICTIONARY skip)
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

# =============================================================================
# _check_legacy_auto_memory_path: ~/.claude/projects/*/ai-tools*/memory/ block テスト
# CLAUDE.md § Memory write target: ai-tools repo の memory write 先は ~/ai-tools/memory/ 固定
# =============================================================================

_run_legacy_memory_write() {
  local file_path="$1"
  local tool_name="${2:-Write}"
  local input
  input=$(jq -n --arg fp "$file_path" \
    '{file_path: $fp, content: "test content"}')
  invoke_hook_run_merged "$tool_name" "$input"
}

@test "legacy-memory-block: ~/.claude/projects/*ai-tools*/memory/ への Write は exit 2 で block される" {
  local legacy_path
  legacy_path="${HOME}/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/foo.md"
  _run_legacy_memory_write "$legacy_path"
  [[ "$status" -eq 2 ]]
}

@test "legacy-memory-block: 正規 path ~/ai-tools/memory/foo.md への Write は通過する" {
  local valid_path
  valid_path="${HOME}/ai-tools/memory/foo.md"
  _run_legacy_memory_write "$valid_path"
  # block されない (exit 2 にならない)
  [[ "$status" -ne 2 ]]
}

@test "legacy-memory-block: block 発火時に legacy-memory-path-block.log に追記される" {
  local log_file="${HOME}/.claude/logs/legacy-memory-path-block.log"
  local before_lines=0
  [[ -f "$log_file" ]] && before_lines=$(wc -l < "$log_file")

  local legacy_path
  legacy_path="${HOME}/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/bar.md"
  _run_legacy_memory_write "$legacy_path"
  # exit 2 (block) を期待するが、log 書き込みを確認するために status は問わない

  [[ -f "$log_file" ]]
  local after_lines
  after_lines=$(wc -l < "$log_file")
  [[ "$after_lines" -gt "$before_lines" ]]
}

# =============================================================================
# memory-exclusion: memory file への write 時に NG-DICTIONARY block を skip
# canonical: lib/hook-utils.sh _is_memory_path + pre-tool-use.sh line 1340 / 1373
# user 指示 2026-06-30: memory save 時に NG word 検出を skip
# =============================================================================

_run_memory_ng_write() {
  local input
  input=$(jq -n --arg fp "$1" --arg ct "$2" '{file_path: $fp, content: $ct}')
  invoke_hook_run_merged "Write" "$input"
}

@test "memory-exclusion: ~/ai-tools/memory/ に NG-DICTIONARY 語を含む write は block されない" {
  local memory_path="${HOME}/ai-tools/memory/test-ng-exclusion.md"
  local ng_content="# test\n\n効果的にシームレスに包括的な処理を実現します。\n"
  _run_memory_ng_write "$memory_path" "$ng_content"
  [[ "$status" -ne 2 ]]
}

@test "memory-exclusion: 通常 path に同じ NG-DICTIONARY 語を含む write は block される (control)" {
  local normal_path="${HOME}/ghq/github.com/some-other-repo-not-aitools/notes-ng-test.md"
  local ng_content="# test\n\n効果的にシームレスに包括的な処理を実現します。\n"
  _run_memory_ng_write "$normal_path" "$ng_content"
  [[ "$status" -eq 2 ]]
}

@test "memory-exclusion: ~/.claude/projects/*/memory/ への NG 語 write は block されない (legacy-memory-block 適用前提)" {
  # legacy-memory-block が先に発火するため、NG-DICTIONARY block の到達前に止まる
  # ただし memory-exclusion logic 自体は _is_auto_memory_path で先行除外する
  local legacy_memory="${HOME}/.claude/projects/-Users-foo-bar/memory/test.md"
  local ng_content="# test\n\n効果的にシームレスな処理。\n"
  _run_memory_ng_write "$legacy_memory" "$ng_content"
  # legacy-memory-block (~/.claude/projects/*ai-tools*/memory/) は ai-tools 系のみ block
  # foo-bar は ai-tools 系でないので legacy-block 発火せず、_is_auto_memory_path で NG-DICT skip → exit 0
  [[ "$status" -ne 2 ]]
}
