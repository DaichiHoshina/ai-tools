#!/usr/bin/env bash
# code-comment.md 規範「本文は常体で閉じる」への違反を、新規追加された comment 行から検出する。
# 出力は件数 + 先頭 3 行で、呼び出し側が MESSAGE に append する。

set -euo pipefail

# 常体で閉じている / 対象外と判定する末尾 pattern
# 五段活用終止形の く/ぐ/つ/ぶ/む が漏れて「書く」等を誤検出していたため 2026-07-18 に追加した。
# [[:alnum:]] は locale 依存で日本語 letter を含むため使わず、ASCII を明示する。
_COMMENT_STYLE_OK_TAIL_RE='(る|た|だ|い|う|く|ぐ|す|つ|ず|ぬ|ぶ|む|ん|よ|ね|か|な|と|も|[a-zA-Z0-9_/@#%&*+=<>~^-])$'

# 対象外 prefix (機械 marker / example label は文体判定を skip)
_COMMENT_STYLE_SKIP_PREFIX_RE='^(MEMO|TODO|FIXME|NOTE|XXX|HACK|WARN|NB|NG|OK|Bad|Good|例):'

# 拡張子 → comment marker regex
_comment_style_marker_re_for() {
  local _ext="$1"
  case "$_ext" in
    py|rb|sh|bash|zsh|tf|pl|ex|exs)
      printf '%s' '^[[:space:]]*#([^!]|$)' ;;
    sql|lua|hs)
      printf '%s' '^[[:space:]]*--' ;;
    go|ts|tsx|js|jsx|mjs|cjs|rs|java|kt|kts|c|cc|cpp|h|hpp|swift|php|scala|proto|dart)
      printf '%s' '^[[:space:]]*(//|/\*)' ;;
    *)
      return 1 ;;
  esac
}

# 拡張子ごとに marker 定義が違うため、既存の _comment_style_marker_re_for を再利用して抽出する。
_extract_comment_body_text() {
  local _file="$1"
  local _content="$2"
  local _ext="${_file##*.}"
  local _marker_re
  if ! _marker_re="$(_comment_style_marker_re_for "$_ext")"; then
    return 1
  fi
  local _out="" _line _body
  while IFS= read -r _line; do
    grep -qE "$_marker_re" <<< "$_line" || continue
    _body="$(_comment_style_strip_marker "$_line")"
    [[ -z "$_body" ]] && continue
    _out="${_out}${_body}"$'\n'
  done <<< "$_content"
  printf '%s' "$_out"
  return 0
}

# comment marker を剥がして本文だけ返す
_comment_style_strip_marker() {
  local _line="$1"
  local _body="$_line"
  # 先頭 whitespace 除去
  _body="${_body#"${_body%%[![:space:]]*}"}"
  # marker prefix 除去 (bash 変数展開で対応可能な単純 pattern のみ)
  case "$_body" in
    '//'*) _body="${_body#//}" ;;
    '/*'*) _body="${_body#/\*}"; _body="${_body%\*/}" ;;
    '#'*) _body="${_body#\#}" ;;
    '--'*) _body="${_body#--}" ;;
  esac
  # 先頭 whitespace 再除去
  _body="${_body#"${_body%%[![:space:]]*}"}"
  # 末尾 whitespace 除去
  _body="${_body%"${_body##*[![:space:]]}"}"
  # 末尾記号 (。 . ! ? , 、 : ;) を判定用に除去
  while :; do
    case "$_body" in
      *[.。!?、,:\;]) _body="${_body%?}" ;;
      *) break ;;
    esac
    _body="${_body%"${_body##*[![:space:]]}"}"
  done
  printf '%s' "$_body"
}

# 日本語 (非 ASCII) を含むか判定
_comment_style_has_japanese() {
  local _text="$1"
  # 非 ASCII byte を含めば日本語ありとみなす (URL / 識別子は ASCII のみのため誤爆しない)
  LC_ALL=C printf '%s' "$_text" | LC_ALL=C grep -q '[^ -~]' 2>/dev/null
}

# 常体で閉じているか判定 (閉じていれば OK=0)
_comment_style_is_closed() {
  local _body="$1"
  # skip prefix (MEMO: TODO: 等) は常に OK
  if [[ "$_body" =~ $_COMMENT_STYLE_SKIP_PREFIX_RE ]]; then
    return 0
  fi
  # 日本語を含まない (英語のみ) 行は対象外
  if ! _comment_style_has_japanese "$_body"; then
    return 0
  fi
  # 末尾判定
  if [[ "$_body" =~ $_COMMENT_STYLE_OK_TAIL_RE ]]; then
    return 0
  fi
  return 1
}

