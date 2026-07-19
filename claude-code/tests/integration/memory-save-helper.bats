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

@test "resolve-dir returns ai-tools SoT when MEMORY_SAVE_DIR unset (from non-ai-tools cwd)" {
  # 3 tool 共有 SoT 固定: cwd がどの repo でも ~/ai-tools/memory を返す (CLAUDE.md L188)
  local fake_repo; fake_repo=$(mktemp -d)
  ( cd "$fake_repo" && git init -q )
  # <repo-parent>/memory/ を作っても影響しない (旧 fallback 廃止確認)
  mkdir -p "${fake_repo%/*}/memory"
  run env -u MEMORY_SAVE_DIR bash -c "cd '$fake_repo' && '$HELPER' resolve-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${HOME}/ai-tools/memory" ]
  rm -rf "$fake_repo" "${fake_repo%/*}/memory"
}

@test "resolve-dir returns ai-tools SoT when outside any git repo" {
  local nogit; nogit=$(mktemp -d)
  run env -u MEMORY_SAVE_DIR bash -c "cd '$nogit' && '$HELPER' resolve-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${HOME}/ai-tools/memory" ]
  rm -rf "$nogit"
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
# resolve-permanent-dir: exit の恒久 file を Tier 判定で ai-tools/memory (Tier A) か
# references-private/snkr-knowledge (Tier B) へ振り分ける。逆流防止の恒久 guard。
# canonical: commands/memory-save.md § exit post-processing step 2 (Tier B routing)
# term literal は canonical rule file から抽出するため、test は override rule で固定する。
# =============================================================================

# social-hit term を含む本文 → private dir (Tier B)
@test "resolve-permanent-dir: social-hit term 含む本文は private dir を返す" {
  local rule; rule=$(mktemp)
  printf '**social-hit (block)**: foobar / bazqux\n' > "$rule"
  local priv; priv=$(mktemp -d)
  run bash -c "printf '%s' 'this text mentions foobar here' | MEMORY_SOCIAL_HIT_RULE='$rule' MEMORY_PRIVATE_DIR='$priv' '$HELPER' resolve-permanent-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$priv" ]
  rm -f "$rule"; rm -rf "$priv"
}

# term を含まない汎用本文 → ai-tools/memory (Tier A = MEMORY_SAVE_DIR)
@test "resolve-permanent-dir: term 無い汎用本文は ai-tools/memory (Tier A) を返す" {
  local rule; rule=$(mktemp)
  printf '**social-hit (block)**: foobar / bazqux\n' > "$rule"
  run bash -c "printf '%s' 'a generic lesson about bash set -e pitfalls' | MEMORY_SOCIAL_HIT_RULE='$rule' '$HELPER' resolve-permanent-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$MEMORY_SAVE_DIR" ]
  rm -f "$rule"
}

# 大文字小文字を無視して match する (grep -i)
@test "resolve-permanent-dir: term 判定は大文字小文字を無視する" {
  local rule; rule=$(mktemp)
  printf '**social-hit (block)**: FooBar\n' > "$rule"
  local priv; priv=$(mktemp -d)
  run bash -c "printf '%s' 'lowercase foobar mention' | MEMORY_SOCIAL_HIT_RULE='$rule' MEMORY_PRIVATE_DIR='$priv' '$HELPER' resolve-permanent-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$priv" ]
  rm -f "$rule"; rm -rf "$priv"
}

# rule file 不在時は安全側 (Tier A) に倒す (term 抽出 0 件 → 全て ai-tools/memory)
@test "resolve-permanent-dir: rule file 不在時は Tier A に倒す" {
  run bash -c "printf '%s' 'any content snkrdunk-like' | MEMORY_SOCIAL_HIT_RULE='/nonexistent/rule.md' '$HELPER' resolve-permanent-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$MEMORY_SAVE_DIR" ]
}

