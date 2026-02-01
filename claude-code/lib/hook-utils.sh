#!/bin/bash
# =============================================================================
# Hook共通ユーティリティ
# =============================================================================

# 標準入力からJSON読み取り
read_hook_input() {
  cat
}

# JSONフィールド取得
# Usage: get_field "$INPUT" "field_name" "default_value"
get_field() {
  local input="$1"
  local field="$2"
  local default="${3:-}"
  echo "$input" | jq -r ".${field} // \"${default}\""
}

# ネストしたフィールド取得
# Usage: get_nested_field "$INPUT" "workspace.current_dir" "."
get_nested_field() {
  local input="$1"
  local path="$2"
  local default="${3:-}"
  echo "$input" | jq -r ".${path} // \"${default}\""
}