# 引数: file_path new_content
# 出力: warn message (件数 > 0 の時のみ、それ以外は空)
# 副作用: ~/.claude/logs/comment-style-warn.log に 1 行 append (件数 > 0 の時)
run_comment_style_check() {
  local _file="$1"
  local _content="$2"
  if [[ -z "$_file" || -z "$_content" ]]; then
    return 0
  fi
  local _ext="${_file##*.}"
  local _marker_re
  if ! _marker_re="$(_comment_style_marker_re_for "$_ext")"; then
    return 0
  fi

  local _bad_lines=()
  local _line _body _lineno=0
  while IFS= read -r _line; do
    _lineno=$((_lineno + 1))
    if ! grep -qE "$_marker_re" <<< "$_line"; then
      continue
    fi
    _body="$(_comment_style_strip_marker "$_line")"
    if [[ -z "$_body" ]]; then
      continue
    fi
    if _comment_style_is_closed "$_body"; then
      continue
    fi
    _bad_lines+=("${_lineno}: ${_body:0:80}")
  done <<< "$_content"

  local _count="${#_bad_lines[@]}"
  if [[ "$_count" -eq 0 ]]; then
    return 0
  fi

  # log に append
  local _log_dir="${HOME}/.claude/logs"
  local _log_file="${_log_dir}/comment-style-warn.log"
  mkdir -p "$_log_dir" 2>/dev/null || true
  TZ=UTC printf -v _ts '%(%Y-%m-%dT%H:%M:%SZ)T' -1
  local _bad
  for _bad in "${_bad_lines[@]}"; do
    printf '%s\t%s\t%s\t%s\n' "$_ts" "${SESSION_ID:-unknown}" "$_file" "$_bad" >> "$_log_file" 2>/dev/null || true
  done

  # stdout に warn message (先頭 3 行 + 件数)
  local _head_n=3
  local _shown=("${_bad_lines[@]:0:$_head_n}")
  local _extra=$((_count - _head_n))
  printf '⚠ code comment 体言止め検出 (%d 件): %s\n' "$_count" "$_file"
  printf '  L%s\n' "${_shown[@]}"
  if [[ "$_extra" -gt 0 ]]; then
    printf '  ... (他 %d 件、full log: ~/.claude/logs/comment-style-warn.log)\n' "$_extra"
  fi
  printf '  canonical: guidelines/writing/code-comment.md § 日本語品質 (常体で閉じる)\n'
}

# Write は content が全文なので、disk の既存 file と diff して新規行だけに絞り込む。
# file 未存在は全体を新規行扱い、既存 file の読込失敗は 1 を返し呼び出し側に block を見送らせる。
run_comment_style_new_lines_for_write() {
  local _file="$1"
  local _new_content="$2"
  if [[ ! -e "$_file" ]]; then
    printf '%s' "$_new_content"
    return 0
  fi
  local _old_content
  if ! _old_content="$(cat "$_file" 2>/dev/null)"; then
    return 1
  fi
  diff <(printf '%s\n' "$_old_content") <(printf '%s\n' "$_new_content") 2>/dev/null \
    | grep '^> ' | sed 's/^> //'
  return 0
}

# 新規行に絞り込み済みの content だけを判定し、体言止め hit で GUARD_CLASS を Forbidden にする。
# 呼び出し元スコープの GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT を直接更新する。
run_comment_style_block_check() {
  local _file="$1"
  local _content="$2"
  [[ "${GUARD_CLASS:-}" == "Forbidden" ]] && return 0
  [[ -z "$_file" || -z "$_content" ]] && return 0
  local _hits
  _hits=$(run_comment_style_check "$_file" "$_content" || true)
  [[ -z "$_hits" ]] && return 0
  GUARD_CLASS="Forbidden"
  MESSAGE="${ICON_CRITICAL:-◉} code comment 体言止め block: ${_file}"
  local _ctx="新規追加 comment が体言止めで終わっている。常体で閉じる (〜する/〜した/〜だ)。canonical: guidelines/writing/code-comment.md
${_hits}"
  if [[ -n "${ADDITIONAL_CONTEXT:-}" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_ctx}"
  else
    ADDITIONAL_CONTEXT="$_ctx"
  fi
}