# canonical rule file 経由で実 term (snkrdunk) を含む本文が private へ振られる (回帰防止)
@test "resolve-permanent-dir: canonical rule の実 term snkrdunk は private へ振る" {
  local canonical="${HOME}/.claude/rules/public-repo-private-data-block.md"
  if [ ! -f "$canonical" ]; then skip "canonical rule file 不在 (sync 前環境)"; fi
  if ! grep -q '^\*\*social-hit (block)\*\*:.*snkrdunk' "$canonical"; then skip "canonical に snkrdunk term 無し"; fi
  local priv; priv=$(mktemp -d)
  run bash -c "printf '%s' 'snkrdunk.com の v2 実装メモ' | MEMORY_PRIVATE_DIR='$priv' '$HELPER' resolve-permanent-dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$priv" ]
  rm -rf "$priv"
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

@test "find-clear-entry: append-clear-line で書いた topic の [clear] 行を拾う" {
  "$HELPER" append-clear-line "reload-fix" "summary text" "abc1234"
  run "$HELPER" find-clear-entry "reload-fix"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[clear] reload-fix "* ]]
  [[ "$output" == *"abc1234"* ]]
}

@test "find-clear-entry: 存在しない topic は空 + exit 0" {
  "$HELPER" append-clear-line "other-topic" "summary" ""
  run "$HELPER" find-clear-entry "missing-topic"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "find-clear-entry: 部分 match (substring) では hit しない" {
  "$HELPER" append-clear-line "reload-fix-v2" "summary" ""
  run "$HELPER" find-clear-entry "reload-fix"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "pbcopy-reload: /reload <topic> を stdout に返す (pbcopy 不在でも exit 0)" {
  run "$HELPER" pbcopy-reload "my-topic"
  [ "$status" -eq 0 ]
  [ "$output" = "/reload my-topic" ]
}

@test "prepare: MEMORY_SAVE_DIR override が dir= に反映される" {
  run "$HELPER" prepare foo
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^dir=${MEMORY_SAVE_DIR}$"
}

@test "prepare: 既存 file なしは new_name に today + topic、merge_target は空" {
  run "$HELPER" prepare foo
  [ "$status" -eq 0 ]
  local today; today=$(date +%Y%m%d)
  echo "$output" | grep -q "^new_name=work-context-${today}-foo$"
  echo "$output" | grep -q '^merge_target=$'
}

@test "prepare: 同日同 topic file ありは merge_target を返し new_name は空" {
  local today; today=$(date +%Y%m%d)
  touch "${MEMORY_SAVE_DIR}/work-context-${today}-foo.md"
  run "$HELPER" prepare foo
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "^merge_target=${MEMORY_SAVE_DIR}/work-context-${today}-foo.md$"
  echo "$output" | grep -q '^new_name=$'
}

@test "prepare: branch 引数の issue key が new_name に prefix される" {
  run "$HELPER" prepare login "feature/PROJ-123-add-login"
  [ "$status" -eq 0 ]
  local today; today=$(date +%Y%m%d)
  echo "$output" | grep -q "^issue_key=PROJ-123$"
  echo "$output" | grep -q "^new_name=work-context-${today}-PROJ-123-login$"
}

@test "prepare: 非 git dir でも exit 0 で worktree / branch は空" {
  local nogit; nogit=$(mktemp -d)
  run env MEMORY_SAVE_DIR="$MEMORY_SAVE_DIR" bash -c "cd '$nogit' && '$HELPER' prepare foo"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '^worktree=$'
  echo "$output" | grep -q '^branch=$'
  rm -rf "$nogit"
}

@test "finalize clear: MEMORY.md prepend + stdout は /reload <topic>" {
  run "$HELPER" finalize clear my-topic "1 行 summary" abc1234
  [ "$status" -eq 0 ]
  [ "$output" = "/reload my-topic" ]
  head -1 "${MEMORY_SAVE_DIR}/MEMORY.md" | grep -qF '[clear] my-topic — 1 行 summary (commit: abc1234)'
}

@test "finalize topic: update-index 相当の行を書き stdout は /reload <topic>" {
  run "$HELPER" finalize topic work-context-20260101-foo foo "desc text" "hook text"
  [ "$status" -eq 0 ]
  [ "$output" = "/reload foo" ]
  head -1 "${MEMORY_SAVE_DIR}/MEMORY.md" | grep -qF '[desc text](work-context-20260101-foo.md) — hook text'
}

@test "finalize: 不明 mode は非 0 で終了する" {
  run "$HELPER" finalize bogus foo bar
  [ "$status" -ne 0 ]
}
