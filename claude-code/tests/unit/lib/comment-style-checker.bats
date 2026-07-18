#!/usr/bin/env bats
# =============================================================================
# BATS Tests for comment-style-checker.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/comment-style-checker.sh"
  export HOME="${BATS_TEST_TMPDIR}"
}

# =============================================================================
# 正常系: 常体で閉じた comment は検出されない
# =============================================================================

@test "comment-style: closed sentence in shell comment is not flagged" {
  local content=$'#!/bin/bash\n# 常体で閉じた comment を書いた\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "comment-style: closed sentence in Go comment is not flagged" {
  local content=$'package main\n// 常体で閉じた comment を書いた\nfunc main() {}'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.go' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# 異常系: 体言止めは検出される
# =============================================================================

@test "comment-style: taigen-dome sentence is flagged" {
  local content=$'#!/bin/bash\n# 改行文字の処理\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "改行文字の処理" ]]
}

# =============================================================================
# 末尾閉じ括弧の剥がし (動詞 + 括弧補足の誤検出防止、2026-07-18)
# =============================================================================

@test "comment-style: verb + closing bracket (動詞 + 括弧補足) is not flagged" {
  local content=$'package main\n// 体言止めを検出する (canonical: guidelines/writing/code-comment.md)\nfunc main() {}'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.go' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "comment-style: noun + closing bracket (体言止め + 括弧) is still flagged" {
  local content=$'package main\n// 誤爆防止)\nfunc main() {}'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.go' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "誤爆防止" ]]
}

# =============================================================================
# 偽陽性防止: literal \n (backslash+n の 2 文字) を含む content で誤分断されない
# regression: 過去に unescape 処理が literal \n を実改行に変換し、
# 「// 改行文字\nを検出する」の 1 行が「改行文字」で分断され誤検出されていた
# =============================================================================

@test "comment-style: literal backslash-n in content does not cause false positive" {
  local content=$'#!/bin/bash\n# 改行文字 \\n を検出する\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# skip pattern: MEMO: / TODO: 等の prefix は判定対象外にする
# =============================================================================

@test "comment-style: MEMO prefix is skipped" {
  local content=$'#!/bin/bash\n# MEMO: 後で見直す対象の一覧\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "comment-style: TODO prefix is skipped even with taigen-dome" {
  local content=$'#!/bin/bash\n# TODO: 型定義の整理\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# 対象外: 英語のみの comment は判定 skip
# =============================================================================

@test "comment-style: english-only comment is skipped" {
  local content=$'#!/bin/bash\n# english only comment without period\necho ok'
  run bash -c "source '$LIB_FILE' && run_comment_style_check '/tmp/x.sh' \"\$1\"" _ "$content"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# MultiEdit: post-tool-use.sh の jq 抽出が edits[].new_string を join することを間接的に確認する
# regression: 過去に .tool_input.new_string を top-level 参照しており MultiEdit では常に空になっていた
# MEMO: 下記 jq filter は post-tool-use.sh:25 と手動同期で維持する (変更時は両方直す)
# =============================================================================

@test "post-tool-use: MultiEdit input yields joined new_string from edits[]" {
  local input='{"tool_name":"MultiEdit","tool_input":{"file_path":"/tmp/x.sh","edits":[{"old_string":"a","new_string":"# 体言止めコメント"},{"old_string":"b","new_string":"echo ok"}]}}'
  local extracted
  extracted="$(printf '%s' "$input" | jq -r 'if .tool_name == "Edit" then (.tool_input.new_string // "") elif .tool_name == "MultiEdit" then ([.tool_input.edits[]?.new_string // empty] | join("\n")) else "" end')"
  [[ "$extracted" =~ "体言止めコメント" ]]
  [[ "$extracted" =~ "echo ok" ]]
}
