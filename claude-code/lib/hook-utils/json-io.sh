#!/bin/bash
# =============================================================================
# hook-utils / json-io module
# =============================================================================
if [[ "${_HOOK_UTILS_JSON_IO_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_JSON_IO_LOADED=1

# jqの存在チェック。なければエラー出力してexit 1
# Usage: require_jq
require_jq() {
  if ! command -v jq &>/dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq (macOS) / apt install jq (Ubuntu)"}' >&2
    exit 1
  fi
}

# 標準入力からJSON読み取り
read_hook_input() {
  cat
}

# MESSAGE 変数への append（複数 hook 分岐の警告共存）
# 既存メッセージが空なら代入、非空なら改行結合。
# Usage: MESSAGE=$(append_message "$MESSAGE" "新しい警告")
append_message() {
  local current="${1:-}"
  local addition="${2:-}"
  if [[ -z "${addition}" ]]; then
    printf '%s' "${current}"
  elif [[ -z "${current}" ]]; then
    printf '%s' "${addition}"
  else
    printf '%s\n%s' "${current}" "${addition}"
  fi
}

# JSONフィールド取得（フラット or dotted path 両対応）
# Usage:
#   get_field "$INPUT" "field_name" "default_value"
#   get_field "$INPUT" "workspace.current_dir"   # dotted path も可
get_field() {
  local input="$1"
  local field="$2"
  local default="${3:-}"
  echo "$input" | jq -r ".${field} // \"${default}\""
}

# ネストJSONフィールド取得（dotted path / 配列添字対応）
# Usage:
#   get_nested_field "$INPUT" "workspace.current_dir"
#   get_nested_field "$INPUT" "a.b.c" "default"
#   get_nested_field "$INPUT" "items[0].name"
#
# Notes:
# - path は jq の構造的に valid な dotted path / 配列添字のみ許可。
#   field        : 英字 or `_` で始まり、英数字 / `_` のみ
#   field.sub    : `.` で連結（連続 `.` や末尾 `.` は不可）
#   field[0]     : `[]` 内は数字のみ（空・英字は不可）
#   組み合わせ   : `a.b[0].c[1]` のような chain 可
#   構造的に不正な path（`..x` / `[abc]` / `]x[` / `[0]` 単独 等）は default 返却。
#   許可外文字や jq 演算子（` `, `,`, `|` 等）混入も同様。
# - default 値は jq 式リテラル内に直挿入される。`"` / バックスラッシュは escape
#   されない。printable ASCII リテラル前提（caller 責任）
# - $input 由来の値を path に渡してはいけない（許可文字内でも論理上 path traversal）
get_nested_field() {
  local input="$1"
  local path="$2"
  local default="${3:-}"
  # 構造validation: jq path として有効な形のみ通す（jq filter injection 防止 + jq 構文エラー回避）
  local valid_path_re='^[A-Za-z_][A-Za-z0-9_]*((\.[A-Za-z_][A-Za-z0-9_]*)|(\[[0-9]+\]))*$'
  if [[ ! "$path" =~ $valid_path_re ]]; then
    echo "$default"
    return 0
  fi
  echo "$input" | jq -r ".${path} // \"${default}\""
}

# 複数JSONフィールドを1回のjq呼び出しでTSV取得（fork削減）
# Usage:
#   IFS=$'\t' read -r VAR1 VAR2 ... < <(extract_json_fields "$INPUT" '.f1 // "x"' '.f2 // 0' ...)
#
# 各引数は jq 式リテラル（デフォルト値含む）。タブ区切りで返すため値にタブを含む場合は不可。
#
# Notes:
# - **Security**: 引数 $@ はそのまま jq 式に連結される。呼び出し元責任で**静的リテラルのみ**
#   渡すこと。$INPUT 値由来の文字列を渡すと jq 式 injection の可能性あり。
# - **Failure mode**: jq が異常終了（不正 JSON 入力等）すると stdout 空 → 呼び出し側 `read`
#   が EOF を返し、`set -e` 下では hook 早期終了する（旧 `VAR=$(jq ...)` と同挙動）。
#   信頼できない入力には `validate_json` で事前検証推奨。
extract_json_fields() {
  local input="$1"; shift
  local jq_expr="["
  local first=1
  for f in "$@"; do
    if (( first )); then
      jq_expr+="$f"
      first=0
    else
      jq_expr+=", $f"
    fi
  done
  jq_expr+="] | @tsv"
  jq -r "$jq_expr" <<< "$input"
}
