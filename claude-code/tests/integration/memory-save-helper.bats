#!/usr/bin/env bats
# =============================================================================
# memory-save-helper.sh — deterministic helper for /memory-save command
# =============================================================================
# 背景: AI による MEMORY.md 編集の format ズレ / 日付 typo / dedup 漏れを
# 排除するための shell helper。本 test は subcommand 4 種の契約を固定する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HELPER="${PROJECT_ROOT}/scripts/memory-save-helper.sh"
  export MEMORY_SAVE_DIR="$(mktemp -d)"
}

teardown() {
  [ -d "$MEMORY_SAVE_DIR" ] && rm -rf "$MEMORY_SAVE_DIR"
}

@test "resolve-dir respects MEMORY_SAVE_DIR env" {
  run "$HELPER" resolve-dir
  [ "$status" -eq 0 ]
  [ "$output" = "$MEMORY_SAVE_DIR" ]
}

@test "list-today returns empty when no files" {
  run "$HELPER" list-today
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list-today lists only today's work-context files" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-foo.md"
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-bar.md"
  touch "${MEMORY_SAVE_DIR}/work-context-20200101-old.md"
  touch "${MEMORY_SAVE_DIR}/feedback_unrelated.md"
  run "$HELPER" list-today
  [ "$status" -eq 0 ]
  [[ "$output" == *"work-context-${today}-foo.md"* ]]
  [[ "$output" == *"work-context-${today}-bar.md"* ]]
  [[ "$output" != *"work-context-20200101-old.md"* ]]
  [[ "$output" != *"feedback_unrelated.md"* ]]
}

@test "resolve-name returns base when no collision" {
  run "$HELPER" resolve-name work-context-20990101-fresh
  [ "$status" -eq 0 ]
  [ "$output" = "work-context-20990101-fresh" ]
}

@test "resolve-name adds -2 -3 suffix on collision" {
  touch "${MEMORY_SAVE_DIR}/work-context-20990101-dup.md"
  run "$HELPER" resolve-name work-context-20990101-dup
  [ "$status" -eq 0 ]
  [ "$output" = "work-context-20990101-dup-2" ]
  touch "${MEMORY_SAVE_DIR}/work-context-20990101-dup-2.md"
  run "$HELPER" resolve-name work-context-20990101-dup
  [ "$output" = "work-context-20990101-dup-3" ]
}

@test "update-index creates MEMORY.md when absent" {
  run "$HELPER" update-index work-context-20990101-foo "Foo work" "hook line"
  [ "$status" -eq 0 ]
  [ -f "${MEMORY_SAVE_DIR}/MEMORY.md" ]
  local content; content=$(cat "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$content" == *"[Foo work](work-context-20990101-foo.md)"* ]]
  [[ "$content" == *"— hook line"* ]]
}

@test "update-index prepends new entries (newest on top)" {
  "$HELPER" update-index work-context-20990101-foo "Foo" "first"
  "$HELPER" update-index work-context-20990101-bar "Bar" "second"
  local first_line; first_line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$first_line" == *"[Bar]"* ]]
}

@test "update-index dedups when same file re-registered" {
  "$HELPER" update-index work-context-20990101-foo "Foo v1" "hook1"
  "$HELPER" update-index work-context-20990101-foo "Foo v2" "hook2"
  local count; count=$(grep -c "](work-context-20990101-foo.md)" "${MEMORY_SAVE_DIR}/MEMORY.md")
  [ "$count" -eq 1 ]
  local first_line; first_line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$first_line" == *"Foo v2"* ]]
  [[ "$first_line" == *"hook2"* ]]
}

@test "update-index works without hook arg" {
  run "$HELPER" update-index work-context-20990101-foo "No hook"
  [ "$status" -eq 0 ]
  local line; line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$line" == *"[No hook](work-context-20990101-foo.md)"* ]]
  [[ "$line" != *"—"* ]]
}

@test "unknown subcommand exits non-zero" {
  run "$HELPER" bogus
  [ "$status" -ne 0 ]
}

# =============================================================================
# append-clear-line: /memory-save clear 用、個別 file なしで MEMORY.md に 1 行 prepend
# canonical: commands/memory-save.md § "clear" post-processing (2026-06-30 改訂)
# =============================================================================

@test "append-clear-line: 新規 MEMORY.md に 1 行 entry を書き込む" {
  rm -f "${MEMORY_SAVE_DIR}/MEMORY.md"
  run "$HELPER" append-clear-line "test-topic" "test summary" "abc1234"
  [ "$status" -eq 0 ]
  [ -f "${MEMORY_SAVE_DIR}/MEMORY.md" ]
  local line; line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$line" == *"[clear] test-topic"* ]]
  [[ "$line" == *"test summary"* ]]
  [[ "$line" == *"(commit: abc1234)"* ]]
}

