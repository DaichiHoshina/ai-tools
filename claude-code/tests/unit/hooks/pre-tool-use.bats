#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh
# 残余 test 集約 file: social-hit block / cat-read-hint / inject-log (skip)
# 他の test は下記に分割済み:
#   - pre-tool-use-classification.bats (Safe/Boundary/Forbidden 分類)
#   - pre-tool-use-dangerous.bats       (detect_dangerous_patterns / HEREDOC)
#   - pre-tool-use-jargon.bats          (AI 定型語 / gap1-3 / ng-dict-inject)
#   - pre-tool-use-today-commits.bats   (_inject_today_commits)
#   - pre-tool-use-memory.bats          (legacy-memory-block / memory-exclusion)
# NOTE: 本 file は hook の social-hit allowlist (pre-tool-use.sh:391) 対象。
#       social-hit term を literal 保持するため、この file を allowlist に残す。
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
# inject byte size log テスト
# _append_jp_quality_inject_log: 外向き text block/warn 判定直前に byte 数を記録する
# =============================================================================

@test "inject-log: commit message チェック時に jp-quality-inject.log が追記される" {
  skip "実装 (_append_jp_quality_inject_log) が hooks/pre-tool-use.sh から削除済み。log 追記機能は復活時に unskip"
  local log_file="$HOME/.claude/logs/jp-quality-inject.log"
  local before_lines=0
  [[ -f "$log_file" ]] && before_lines=$(wc -l < "$log_file")

  # 難読漢語 block で _block_if_ai_jargon → inject log が書かれる
  local input
  input=$(jq -n --arg c 'git commit -m "鑑みると修正する"' \
    '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  # exit 2 (block) を期待するが、log 書き込みを確認するために status は問わない

  [[ -f "$log_file" ]]
  local after_lines
  after_lines=$(wc -l < "$log_file")
  [[ "$after_lines" -gt "$before_lines" ]]

  # 最終行に期待フォーマットが含まれること
  local last_line
  last_line=$(tail -1 "$log_file")
  [[ "$last_line" =~ "tool=commit message" ]]
  [[ "$last_line" =~ "bytes=" ]]
  [[ "$last_line" =~ "threshold=1500" ]]
  [[ "$last_line" =~ "status=" ]]
}

# =============================================================================
# social-hit block stderr echo テスト
# hit_term= format 検証 (2026-06-08 追加)
# =============================================================================

# social-hit block 発生時に stderr へ [social-hit-block] hit_term=<term> file=<path> を出力する検証
# NOTE: term literal は split 記法で hook block を回避 (このファイル自体は allowlist 除外済)

_run_social_hit_write() {
  local file_path="$1"
  local content="$2"
  local tool_name="${3:-Write}"
  local input
  input=$(jq -n --arg fp "$file_path" --arg ct "$content" \
    '{file_path: $fp, content: $ct}')
  # stdout と stderr を両方取得するため merged variant を使う
  invoke_hook_run_merged "$tool_name" "$input"
}

# =============================================================================
# 2026-07-09: Edit/Write の social-hit / private-name block を恒久廃止
# 理由: local reversible な file 書込を毎回止めるとメモ集約作業等が回らない。
#       不可逆な公開経路 (git commit / gh / glab) は Bash 側の block で防ぐ。
# 下記 test 群は「Edit/Write では block されない (素通し)」ことの回帰保証。
# =============================================================================

@test "social-hit: Write は hit 語含んでも block されない (Edit/Write 経路恒久廃止)" {
  local term1="snkr""dunk"
  local target_path
  target_path="${HOME}/ai-tools/claude-code/some-new-file.md"
  _run_social_hit_write "${target_path}" "this mentions ${term1} product"
  # Edit/Write は素通し (exit 2 にならない)
  [[ "$status" -ne 2 ]]
  # stderr に [social-hit-block] も出ない
  ! echo "${output}" | grep -q "\[social-hit-block\] hit_term="
}

@test "social-hit: ai-tools 別 file への Write も素通し" {
  local term2="snkr""dunk"
  local target_path
  target_path="${HOME}/ai-tools/claude-code/another-file.md"
  _run_social_hit_write "${target_path}" "${term2} data pipeline"
  [[ "$status" -ne 2 ]]
}

@test "social-hit: ai-tools 配下以外のパスも素通し (従来通り)" {
  local term1="snkr""dunk"
  local outside_path
  outside_path="${HOME}/ghq/github.com/myorg/some-repo/file.md"
  _run_social_hit_write "${outside_path}" "${term1} content"
  [[ "$status" -ne 2 ]]
}

@test "social-hit: ghq 実 path への Write も素通し" {
  local term1="snkr""dunk"
  local ghq_path
  ghq_path="${HOME}/ghq/github.com/DaichiHoshina/ai-tools/claude-code/some-new-file.md"
  _run_social_hit_write "${ghq_path}" "this mentions ${term1} product"
  [[ "$status" -ne 2 ]]
}

# =============================================================================
# cat simple read → Read ツール振替 hint テスト
# =============================================================================

@test "cat-read-hint: cat file.md → additionalContext に Read hint が出る" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"cat /path/to/CLAUDE.md"}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ "$ctx" =~ "Read" ]]
}

@test "cat-read-hint: cat file.json → additionalContext に Read hint が出る" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"cat /path/to/settings.json"}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ "$ctx" =~ "Read" ]]
}

@test "cat-read-hint: cat > file.md (write 系) → Read hint が出ない" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"cat > /tmp/out.md"}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ ! "$ctx" =~ "cat でファイル読み取り" ]]
}

@test "cat-read-hint: cat file.md | head (pipe 系) → Read hint が出ない" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"cat /path/to/CLAUDE.md | head -20"}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ ! "$ctx" =~ "cat でファイル読み取り" ]]
}