@test "append-clear-line: commit hash 省略時は (commit: …) を付けない" {
  rm -f "${MEMORY_SAVE_DIR}/MEMORY.md"
  run "$HELPER" append-clear-line "no-commit-topic" "no commit summary" ""
  [ "$status" -eq 0 ]
  local line; line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$line" == *"[clear] no-commit-topic"* ]]
  [[ "$line" == *"no commit summary"* ]]
  [[ "$line" != *"(commit:"* ]]
}

@test "append-clear-line: 既存 MEMORY.md の先頭に prepend する" {
  printf '%s\n' "- old entry 1" "- old entry 2" > "${MEMORY_SAVE_DIR}/MEMORY.md"
  run "$HELPER" append-clear-line "new-topic" "new summary" "def5678"
  [ "$status" -eq 0 ]
  local first_line; first_line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$first_line" == *"[clear] new-topic"* ]]
  local total_lines; total_lines=$(wc -l < "${MEMORY_SAVE_DIR}/MEMORY.md")
  [ "$total_lines" -eq 3 ]
  # 旧 entry が残存していること
  grep -q "old entry 1" "${MEMORY_SAVE_DIR}/MEMORY.md"
  grep -q "old entry 2" "${MEMORY_SAVE_DIR}/MEMORY.md"
}

@test "append-clear-line: 同日複数 clear save は dedup せず重複保存する" {
  rm -f "${MEMORY_SAVE_DIR}/MEMORY.md"
  "$HELPER" append-clear-line "same-topic" "first save" "aaa1111"
  "$HELPER" append-clear-line "same-topic" "second save" "bbb2222"
  local count; count=$(grep -c "same-topic" "${MEMORY_SAVE_DIR}/MEMORY.md")
  [ "$count" -eq 2 ]
  # 新しい (second) が先頭、古い (first) が後
  local first_line; first_line=$(head -1 "${MEMORY_SAVE_DIR}/MEMORY.md")
  [[ "$first_line" == *"second save"* ]]
}

@test "extract-issue-key: PROJ-123 形式を抽出する" {
  run "$HELPER" extract-issue-key "feature/PROJ-123-add-login"
  [ "$status" -eq 0 ]
  [ "$output" = "PROJ-123" ]
}

@test "extract-issue-key: #123 形式は数字だけ抽出する" {
  run "$HELPER" extract-issue-key "fix/#456-null-guard"
  [ "$status" -eq 0 ]
  [ "$output" = "456" ]
}

@test "extract-issue-key: issue-789 形式は issue-<n> を返す" {
  run "$HELPER" extract-issue-key "issue-789-refactor"
  [ "$status" -eq 0 ]
  [ "$output" = "issue-789" ]
}

@test "extract-issue-key: issue/123 形式 (スラッシュ区切り) は issue-<n> を返す" {
  run "$HELPER" extract-issue-key "issue/123-foo"
  [ "$status" -eq 0 ]
  [ "$output" = "issue-123" ]
}

@test "extract-issue-key: issue_456 形式 (アンダースコア区切り) は issue-<n> を返す" {
  run "$HELPER" extract-issue-key "issue_456-bar"
  [ "$status" -eq 0 ]
  [ "$output" = "issue-456" ]
}

@test "extract-issue-key: key 無い branch は空を返す" {
  run "$HELPER" extract-issue-key "feature/add-login"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "extract-issue-key: 空 branch も空を返す (exit 0)" {
  run "$HELPER" extract-issue-key ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "find-topic-match: 同日 exact suffix match で hit する" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-reload-fix.md"
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-other-topic.md"
  run "$HELPER" find-topic-match "reload-fix"
  [ "$status" -eq 0 ]
  [[ "$output" == *"work-context-${today}-reload-fix.md"* ]]
  [[ "$output" != *"other-topic"* ]]
}

@test "find-topic-match: issue key prefix があっても topic 部分で hit する" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-PROJ-123-reload-fix.md"
  run "$HELPER" find-topic-match "reload-fix"
  [ "$status" -eq 0 ]
  [[ "$output" == *"work-context-${today}-PROJ-123-reload-fix.md"* ]]
}

@test "find-topic-match: match 無しで exit 0 + 空出力" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-foo.md"
  run "$HELPER" find-topic-match "bar"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "find-topic-match: 部分 match (substring) では hit しない" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-login-flow.md"
  run "$HELPER" find-topic-match "login"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "append-clear-line: 個別 file (work-context-*.md) は作らない" {
  rm -f "${MEMORY_SAVE_DIR}/MEMORY.md"
  rm -f "${MEMORY_SAVE_DIR}"/work-context-*.md
  "$HELPER" append-clear-line "no-file-topic" "summary" ""
  local file_count; file_count=$(find "${MEMORY_SAVE_DIR}" -maxdepth 1 -name 'work-context-*.md' 2>/dev/null | wc -l | tr -d ' ')
  [ "$file_count" -eq 0 ]
}
