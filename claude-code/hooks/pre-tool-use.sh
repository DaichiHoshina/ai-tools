#!/usr/bin/env bash
# PreToolUse Hook - protection-mode 必須チェック
# 3層分類: Safe/Boundary/Forbidden
# v2.2.0対応: jq安全出力、パターン検出強化

set -euo pipefail

# lib/hook-utils.sh を source する (ai-tools path helper 等)
_HOOK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
# shellcheck source=../lib/hook-utils.sh
if [[ -f "${_HOOK_LIB_DIR}/hook-utils.sh" ]]; then
  # shellcheck disable=SC1091
  source "${_HOOK_LIB_DIR}/hook-utils.sh"
else
  # fallback: ~/.claude/lib/ 経由 (sync.sh to-local 済み環境)
  _FALLBACK_LIB="$HOME/.claude/lib/hook-utils.sh"
  # shellcheck disable=SC1090
  [[ -f "$_FALLBACK_LIB" ]] && source "$_FALLBACK_LIB" || true
fi

# lib/jp-quality-check.sh を source する (AI定型語 / NG語 block 系)
# shellcheck source=../lib/jp-quality-check.sh
if [[ -f "${_HOOK_LIB_DIR}/jp-quality-check.sh" ]]; then
  # shellcheck disable=SC1091
  source "${_HOOK_LIB_DIR}/jp-quality-check.sh"
else
  # fallback: ~/.claude/lib/ 経由 (sync.sh to-local 済み環境)
  _FALLBACK_JPLIB="$HOME/.claude/lib/jp-quality-check.sh"
  # shellcheck disable=SC1090
  [[ -f "$_FALLBACK_JPLIB" ]] && source "$_FALLBACK_JPLIB" || true
fi

# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'   # exclamation-circle (critical/forbidden)
ICON_WARNING=$'\u25b2'    # exclamation-triangle (boundary)

# JSON入力を読み込む
INPUT=$(cat)

# ツール名 + セッションID を jq 1 回で取得 (fork 削減、@tsv + read。他 hook と同方式)
# CLAUDE_CODE_SESSION_ID env は Claude Code v2.1.90+ で export される場合があるため fallback で参照
IFS=$'\t' read -r TOOL_NAME SESSION_ID < <(jq -r '[.tool_name // "", .session_id // ""] | @tsv' <<< "$INPUT")
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${SESSION_ID}}"

# protection-mode判定変数
GUARD_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""


# ====================================
# Rename propagation 検知
# Heading / section / symbol rename 検知 → cross-ref 残存 warning
# ====================================

# git root を解決する: file_path のディレクトリから git root を探し stdout に出力
# 引数: file_path (省略可、省略時は CWD から探す)
_resolve_git_root() {
  local file_path="${1:-.}"
  if [ -n "$file_path" ] && [ "$file_path" != "." ] && [ -d "$(dirname "$file_path")" ]; then
    local dir_path
    dir_path="$(dirname "$file_path")"
    (cd "$dir_path" && git rev-parse --show-toplevel 2>/dev/null) || dirname "$file_path"
  else
    git rev-parse --show-toplevel 2>/dev/null || echo "."
  fi
}

# repo 内を 1 パス grep し、マッチしたファイル path を改行区切りで stdout 出力 (最大 20 件)。
# git work tree 内では git grep (単一プロセス / .gitignore 尊重 / tracked+untracked) を使う。
# 非 git path では従来の find -exec grep に fallback する (bench/test の /tmp 等)。
# 引数: search_root, mode(fixed|regex), pattern
# 注: git grep は no-match で rc=1、head の SIGPIPE で rc=141 になりうるため末尾 || true で吸収
#     (呼び出し側は set -euo pipefail 下のため)
_repo_grep_files() {
  local search_root="$1"
  local mode="$2"
  local pattern="$3"
  if git -C "$search_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local _mflag="-F"
    [[ "$mode" == "regex" ]] && _mflag="-E"
    git -C "$search_root" grep -l "$_mflag" --untracked -e "$pattern" -- \
      '*.md' '*.sh' '*.ts' '*.tsx' '*.js' '*.py' '*.json' '*.yaml' '*.yml' '*.toml' '*.bats' \
      2>/dev/null | head -20 || true
  else
    local _gflag="-l"
    [[ "$mode" == "fixed" ]] && _gflag="-lF"
    find "$search_root" \
      -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.bats" \) \
      -not -path "*/.git/*" \
      -not -path "*/node_modules/*" \
      -not -path "*/dist/*" \
      -not -path "*/build/*" \
      -exec grep "$_gflag" "$pattern" {} \; 2>/dev/null | head -20 || true
  fi
}

# heading rename サブルーチン
# 引数: old_str, new_str, file_path
# 副作用: ADDITIONAL_CONTEXT にメッセージを追記する
_detect_heading_rename() {
  local old_str="$1"
  local new_str="$2"
  local file_path="${3:-.}"
  local search_root="${4:-$(_resolve_git_root "$file_path")}"

  [[ "$old_str" =~ ^(#{2,3})[[:space:]]+.+$ ]] || return 0
  [[ "$new_str" =~ ^(#{2,3})[[:space:]]+.+$ ]] || return 0

  local heading_level="${BASH_REMATCH[1]}"
  local old_title new_title
  old_title=$(echo "$old_str" | sed -E "s/^${heading_level}[[:space:]]+//" | sed 's/[[:space:]]*$//')
  new_title=$(echo "$new_str" | sed -E "s/^${heading_level}[[:space:]]+//" | sed 's/[[:space:]]*$//')

  # 旧 heading title の残存検索（.md, .sh, .ts/.tsx, .js, .py, .json, .yaml, .toml, .bats）
  local grep_results
  grep_results=$(_repo_grep_files "$search_root" fixed "$old_title")

  if [ -n "$grep_results" ]; then
    local _tmp_fc="${grep_results//$'\n'/}"
    local file_count=$(( ${#grep_results} - ${#_tmp_fc} + 1 ))
    local file_list="${grep_results//$'\n'/','}"; file_list="${file_list%,}"
    local rename_warn="${ICON_WARNING} Rename検知: 旧heading「${old_title}」→「${new_title}」、${file_count}ファイルに残存（${file_list}）。cross-ref同期確認推奨"
    if [ -n "$ADDITIONAL_CONTEXT" ]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${rename_warn}"
    else
      ADDITIONAL_CONTEXT="${rename_warn}"
    fi
  fi

  # slug 形式 anchor の残存検索 (#old-slug)
  # slug 化: 小文字化 / 英数・スペース・ハイフン以外除去 / 空白→ハイフン
  local old_slug
  old_slug=$(printf '%s' "$old_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g')
  if [ -n "$old_slug" ] && [ ${#old_slug} -gt 3 ]; then
    local slug_pattern="#${old_slug}"
    local slug_results
    slug_results=$(_repo_grep_files "$search_root" fixed "$slug_pattern")
    if [ -n "$slug_results" ]; then
      local slug_list="${slug_results//$'\n'/','}"; slug_list="${slug_list%,}"
      local slug_warn="${ICON_WARNING} anchor slug 残存: 「${slug_pattern}」が残存（${slug_list}）。bats anchor・cross-ref 同期確認推奨"
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${slug_warn}"
      else
        ADDITIONAL_CONTEXT="${slug_warn}"
      fi
    fi
  fi
}

# symbol rename サブルーチン (識別子 1 個のみ置換を検知)
# 引数: old_str, new_str, file_path
# 副作用: ADDITIONAL_CONTEXT にメッセージを追記する
_detect_symbol_rename() {
  local old_str="$1"
  local new_str="$2"
  local file_path="${3:-.}"
  local search_root="${4:-$(_resolve_git_root "$file_path")}"

  # 識別子パターンが含まれるか確認 (false positive 削減)
  [[ "$old_str" =~ [^a-zA-Z0-9_]?([a-zA-Z_][a-zA-Z0-9_]*)[^a-zA-Z0-9_]? ]] || return 0
  [[ "$new_str" =~ [^a-zA-Z0-9_]?([a-zA-Z_][a-zA-Z0-9_]*)[^a-zA-Z0-9_]? ]] || return 0

  # 識別子数を数える（1 個のみ rename と判定）
  local _old_idents _new_idents
  mapfile -t _old_idents < <(grep -o '[a-zA-Z_][a-zA-Z0-9_]*' <<< "$old_str")
  mapfile -t _new_idents < <(grep -o '[a-zA-Z_][a-zA-Z0-9_]*' <<< "$new_str")
  local old_count=${#_old_idents[@]}
  local new_count=${#_new_idents[@]}

  [ "$old_count" -eq 1 ] && [ "$new_count" -eq 1 ] || return 0

  local old_ident="${_old_idents[0]}"
  local new_ident="${_new_idents[0]}"
  [ "$old_ident" != "$new_ident" ] || return 0

  # 旧 identifier の残存検索 (word boundary)
  local grep_results
  grep_results=$(_repo_grep_files "$search_root" regex "\b${old_ident}\b")

  if [ -n "$grep_results" ]; then
    local _tmp_fc="${grep_results//$'\n'/}"
    local file_count=$(( ${#grep_results} - ${#_tmp_fc} + 1 ))
    local file_list="${grep_results//$'\n'/','}"; file_list="${file_list%,}"
    local rename_warn="${ICON_WARNING} Rename検知: 「${old_ident}」→「${new_ident}」、${file_count}ファイルに残存（${file_list}）。cross-ref同期確認推奨"
    if [ -n "$ADDITIONAL_CONTEXT" ]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${rename_warn}"
    else
      ADDITIONAL_CONTEXT="${rename_warn}"
    fi
  fi
}

# orchestrator: skip guard のみ担当し、2 つの private helper を順次呼ぶ
detect_rename_propagation() {
  local old_str="$1"
  local new_str="$2"
  local file_path="${3:-.}"

  # skip: 新名が空、旧名 ≤ 3 文字（false positive 多い）
  if [ -z "$new_str" ] || [ ${#old_str} -le 3 ]; then
    return
  fi

  # git root を 1 回だけ解決し helper に渡す (helper 毎の重複解決を排除)
  local search_root
  search_root=$(_resolve_git_root "$file_path")

  # heading rename を先に試みる (heading なら symbol rename は skip)
  if [[ "$old_str" =~ ^(#{2,3})[[:space:]]+.+$ ]] && [[ "$new_str" =~ ^(#{2,3})[[:space:]]+.+$ ]]; then
    _detect_heading_rename "$old_str" "$new_str" "$file_path" "$search_root"
    return
  fi

  _detect_symbol_rename "$old_str" "$new_str" "$file_path" "$search_root"
}

# ====================================
# social-hit block
# ~/ai-tools/ public repo への社内 product 名 / 社内識別子の書き込みを hard block
# term list は ~/.claude/rules/public-repo-private-data-block.md の
# "social-hit (block)" key から動的抽出 (PRINCIPLES.md と同じ記法)
# ====================================
_social_hit_rule_file="$HOME/.claude/rules/public-repo-private-data-block.md"

# ai-tools public repo への social-hit term 書き込みを block する
# 引数: file_path, content
_check_social_hit() {
  local file_path="$1"
  local content="$2"
  [[ -z "$file_path" ]] && return 0
  [[ -z "$content" ]] && return 0

  # rule file 不在時は silent pass (未 sync 環境への配慮)
  [[ -f "$_social_hit_rule_file" ]] || return 0

  # ai-tools/ 配下の path のみ判定対象 (symlink と ghq 実 path の両方を OR 判定)
  if ! _is_aitools_path "$file_path"; then
    return 0
  fi

  # 自己除外 (allowlist): rule 説明文として term を保持する file は判定対象外
  local rel_path
  rel_path=$(_aitools_relpath "$file_path")
  case "$rel_path" in
    claude-code/rules/public-repo-private-data-block.md|\
    claude-code/CLAUDE.md|\
    claude-code/hooks/pre-tool-use.sh|\
    claude-code/tests/unit/hooks/pre-tool-use.bats)
      return 0
      ;;
  esac

  # social-hit term 抽出 → 1 パス grep で hit 語列挙 (N×fork → 1 fork、jp-quality-check.sh:182 と同手法)
  local found=() _terms=() word
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    _terms+=("$word")
  done < <(_extract_term_list "$_social_hit_rule_file" "social-hit (block)")
  if [[ ${#_terms[@]} -gt 0 ]]; then
    local _found_raw
    _found_raw=$(printf '%s' "$content" | grep -oFf <(printf '%s\n' "${_terms[@]}") | sort -u || true)
    [[ -n "$_found_raw" ]] && mapfile -t found < <(printf '%s\n' "$_found_raw")
  fi

  if [[ ${#found[@]} -gt 0 ]]; then
    local word_list
    word_list=$(printf '%s' "${found[*]}" | tr ' ' ',')
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} social-hit block: [${word_list}] file=${file_path}"
    ADDITIONAL_CONTEXT="ai-tools repo は public。社内 product 名 / 識別子を public repo に書き込めません。
対処: file_path を ~/.claude/references-private/ に切り替えるか、term を削除 / 匿名化して再実行してください。
ログ: ~/.claude/logs/social-hit-block.log"
    printf '[social-hit-block] hit_term=%s file=%s\n' "$word_list" "$file_path" >&2
    _append_block_log "${HOME}/.claude/logs/social-hit-block.log" "$TOOL_NAME" "$word_list" "$file_path"
  fi
}

# Bash 外向き text (commit message / pr body 等) を social-hit term で判定する
# 引数: label (人間可読: "commit message" / "gh pr create" 等), text
_check_social_hit_in_text() {
  local label="$1"
  local text="$2"
  [[ -z "$text" ]] && return 0
  [[ -f "$_social_hit_rule_file" ]] || return 0

  local found=() _terms=() word
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    _terms+=("$word")
  done < <(_extract_term_list "$_social_hit_rule_file" "social-hit (block)")
  if [[ ${#_terms[@]} -gt 0 ]]; then
    local _found_raw
    _found_raw=$(printf '%s' "$text" | grep -oFf <(printf '%s\n' "${_terms[@]}") | sort -u || true)
    [[ -n "$_found_raw" ]] && mapfile -t found < <(printf '%s\n' "$_found_raw")
  fi

  if [[ ${#found[@]} -gt 0 ]]; then
    local word_list
    word_list=$(printf '%s' "${found[*]}" | tr ' ' ',')
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} social-hit block: [${word_list}] in ${label}"
    ADDITIONAL_CONTEXT="ai-tools repo は public。社内 product 名 / 識別子を ${label} に含められません。
対処: term を削除 / 匿名化 (例: <product-name>) して再実行してください。
ログ: ~/.claude/logs/social-hit-block.log"
    printf '[social-hit-block] hit_term=%s label=%s\n' "$word_list" "$label" >&2
    _append_block_log "${HOME}/.claude/logs/social-hit-block.log" "$TOOL_NAME" "$word_list" "${label}"
  fi
}

# ====================================
# private-name block
# ~/.claude/references-private/private-name-list.txt を動的読込し、
# social-hit static list と merged して ai-tools 配下 file・Bash 外向き text を block
# allowlist: daichi / DaichiHoshina / Daichi Hoshina / Anthropic / Claude
# ====================================
_private_name_list_file="$HOME/.claude/references-private/private-name-list.txt"
_private_name_allowlist=("daichi" "DaichiHoshina" "Daichi Hoshina" "Anthropic" "Claude")

# private-name-list.txt から term list を読込 (# 行・空行 skip、file 不在時は空)
_load_private_name_terms() {
  [[ -f "$_private_name_list_file" ]] || return 0
  grep -v '^[[:space:]]*#' "$_private_name_list_file" | grep -v '^[[:space:]]*$' || true
}

# allowlist に含まれるか判定 (含まれる場合 return 0)
_is_private_name_allowlisted() {
  local term="$1"
  local item
  for item in "${_private_name_allowlist[@]}"; do
    [[ "$term" == "$item" ]] && return 0
  done
  return 1
}

# private-name block 判定: file_path / label, content を受け取り hit 時に GUARD_CLASS を Forbidden にする
# 引数: target_label (file_path or "commit message" 等), content
_check_private_name() {
  local target_label="$1"
  local content="$2"
  [[ -z "$content" ]] && return 0

  # term list 読込
  local terms=()
  while IFS= read -r term; do
    [[ -z "$term" ]] && continue
    _is_private_name_allowlisted "$term" && continue
    terms+=("$term")
  done < <(_load_private_name_terms)

  # term が 0 件なら skip (list 不在 / 空 → fallback は AI 側 default rule のみ)
  [[ ${#terms[@]} -eq 0 ]] && return 0

  # 1 パス grep で hit 語列挙 (N×fork → 1 fork、jp-quality-check.sh:182 と同手法)
  local found=()
  local _found_raw
  _found_raw=$(printf '%s' "$content" | grep -oFf <(printf '%s\n' "${terms[@]}") | sort -u || true)
  [[ -n "$_found_raw" ]] && mapfile -t found < <(printf '%s\n' "$_found_raw")

  if [[ ${#found[@]} -gt 0 ]]; then
    local word_list
    word_list=$(printf '%s\n' "${found[@]}" | tr '\n' ',' | sed 's/,$//')
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} private name detected: [${word_list}] in ${target_label}"
    ADDITIONAL_CONTEXT="ai-tools repo は public。個人名 / 会社名 / project 固有名詞を public repo に書き込めません。
対処: term を削除 / 匿名化 (<person-name> / <company-name> / <project-name>) して再実行してください。
canonical list: ~/.claude/references-private/private-name-list.txt (user 記入のみ)
ログ: ~/.claude/logs/private-name-block.log"
    printf '[private-name-block] hit_term=%s target=%s\n' "$word_list" "$target_label" >&2
    _append_block_log "${HOME}/.claude/logs/private-name-block.log" "$TOOL_NAME" "$word_list" "$target_label"
  fi
}

# ====================================
# parent 事前準備 missing 検出 (warn-only)
# Task tool 発火 prompt が ≥500 word かつ file:line pattern / label 付き keyword
# (verify cmd: / DoD: / target file:) のいずれも未出現の場合に warn を返す (block はしない)
# 引数: prompt (string)
# 戻り値: 0 = missing 検出 / 1 = 事前準備済 or 短 prompt
# ====================================
_check_parent_prep_missing() {
  local prompt="$1"
  # 短 prompt は対象外 (≤500 word の subagent context budget と一致)
  local word_count
  word_count=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
  [ "$word_count" -lt 500 ] && return 1

  # file:line pattern (例: src/foo.ts:42) のみ「事前準備済」とみなす
  # 自然言語中の target / verify 単語では trigger しない (too-broad false-negative 防止)
  # (^|[[:space:]]) 境界を要求: URL 内の host:port (例: example.com:8080) は ://直後で空白前置なし → 除外
  if printf '%s' "$prompt" | grep -qE "(^|[[:space:]])[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+"; then
    return 1
  fi
  # label 付き keyword のみ trigger: "verify cmd:" / "DoD:" / "target file:" 等
  if printf '%s' "$prompt" | grep -qiE "(verify cmd|DoD|target file)[ \t]*[:=]"; then
    return 1
  fi
  return 0  # 事前準備 missing 検出
}

# ====================================
# 口語起動 marker 検出 (warn-only)
# Task tool 発火 prompt に口語起動 marker (お任せ / 全部 等) が含まれ、
# かつ file:line 明示がない場合に warn を返す (block はしない)
# 引数: prompt (string)
# 戻り値: 0 = marker 検出 (warn 対象) / 1 = marker なし or file:line 明示済
# ====================================
_check_colloquial_trigger_missing_delegation() {
  local prompt="$1"

  # marker list: 口語起動を示す JP/EN フレーズ (case-insensitive POSIX ERE)
  # お任せ / おまかせ / 全部 / 全消化 / できるもの全部 / 修正して欲しい / 改善して / 全自動で / auto で
  if ! printf '%s' "$prompt" | grep -qiE \
    'お任せ|おまかせ|全部|全消化|できるもの全部|修正して欲しい|改善して|全自動で|auto[[:space:]]*で'; then
    return 1  # marker なし → warn 不要
  fi

  # file:line が明示されていれば事前準備済とみなし warn しない
  # _check_parent_prep_missing と同一判定 (空白境界 + URL host:port 除外)
  if printf '%s' "$prompt" | grep -qE "(^|[[:space:]])[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+"; then
    return 1  # file:line あり → 委譲準備済
  fi
  if printf '%s' "$prompt" | grep -qiE "(verify cmd|DoD|target file)[ \t]*[:=]"; then
    return 1  # label 付き keyword あり → 委譲準備済
  fi

  return 0  # marker 検出 + file:line なし → warn 対象
}

# ====================================
# session split warn (warn-only, pre-tool-use)
# session age >= 3h or jsonl msg 数 >= 1000 で /clear 推奨を additionalContext に注入
# 1 session につき 1 回のみ発火 (state file: ~/.claude/logs/.session-split-warned-<id>)
# ====================================
_check_session_split() {
  local session_id="$1"
  local cwd="$2"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0

  local _WARN_FILE="${HOME}/.claude/logs/.session-split-warned-${session_id}"
  [[ -f "$_WARN_FILE" ]] && return 0  # 既に通知済 → skip

  # jsonl path 構築 (msg count で引き続き使用)
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  [[ ! -f "$_JSONL" ]] && return 0

  # session start epoch (共通関数で解決)
  local _NOW
  printf -v _NOW '%(%s)T' -1
  local _START_EPOCH
  _START_EPOCH=$(_resolve_session_jsonl_epoch "$session_id" "$cwd") || return 0
  local _ELAPSED=$(( _NOW - _START_EPOCH ))

  # msg count
  local _MSG_COUNT
  _MSG_COUNT=$(grep -c '"type":"user"\|"type":"assistant"' "$_JSONL" 2>/dev/null) || _MSG_COUNT=0

  local _AGE_H=$(( _ELAPSED / 3600 ))
  local _REASON=""
  (( _ELAPSED >= _TH_SESSION_AGE_S )) && _REASON="age=${_AGE_H}h"
  if (( _MSG_COUNT >= _TH_SESSION_MSG )); then
    [[ -n "$_REASON" ]] && _REASON="${_REASON} / "
    _REASON="${_REASON}messages=${_MSG_COUNT}"
  fi
  [[ -z "$_REASON" ]] && return 0

  # 発火: state file 書き込み + log 追記 + additionalContext 追加
  mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
  touch "$_WARN_FILE" 2>/dev/null || true
  local _TS_LABEL
  printf -v _TS_LABEL '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | %s | %s | msg=%s\n' "$_TS_LABEL" "$session_id" "age=${_AGE_H}h" "$_MSG_COUNT" \
    >> "${HOME}/.claude/logs/session-split-warn.log" 2>/dev/null || true

  local _WARN_MSG="[session-split-warn] ${_REASON} exceeds threshold (3h / 1000 msg). Suggest /clear or /compact to refresh cache TTL"
  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_WARN_MSG}"
  else
    ADDITIONAL_CONTEXT="${_WARN_MSG}"
  fi
}

# ====================================
# large-repo 連続 Edit 強制委譲 signal (warn-only, pre-tool-use)
# ====================================
# parent が 1 message 1 Task で逐次 Agent fire する pattern を検出し、
# 並列化を促す additionalContext を注入する (warn-only)
#
# 発火条件: tool_name == "Task" の pre-tool-use 時のみ
# counter: ~/.claude/logs/.agent-fire-count-<session_id>  (整数 1 行)
# 最終 fire timestamp: ~/.claude/logs/.agent-fire-lastts-<session_id>  (nanosec 整数)
# fence: ~/.claude/logs/.sequential-fire-warned-<session_id>  (1 threshold 1 inject)
# log: ~/.claude/logs/sequential-fire-warn.log
#
# parallel 判定: 直前 Task fire から 500ms (500000000 ns) 以内 = 同一 message 内並列発火
#   → counter をリセット (並列は問題ない)
# sequential 判定: 500ms 超 = 別 message からの逐次発火
#   → counter++ し threshold (>=3) で warn 1 回 inject
# ====================================
_check_sequential_agent_fire() {
  local session_id="$1"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0

  local _LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true

  local _COUNT_FILE="${_LOG_DIR}/.agent-fire-count-${session_id}"
  local _LASTTS_FILE="${_LOG_DIR}/.agent-fire-lastts-${session_id}"
  local _FENCE_FILE="${_LOG_DIR}/.sequential-fire-warned-${session_id}"

  # 現在 timestamp (nanosec)
  local _NOW_NS
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    # bash 5.0+ builtin: fork 0、形式 "1234567890.123456" → ns 9桁 padding
    _NOW_NS="${EPOCHREALTIME/./}000"
  else
    _NOW_NS=$(date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)")
  fi

  # 直前 fire timestamp 取得
  local _LAST_NS=0
  [[ -f "$_LASTTS_FILE" ]] && read -r _LAST_NS < "$_LASTTS_FILE" 2>/dev/null || _LAST_NS=0
  # 数値チェック (破損対策)
  [[ "$_LAST_NS" =~ ^[0-9]+$ ]] || _LAST_NS=0

  # timestamp を更新
  printf '%s\n' "$_NOW_NS" > "$_LASTTS_FILE" 2>/dev/null || true

  # 経過時間 (ns)
  local _ELAPSED=$(( _NOW_NS - _LAST_NS ))

  # 500ms 以内 → 同一 message 内並列発火と推定 → counter リセット
  local _PARALLEL_THRESHOLD_NS=$_TH_PARALLEL_WINDOW_NS
  if (( _LAST_NS > 0 && _ELAPSED <= _PARALLEL_THRESHOLD_NS )); then
    # 並列発火検出: counter リセット (fence は維持)
    printf '0\n' > "$_COUNT_FILE" 2>/dev/null || true
    return 0
  fi

  # fence 通過済み → 新 sequence でも再 warn しない
  [[ -f "$_FENCE_FILE" ]] && return 0

  # counter インクリメント
  local _CUR=0
  [[ -f "$_COUNT_FILE" ]] && read -r _CUR < "$_COUNT_FILE" 2>/dev/null || _CUR=0
  [[ "$_CUR" =~ ^[0-9]+$ ]] || _CUR=0
  _CUR=$(( _CUR + 1 ))
  printf '%s\n' "$_CUR" > "$_COUNT_FILE" 2>/dev/null || true

  # threshold 判定 (>= _TH_PARALLEL_SEQ、speed-bias)
  if (( _CUR >= _TH_PARALLEL_SEQ )); then
    touch "$_FENCE_FILE" 2>/dev/null || true

    # ログ追記
    local _TS_LABEL
    printf -v _TS_LABEL '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s | %s | counter=%s | elapsed_ms=%s\n' \
      "$_TS_LABEL" "$session_id" "$_CUR" "$(( _ELAPSED / 1000000 ))" \
      >> "${_LOG_DIR}/sequential-fire-warn.log" 2>/dev/null || true

    local _SUGGEST="[parallel-fire-suggest] last ${_CUR} Agent fires sequential (peak=1). 次の発火は 1 message 内 N tool_use 並列必須。independent task ≥2 なら 100% 並列、迷ったら並列側 (CLAUDE.md Auto-Delegation default=並列)"
    if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_SUGGEST}"
    else
      ADDITIONAL_CONTEXT="${_SUGGEST}"
    fi
  fi
}

# ====================================
# 同 session 内で直近 5 回連続 Write/Edit/MultiEdit が large-repo src に hit した場合に
# developer-agent 委譲を促す additionalContext を注入する
# counter: ~/.claude/logs/.large-repo-edit-count-<session_id>
# 重複抑制: ~/.claude/logs/.delegation-warned-<session_id> (1 threshold につき 1 回)
# ====================================
_check_large_repo_consecutive_edit() {
  local session_id="$1"
  local file_path="$2"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0
  [[ -z "$file_path" ]] && return 0

  local _LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true
  local _COUNT_FILE="${_LOG_DIR}/.large-repo-edit-count-${session_id}"
  local _WARN_FILE="${_LOG_DIR}/.delegation-warned-${session_id}"

  # large-repo src pattern 判定
  # 対象: 明示 prefix に絞る (~/ghq/github.com/ 全体は OSS clone を巻き込むため削除)
  # ai-tools 自身も対象 (speed-bias: parent inline edit が Opus 比率悪化の主因)
  # hook source は allowlist 対象のため social-hit term literal 記載可 (rules/public-repo-private-data-block.md)
  local _IS_LARGE_REPO=0
  case "$file_path" in
    "${HOME}"/ghq/github.com/snkrdunk/* | \
    "${HOME}"/ghq/github.com/snkrdunk-loadtest/* | \
    "${HOME}"/ghq/github.com/snkrdunk-terraform/* | \
    "${HOME}"/ghq/github.com/DaichiHoshina/ai-tools/* | \
    "${HOME}"/ai-tools/*)
      _IS_LARGE_REPO=1 ;;
    *)
      _IS_LARGE_REPO=0 ;;
  esac

  # src 拡張子チェック (ai-tools の hook/skill/command/agent/rule は .sh/.md)
  local _IS_SRC=0
  case "$file_path" in
    *.go|*.ts|*.tsx|*.py|*.dart|*.tf|*.sh|*.md) _IS_SRC=1 ;;
  esac

  if [[ "$_IS_LARGE_REPO" -eq 1 && "$_IS_SRC" -eq 1 ]]; then
    # hit: counter をインクリメント
    local _CUR=0
    [[ -f "$_COUNT_FILE" ]] && read -r _CUR < "$_COUNT_FILE" 2>/dev/null || _CUR=0
    _CUR=$(( _CUR + 1 ))
    printf '%s\n' "$_CUR" > "$_COUNT_FILE" 2>/dev/null || true

    # threshold 判定 (>= _TH_DELEGATE_SEQ、speed-bias)
    if (( _CUR >= _TH_DELEGATE_SEQ )) && [[ ! -f "$_WARN_FILE" ]]; then
      touch "$_WARN_FILE" 2>/dev/null || true
      local _SUGGEST="[delegation-suggest] last ${_CUR} inline edits 検出。次の edit-class op は developer-agent 委譲 default (CLAUDE.md \"2 consecutive inline exceptions → mandatory delegation\" 違反リスク)"
      if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_SUGGEST}"
      else
        ADDITIONAL_CONTEXT="${_SUGGEST}"
      fi
    fi
  else
    # non-large-repo hit: counter をリセット
    printf '0\n' > "$_COUNT_FILE" 2>/dev/null || true
  fi
}

# ====================================
# worktree session 内 main repo 直接 Edit guard
# worktree session (CWD が **/.claude/worktrees/* 配下) で file_path が
# worktree 外を指す Edit/Write/NotebookEdit を exit 2 でブロックする
# ====================================
_check_worktree_cwd_guard() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return 0

  # CWD 取得: CLAUDE_PROJECT_DIR 優先、なければ pwd
  local cwd="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$cwd" ]]; then
    cwd=$(pwd 2>/dev/null || true)
  fi
  [[ -z "$cwd" ]] && return 0

  # worktree session 判定: CWD が /.claude/worktrees/ 配下か
  # パターン: */.claude/worktrees/<name> or */.claude/worktrees/<name>/<subdir>
  if [[ "$cwd" != */.claude/worktrees/* ]]; then
    # worktree 外 session → guard 不要
    return 0
  fi

  # worktree root を抽出: /.claude/worktrees/<name> までのパス
  # bash パターン展開で最短 prefix match
  local wt_root="${cwd%%/.claude/worktrees/*}/.claude/worktrees/"
  # worktrees/<name> の name 部分を取得
  local after_wt="${cwd#*/.claude/worktrees/}"
  local wt_name="${after_wt%%/*}"
  wt_root="${wt_root}${wt_name}"

  # file_path が worktree root 配下かチェック
  # 正規化: 末尾スラッシュ除去して前方一致
  local norm_wt="${wt_root%/}"
  local norm_fp="${file_path%/}"

  if [[ "$norm_fp" == "$norm_wt" || "$norm_fp" == "$norm_wt/"* ]]; then
    # worktree 内 path → OK
    return 0
  fi

  # worktree 外 path → block
  GUARD_CLASS="Forbidden"
  MESSAGE="${ICON_CRITICAL} [cwd-guard] worktree session 中の main repo 直接 Edit を block"
  ADDITIONAL_CONTEXT="worktree 内 path を指定するか、ExitWorktree してから再実行する。worktree root: ${wt_root} / 指定 path: ${file_path}"
}

# ====================================
# 今日の commit inject
# 書く系 tool (Write/Edit/Bash commit・gh・glab・Slack/Notion MCP) の直前に
# 今日の commit log を additionalContext に append して、最新規範の反映を促す
# session 重複抑制: /tmp/claude-today-commits-<SESSION_KEY>-<YYYYMMDD> に記録済フラグ
# ====================================
_inject_today_commits() {
  local _inject_log_dir="$HOME/.claude/logs"
  local _inject_log_file="${_inject_log_dir}/today-commit-inject.log"

  # session 重複抑制: stdin .session_id ベース (CLAUDE_CODE_SESSION_ID env 優先)
  # session_id が取得できた場合はそれを使用 (session 単位で確実に重複抑制)
  # 取得できない場合は $$ fallback (毎 hook 起動別PIDで重複抑制は機能しないが inject 自体は行う)
  local _session_key="${SESSION_ID:-$$}"
  local _today; printf -v _today '%(%Y%m%d)T' -1
  local _flag_file="/tmp/claude-today-commits-${_session_key}-${_today}"
  if [[ -f "$_flag_file" ]]; then
    return 0
  fi

  # cap: 行数上限 (env override 可)
  local _line_cap="${CLAUDE_HOOK_INJECT_CAP:-30}"
  # cap: commit 数上限 (env override 可)
  local _commit_cap="${CLAUDE_HOOK_INJECT_COMMIT_CAP:-5}"

  # git log: CLAUDE_PROJECT_DIR 優先、なければ HOME
  local _project_dir="${CLAUDE_PROJECT_DIR:-$HOME}"

  # Source 1: 作業中 repo の今日の commit
  local _proj_commits=""
  _proj_commits=$(git -C "$_project_dir" log --since="midnight" --pretty=format:'%h %s' --no-merges 2>/dev/null | head -n "${_commit_cap}" || true)
  if [[ -z "$_proj_commits" ]] && ! git -C "$_project_dir" rev-parse --git-dir >/dev/null 2>&1; then
    mkdir -p "$_inject_log_dir" 2>/dev/null || true
    printf '[%s] today-commit inject: git log failed at %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_project_dir" >> "$_inject_log_file" 2>/dev/null || true
  fi

  # Source 2: ai-tools writing 規約関連 commit (guidelines/ と CLAUDE.md 限定)
  # _project_dir が ~/ai-tools の時は重複しないよう skip
  local _aitools_repo_dir
  _aitools_repo_dir="$(_aitools_dir)"
  local _writing_commits=""
  local _aitools_real
  _aitools_real=$(cd "$_aitools_repo_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  local _project_real
  _project_real=$(cd "$_project_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  if [[ -n "$_aitools_real" && "$_aitools_real" != "$_project_real" ]]; then
    _writing_commits=$(git -C "$_aitools_repo_dir" log --since="midnight" --pretty=format:'%h %s' --no-merges \
      -- "claude-code/guidelines/" "claude-code/CLAUDE.md" 2>/dev/null | head -n "${_commit_cap}" || true)
    if [[ -z "$_writing_commits" ]] && ! git -C "$_aitools_repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
      mkdir -p "$_inject_log_dir" 2>/dev/null || true
      printf '[%s] today-commit inject: git log failed at %s (writing path)\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_aitools_repo_dir" >> "$_inject_log_file" 2>/dev/null || true
    fi
  fi

  # 両方 0 件 → silent skip (フラグも書かない)
  if [[ -z "$_proj_commits" && -z "$_writing_commits" ]]; then
    return 0
  fi

  # フラグ書き込み (以降は重複 inject しない)
  touch "$_flag_file" 2>/dev/null || true

  local _msg=""

  if [[ -n "$_proj_commits" ]]; then
    _msg="今日の commit: ${_proj_commits}"$'\n'"writing 規約 / guidelines / CLAUDE.md 更新が含まれる場合、出力前に当該 file を read して最新規範を反映すること。"
  fi

  if [[ -n "$_writing_commits" ]]; then
    local _writing_msg="writing 規約 (~/ai-tools) の今日更新: ${_writing_commits}"$'\n'"これらを read してから書く。"
    if [[ -n "$_msg" ]]; then
      _msg="${_msg}"$'\n'"${_writing_msg}"
    else
      _msg="${_writing_msg}"
    fi
  fi

  # 行数 cap 適用: _line_cap を超える場合は truncate して末尾に通知行を追加
  local _total_lines
  _total_lines=$(printf '%s\n' "${_msg}" | wc -l | tr -d ' ')
  if [[ "${_total_lines}" -gt "${_line_cap}" ]]; then
    local _truncated_lines=$(( _total_lines - _line_cap ))
    _msg=$(printf '%s\n' "${_msg}" | head -n "${_line_cap}")
    _msg="${_msg}"$'\n'"... (${_truncated_lines} more lines truncated)"
  fi

  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_msg}"
  else
    ADDITIONAL_CONTEXT="${_msg}"
  fi
}

# commit/PR 起草前に NG-DICTIONARY の block 系 term を ADDITIONAL_CONTEXT で事前 inject する
# 目的: 起草段階でNG語を使わせず、block→retry ループを防ぐ (事後型 _inject_principles_on_commit と併存)
# trigger: git commit / gh pr create / gh pr edit / gh pr review / gh issue create / glab 系コマンド
# 重複抑制: SESSION_ID ベースの flag file で 1 session 1 回のみ inject
_inject_ng_dict_on_commit_compose() {
  local _session_key="${SESSION_ID:-$$}"
  local _today; printf -v _today '%(%Y%m%d)T' -1
  local _flag_file="/tmp/claude-ng-inject-${_session_key}-${_today}"
  if [[ -f "$_flag_file" ]]; then
    return 0
  fi

  local _ng_dict_file="${HOME}/.claude/guidelines/writing/NG-DICTIONARY.md"
  local _word_replace_file="${HOME}/.claude/guidelines/writing/PRINCIPLES-word-replace.md"

  # NG-DICTIONARY.md が存在しない場合は silent skip
  if [[ ! -f "$_ng_dict_file" ]]; then
    return 0
  fi

  # block 系 term を動的抽出: "(block)" を含む行から term list を取得
  # 形式: **<name> (block)**: term1 / term2 / ...
  local _block_terms=""
  while IFS= read -r _line; do
    if [[ "$_line" =~ \(block\) ]]; then
      # "**: " 以降を term list として取得
      local _terms_part="${_line#*\*\*: }"
      if [[ -n "$_terms_part" && "$_terms_part" != "$_line" ]]; then
        if [[ -n "$_block_terms" ]]; then
          _block_terms="${_block_terms} / ${_terms_part}"
        else
          _block_terms="${_terms_part}"
        fi
      fi
    fi
  done < "$_ng_dict_file"

  # 1 件も取れなければ silent skip
  if [[ -z "$_block_terms" ]]; then
    return 0
  fi

  # flag 書き込み (以降は重複 inject しない)
  touch "$_flag_file" 2>/dev/null || true

  # 置換ヒント: PRINCIPLES-word-replace.md があれば非日常英語の主要置換表を付加
  local _replace_hint=""
  if [[ -f "$_word_replace_file" ]]; then
    # leverage/utilize/mitigate 等の代表的な非日常英語置換行を抽出 (最大 5 行)
    _replace_hint=$(grep -E 'leverage|utilize|mitigate|facilitate|comprehensive' "$_word_replace_file" 2>/dev/null | head -5 | sed 's/^/  /' || true)
  fi

  local _inject_msg="【起草前 NG 語回避】以下の用語を commit message / PR 本文に使わないでください。source: guidelines/writing/NG-DICTIONARY.md
block_terms: ${_block_terms}"
  if [[ -n "$_replace_hint" ]]; then
    _inject_msg="${_inject_msg}
置換例 (非日常英語 → 平易な日本語):
${_replace_hint}
詳細: guidelines/writing/PRINCIPLES-word-replace.md"
  fi

  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_inject_msg}"
  else
    ADDITIONAL_CONTEXT="${_inject_msg}"
  fi
}

# ====================================
# protection-mode 3層分類判定
# ====================================

# session split warn: 任意 tool 呼出し前に 1 session 1 回だけ注入 (warn-only)
_CWD_FOR_SPLIT=$(jq -r '.cwd // empty' <<< "$INPUT")
_check_session_split "$SESSION_ID" "$_CWD_FOR_SPLIT"

case "$TOOL_NAME" in
  # === 安全操作（即実行可能） ===
  "Read")
    GUARD_CLASS="Safe"
    # ディレクトリ判定: EISDIR を事前ブロックして Glob/ls へ誘導
    READ_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    if [ -n "$READ_PATH" ] && [ -d "$READ_PATH" ]; then
      _DENY_REASON="Read対象がディレクトリ: ${READ_PATH} → Glob (pattern=\"${READ_PATH}/**/*\") または Bash (ls -la \"${READ_PATH}\") を使うこと"
      jq -n --arg reason "$_DENY_REASON" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
      exit 0
    fi
    ;;

  "Glob"|"Grep"|"WebFetch"|"WebSearch"|"ListMcpResourcesTool"|"ReadMcpResourceTool")
    GUARD_CLASS="Safe"
    # 安全操作はメッセージなし（トークン節約）
    ;;

  "mcp__serena__read_file"|"mcp__serena__list_dir"|"mcp__serena__find_file"|"mcp__serena__search_for_pattern"|"mcp__serena__get_symbols_overview"|"mcp__serena__find_symbol"|"mcp__serena__find_referencing_symbols"|"mcp__serena__list_memories"|"mcp__serena__read_memory"|"mcp__serena__get_current_config"|"mcp__serena__think_about_collected_information"|"mcp__serena__think_about_task_adherence"|"mcp__serena__think_about_whether_you_are_done")
    GUARD_CLASS="Safe"
    ;;

  "mcp__jira__jira_get"|"mcp__confluence__conf_get"|"mcp__context7__resolve-library-id"|"mcp__context7__query-docs")
    GUARD_CLASS="Safe"
    ;;

  # === 要確認操作（要確認・警告） ===
  "Edit"|"Write"|"MultiEdit"|"NotebookEdit")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: ファイル編集"

    # worktree session 内 main repo 直接 Edit guard
    # MultiEdit は top-level file_path に加え edits[].file_path も持つため両方検査する
    while IFS= read -r _CWD_GUARD_PATH; do
      [[ -z "$_CWD_GUARD_PATH" ]] && continue
      _check_worktree_cwd_guard "$_CWD_GUARD_PATH"
      [[ "$GUARD_CLASS" == "Forbidden" ]] && break
    done < <(jq -r '[.tool_input.file_path, (.tool_input.edits[]?.file_path)] | .[] | select(. != null and . != "")' <<< "$INPUT")
    # Forbidden が立った場合は以降の処理をスキップ
    if [[ "$GUARD_CLASS" == "Forbidden" ]]; then
      :
    else

    # jq 集約: Write/Edit で必要な 4 フィールドを 1 回取得 (fork 削減)
    IFS=$'\t' read -r _EDIT_FILE_PATH EDIT_CONTENT _OLD_STRING _NEW_STRING < <(
      extract_json_fields "$INPUT" \
        '.tool_input.file_path // ""' \
        'if .tool_input.content then .tool_input.content elif .tool_input.new_string then .tool_input.new_string elif .tool_input.edits then [.tool_input.edits[].new_string] | join("\n") else "" end' \
        '.tool_input.old_string // ""' \
        '.tool_input.new_string // ""'
    )

    # large-repo 連続 Edit 委譲 signal (warn-only)
    _check_large_repo_consecutive_edit "$SESSION_ID" "$_EDIT_FILE_PATH"

    # 直編集ガード: ~/.claude/{synced_dir}/... で repo source 存在時に redirect 推奨
    # sync.sh to-local で上書き消失するため、必ず repo source を編集する規約
    _EDIT_PATH="$_EDIT_FILE_PATH"
    if [ -n "$_EDIT_PATH" ] && [[ "$_EDIT_PATH" == "$HOME/.claude/"* ]]; then
      _REL_PATH="${_EDIT_PATH#"$HOME/.claude/"}"
      _FIRST_COMP="${_REL_PATH%%/*}"
      case "$_FIRST_COMP" in
        commands|skills|hooks|agents|rules|guidelines|config|references|CLAUDE.md)
          _REPO_PATH="$(_aitools_dir)/claude-code/$_REL_PATH"
          if [ -f "$_REPO_PATH" ]; then
            _DIRECT_EDIT_WARN="⚠ 直編集警告: ${_EDIT_PATH} は sync.sh to-local で上書き消失します。代わりに repo source ${_REPO_PATH} を編集してください。"
            if [ -n "$ADDITIONAL_CONTEXT" ]; then
              ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DIRECT_EDIT_WARN}"
            else
              ADDITIONAL_CONTEXT="${_DIRECT_EDIT_WARN}"
            fi
          fi
          ;;
      esac
    fi

    # 危険パターン検出（機密リテラル/SSRF/SQL injection）
    if [ -n "$EDIT_CONTENT" ]; then
      detect_dangerous_patterns "$EDIT_CONTENT"
    fi

    # social-hit block: ai-tools public repo への社内 product 名書き込み防止
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      if [ -n "$_EDIT_FILE_PATH" ]; then
        _check_social_hit "$_EDIT_FILE_PATH" "$EDIT_CONTENT"
      fi
    fi

    # private-name block: private-name-list.txt の term を ai-tools 配下 file 書込に適用
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      _PN_PATH="$_EDIT_FILE_PATH"
      if _is_aitools_path "$_PN_PATH"; then
        # 自己除外: rule 説明文として term を保持する file は判定対象外
        _PN_REL=$(_aitools_relpath "$_PN_PATH")
        case "$_PN_REL" in
          claude-code/rules/public-repo-private-data-block.md|\
          claude-code/CLAUDE.md|\
          claude-code/hooks/pre-tool-use.sh|\
          claude-code/tests/unit/hooks/pre-tool-use.bats)
            : ;;  # skip
          *)
            _check_private_name "$_PN_PATH" "$EDIT_CONTENT"
            ;;
        esac
      fi
    fi

    # AI定型語 block: 作業 repo の .md / .txt への書き込みを検査
    # ai-tools 配下は除外 (guidelines / NG-DICTIONARY など NG 語を literal 保持する設定 md の誤爆防止)
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      _AJ_EXT="${_EDIT_FILE_PATH##*.}"
      if [[ "$_AJ_EXT" == "md" || "$_AJ_EXT" == "txt" ]]; then
        if ! _is_aitools_path "$_EDIT_FILE_PATH"; then
          _AJ_BASENAME=$(basename "${_EDIT_FILE_PATH:-file}")
          _block_if_ai_jargon "$EDIT_CONTENT" "ファイル: ${_AJ_BASENAME}"
        fi
      fi
    fi

    # Rename propagation detection (Edit tool only has old_string/new_string)
    if [ -n "$_OLD_STRING" ] && [ -n "$_NEW_STRING" ]; then
      detect_rename_propagation "$_OLD_STRING" "$_NEW_STRING" "$_EDIT_FILE_PATH"
    fi

    # Sonnet delegation declaration grep (CLAUDE.md Auto-Delegation "Edit/Write declaration rule")
    # fetch last 30 lines of latest assistant message from transcript_path; check for "Inline exception" / "Inline prohibited"
    # session+transcript mtime キャッシュ: transcript 更新がない場合は python3 fork を skip
    _TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$INPUT")
    if [ -n "$_TRANSCRIPT" ] && [ -f "$_TRANSCRIPT" ]; then
      _TRANSCRIPT_MTIME=$(stat -c '%Y' "$_TRANSCRIPT" 2>/dev/null || stat -f '%m' "$_TRANSCRIPT" 2>/dev/null || echo "0")
      _TRANSCRIPT_CACHE_FLAG="/tmp/claude-transcript-decl-${SESSION_ID:-$$}-${_TRANSCRIPT_MTIME}"
      if [[ -f "$_TRANSCRIPT_CACHE_FLAG" ]]; then
        _DECL_FOUND=$(cat "$_TRANSCRIPT_CACHE_FLAG" 2>/dev/null || true)
      else
        # 古いキャッシュ (同セッション・異なる mtime) を削除してから scan
        rm -f "/tmp/claude-transcript-decl-${SESSION_ID:-$$}"-* 2>/dev/null || true
        _DECL_FOUND=$(python3 - "$_TRANSCRIPT" <<'PYEOF'
import sys, json
path = sys.argv[1]
lines = []
try:
    with open(path, encoding='utf-8') as f:
        lines = f.readlines()
except Exception:
    sys.exit(0)
# scan from the end to find the latest assistant entry and extract its text
for raw in reversed(lines):
    raw = raw.strip()
    if not raw:
        continue
    try:
        d = json.loads(raw)
    except Exception:
        continue
    if d.get('type') != 'assistant':
        continue
    content = d.get('message', {}).get('content', [])
    text = ''
    for c in content:
        if isinstance(c, dict) and c.get('type') == 'text':
            text = c.get('text', '')
            break
    if not text:
        continue
    tail = '\n'.join(text.splitlines()[-30:])
    if 'Inline exception' in tail or 'Inline prohibited' in tail:
        print('found')
    sys.exit(0)
PYEOF
        )
        # scan 結果を mtime キャッシュとして保存
        printf '%s' "${_DECL_FOUND:-}" > "$_TRANSCRIPT_CACHE_FLAG" 2>/dev/null || true
      fi  # end: cache hit / miss
      if [ "$_DECL_FOUND" != "found" ]; then
        _DECL_WARN="⚠ Sonnet 委譲宣言抜け: Edit/Write 前に 'Inline exception (reason: ...)' か 'Inline prohibited (reason: ...)' を 1 行宣言 (throttle 等詳細: references/auto-delegation-detailed.md)"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DECL_WARN}"
        else
          ADDITIONAL_CONTEXT="${_DECL_WARN}"
        fi
      fi
    fi

    # 書く系 tool: 今日の commit inject（writing 規約更新を最新規範で反映させる）
    _inject_today_commits
    fi  # end: cwd-guard Forbidden skip
    ;;

  "Bash")
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
    classify_bash_command "$COMMAND"

    # AI定型語チェック: git commit / gh / glab の外向き text を抽出して block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      # single-quote 系 regex は変数経由で渡す (shell quoting による capture 空 bug 回避)
      _re_m_sq="-m[[:space:]]+\'([^\']*)\'"
      _re_body_sq="--body[[:space:]]+\'([^\']*)\'"
      _re_title_sq="--title[[:space:]]+\'([^\']*)\'"
      _re_notes_sq="--notes[[:space:]]+\'([^\']*)\'"
      _re_desc_sq="--description[[:space:]]+\'([^\']*)\'"

      # --- git commit: -m オプション値を抽出 (commit-tree / commit-graph は除外) ---
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
        _commit_msg=""
        # -m / --message "..." 形式 (space / = 区切り、long form を含む)
        if [[ "$COMMAND" =~ $_re_m_sq ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --message[[:space:]=]\'([^\']*)\' ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --message[[:space:]=]\"([^\"]*)\" ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m=\'([^\']*)\' ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m=\"([^\"]*)\" ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        fi
        [[ -n "$_commit_msg" ]] && _block_if_ai_jargon "$_commit_msg" "commit message"

        # -F / --file <file> 形式: ファイル内容を読んで block
        if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
          _commit_file_path=""
          _re_F_sq="-F[[:space:]]+\'([^\']*)\'"
          _re_file_sq="--file[[:space:]]+\'([^\']*)\'"
          if [[ "$COMMAND" =~ $_re_F_sq ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ -F[[:space:]]\"([^\"]*)\" ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ -F[[:space:]]+([^[:space:]\'\"]+) ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ $_re_file_sq ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --file[[:space:]]\"([^\"]*)\" ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --file[[:space:]]+([^[:space:]\'\"]+) ]]; then
            _commit_file_path="${BASH_REMATCH[1]}"
          fi
          if [[ -n "$_commit_file_path" ]]; then
            # 相対パスは cwd 起点で解決
            if [[ "$_commit_file_path" != /* ]]; then
              _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
              [[ -n "$_cwd" ]] && _commit_file_path="${_cwd}/${_commit_file_path}"
            fi
            if [[ -f "$_commit_file_path" ]]; then
              _commit_file_content=$(cat "$_commit_file_path" 2>/dev/null || true)
              [[ -n "$_commit_file_content" ]] && _block_if_ai_jargon "$_commit_file_content" "commit message (file)"
            fi
          fi
        fi

        # --amend で inline body オプション (-m/--message/-F/--file) が無い場合:
        # editor 編集で hook は本文取得不可 → warn-only。
        # substring 判定だと --message が -m に誤マッチして warn を抑止するため word-boundary で判定する。
        if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ --amend ]] && \
           ! [[ "$COMMAND" =~ (^|[[:space:]])(-m|-F|--message|--file)([[:space:]=]|$) ]]; then
          _amend_warn="⚠ --amend で editor 編集する本文も NG 語を避けてください (hook は本文を検査できません)"
          if [ -n "$ADDITIONAL_CONTEXT" ]; then
            ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_amend_warn}"
          else
            ADDITIONAL_CONTEXT="${_amend_warn}"
          fi
        fi
      fi

      # --- gh pr create / gh pr edit / gh pr review / gh pr merge / gh issue create / gh issue comment ---
      # --- gh release create ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && { \
          [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] || \
          [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; }; then
        _gh_text=""
        # --body "..." or --body '...'
        if [[ "$COMMAND" =~ $_re_body_sq ]]; then
          _gh_text="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --body[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${BASH_REMATCH[1]}"
        fi
        # --title "..." or --title '...' (append to check text)
        if [[ "$COMMAND" =~ $_re_title_sq ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        fi
        # --notes "..." or --notes '...' (gh release create)
        if [[ "$COMMAND" =~ $_re_notes_sq ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --notes[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        fi
        # --body-file <file> / --body-file="<file>": ファイル内容を読んで body に追加
        _re_body_file_sq="--body-file[[:space:]]+\'([^\']*)\'"
        _gh_body_file_path=""
        if [[ "$COMMAND" =~ $_re_body_file_sq ]]; then
          _gh_body_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --body-file[[:space:]]\"([^\"]*)\" ]]; then
          _gh_body_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --body-file[[:space:]]+([^[:space:]\'\"]+) ]]; then
          _gh_body_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --body-file=([^[:space:]\'\"]+) ]]; then
          _gh_body_file_path="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_gh_body_file_path" ]]; then
          if [[ "$_gh_body_file_path" != /* ]]; then
            _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
            [[ -n "$_cwd" ]] && _gh_body_file_path="${_cwd}/${_gh_body_file_path}"
          fi
          if [[ -f "$_gh_body_file_path" ]]; then
            _gh_file_content=$(cat "$_gh_body_file_path" 2>/dev/null || true)
            [[ -n "$_gh_file_content" ]] && _gh_text="${_gh_text}"$'\n'"${_gh_file_content}"
          fi
        fi
        if [[ -n "$_gh_text" ]]; then
          _gh_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
          _block_if_ai_jargon "$_gh_text" "${_gh_subcmd:-gh}"
        fi
      fi

      # --- glab mr create / glab issue create / glab mr note ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
        _glab_text=""
        if [[ "$COMMAND" =~ $_re_desc_sq ]]; then
          _glab_text="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --description[[:space:]]\"([^\"]*)\" ]]; then
          _glab_text="${BASH_REMATCH[1]}"
        fi
        if [[ "$COMMAND" =~ $_re_title_sq ]]; then
          _glab_text="${_glab_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
          _glab_text="${_glab_text} ${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_glab_text" ]]; then
          _glab_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
          _block_if_ai_jargon "$_glab_text" "${_glab_subcmd:-glab}"
        fi
      fi

      # private-name block: git commit / gh / glab コマンドの外向き text を private-name-list.txt でチェック
      if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
        _pn_cmd_text=""
        _pn_cmd_label=""
        # git commit -m
        if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
          if [[ "$COMMAND" =~ $_re_m_sq ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          fi
          _pn_cmd_label="commit message"
        fi
        # gh pr / issue / release
        if [[ -z "$_pn_cmd_label" ]] && { \
            [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] || \
            [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; }; then
          if [[ "$COMMAND" =~ $_re_body_sq ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --body[[:space:]]\"([^\"]*)\" ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          fi
          if [[ "$COMMAND" =~ $_re_title_sq ]]; then
            _pn_cmd_text="${_pn_cmd_text} ${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
            _pn_cmd_text="${_pn_cmd_text} ${BASH_REMATCH[1]}"
          fi
          _pn_cmd_label=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
        fi
        # glab
        if [[ -z "$_pn_cmd_label" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
          if [[ "$COMMAND" =~ $_re_desc_sq ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --description[[:space:]]\"([^\"]*)\" ]]; then
            _pn_cmd_text="${BASH_REMATCH[1]}"
          fi
          if [[ "$COMMAND" =~ $_re_title_sq ]]; then
            _pn_cmd_text="${_pn_cmd_text} ${BASH_REMATCH[1]}"
          elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
            _pn_cmd_text="${_pn_cmd_text} ${BASH_REMATCH[1]}"
          fi
          _pn_cmd_label=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
        fi
        if [[ -n "$_pn_cmd_text" && -n "$_pn_cmd_label" ]]; then
          _check_social_hit_in_text "${_pn_cmd_label}" "$_pn_cmd_text"
          [[ "$GUARD_CLASS" == "Forbidden" ]] || _check_private_name "${_pn_cmd_label}" "$_pn_cmd_text"
        fi
      fi
    fi

    # Serena substitution hint: notify Claude when Bash code-file read is detected
    # structurally prevents Bash ratio 51% (analytics) violating CLAUDE.md "Tool selection" principle
    if [ "$GUARD_CLASS" != "Forbidden" ] && _is_serena_replaceable "$COMMAND"; then
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}; 🔍 Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      else
        ADDITIONAL_CONTEXT="🔍 Bash でコードファイル参照検出、Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      fi
    fi

    # 書く系 Bash コマンド: 起草前 NG-DICTIONARY inject + 今日の commit inject
    # 対象: git commit / gh pr|issue|release / glab mr|issue|release
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]] \
         || [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] \
         || [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]] \
         || [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]] \
         || [[ "$COMMAND" =~ glab[[:space:]]+release[[:space:]]+create ]]; then
        _inject_ng_dict_on_commit_compose
        _inject_today_commits
      fi
    fi
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command"|"mcp__serena__rename_symbol")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Serena変更操作"
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Jira/Confluence変更"
    ;;

  "mcp__claude_ai_Notion__notion-create-pages"|"mcp__claude_ai_Notion__notion-update-page"|"mcp__claude_ai_Notion__notion-create-comment"|"mcp__claude_ai_Notion__notion-create-database" \
  |"mcp__claude_ai_Slack__slack_send_message"|"mcp__claude_ai_Slack__slack_schedule_message"|"mcp__claude_ai_Slack__slack_create_canvas"|"mcp__claude_ai_Slack__slack_update_canvas")
    # 対象: 文章を外向きに送信・投稿・作成する MCP
    # 除外 (構造操作で文章を書かない):
    #   notion-duplicate-page / notion-move-pages / notion-update-view / notion-update-data-source
    #   slack_add_reaction
    GUARD_CLASS="Safe"
    ADDITIONAL_CONTEXT="📝 投稿前自問5点: ①「で、つまり何？」と思わせないか ②初見が途中で止まらないか ③各段落の役割（背景/理由/具体例/結論/注意点）明確か ④抽象名詞の羅列で段落が終わってないか ⑤bullet 5連続+地の文0の金太郎飴か。詳細: claude-code/guidelines/writing/PRINCIPLES.md"

    # AI定型語チェック: text / content param + nested field を全連結して block
    # Notion children: paragraph/heading/bulleted_list_item/numbered_list_item の rich_text[].text.content
    # Slack blocks: blocks[].text.text
    _mcp_text=$(jq -r '
      [
        (.tool_input.text // empty),
        (.tool_input.content // empty),
        (.tool_input.children[]?
          | (.paragraph?.rich_text[]?.text?.content // empty),
            (.heading_1?.rich_text[]?.text?.content // empty),
            (.heading_2?.rich_text[]?.text?.content // empty),
            (.heading_3?.rich_text[]?.text?.content // empty),
            (.bulleted_list_item?.rich_text[]?.text?.content // empty),
            (.numbered_list_item?.rich_text[]?.text?.content // empty),
            (.quote?.rich_text[]?.text?.content // empty),
            (.callout?.rich_text[]?.text?.content // empty),
            (.toggle?.rich_text[]?.text?.content // empty)
        ),
        (.tool_input.blocks[]?.text?.text // empty)
      ] | map(select(. != null and . != "")) | join("\n")
    ' <<< "$INPUT")
    if [[ -n "$_mcp_text" ]]; then
      _block_if_ai_jargon "$_mcp_text" "$TOOL_NAME"
    fi

    # 書く系 MCP: 今日の commit inject
    _inject_today_commits
    ;;

  "Task")
    GUARD_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    # ただし general-purpose は CLAUDE.md「原則使わない」最大コスト源 → Boundary 警告
    SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT")

    # 並列判定 self-review (全 Task 発火時に inject)
    PARALLEL_REVIEW=$'【並列 self-review (強制 echo、default=並列/委譲)】\n0. default: 並列発火 + Sonnet 委譲。単発・inline 選択時は「なぜ並列/委譲しないか」を 1 行 echo。迷ったら並列・委譲側\n1. Manager 経由は formula_trace、直接 Task は judgment 行を echo (書式: references/PARALLEL-PATTERNS.md)\n2. 独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1)\n3. echo 抜けは under-parallel risk'

    # parent 事前準備 missing 検出 (warn-only、block しない)
    TASK_PROMPT=$(jq -r '.tool_input.prompt // empty' <<< "$INPUT")
    PREP_WARN=""
    if _check_parent_prep_missing "$TASK_PROMPT"; then
      PREP_WARN="
【parent 事前準備 missing 疑い】≥500 word の prompt に target / file:line / verify / DoD いずれも未出現。委譲前 checklist を充足してから発火 (references/developer-agent-delegation-prompt.md §0)"
    fi
    if _check_colloquial_trigger_missing_delegation "$TASK_PROMPT"; then
      PREP_WARN="${PREP_WARN}
【colloquial 起動検出】口語トリガー (お任せ/全部/改善して 等) + file:line 未明示。inline throttle に注意、複数 task 列挙なら 1 message 内 N tool_use 並列発火を確認"
    fi

    if [ "${SUBAGENT_TYPE}" = "general-purpose" ]; then
      # CLAUDE.md「absolutely banned」最大コスト源 (実測 max 501s) → hard block。
      # GP_BLOCK_OFF=1 で従来の warn 据え置き (hook debug 用 escape hatch)。
      if [ "${GP_BLOCK_OFF:-0}" = "1" ]; then
        GUARD_CLASS="Boundary"
        MESSAGE="${ICON_WARNING} general-purpose agent（CLAUDE.md「原則使わない」、最大コスト源）"
        ADDITIONAL_CONTEXT="代替: claude-code-guide / Explore / 直接 grep+find / serena MCP（references/performance-insights.md 参照）
${PARALLEL_REVIEW}${PREP_WARN}"
      else
        GUARD_CLASS="Forbidden"
        MESSAGE="${ICON_CRITICAL} general-purpose agent は禁止 (CLAUDE.md、最大コスト源 実測 max 501s)。代替: explore-agent (検索) / claude-code-guide (CLI/SDK) / developer-agent (実装)"
      fi
    else
      ADDITIONAL_CONTEXT="${PARALLEL_REVIEW}${PREP_WARN}"
    fi

    # 逐次 Agent fire 検出 (warn-only、既存 ADDITIONAL_CONTEXT に append)
    _check_sequential_agent_fire "$SESSION_ID"
    ;;

  "Skill")
    GUARD_CLASS="Safe"

    # ガイドラインは各スキル内で自動読み込み（additionalContext省略でトークン節約）
    ;;

  "TaskCreate"|"TaskUpdate"|"TaskList"|"TaskGet"|"AskUserQuestion"|"EnterPlanMode"|"ExitPlanMode")
    GUARD_CLASS="Safe"
    ;;

  *)
    # 未知のツールはBoundary扱い
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: 未分類ツール: $TOOL_NAME"
    ;;
esac

# ====================================
# JSON出力（jqで安全にエスケープ）
# ====================================

if [ -n "$ADDITIONAL_CONTEXT" ]; then
  if [ -n "$MESSAGE" ]; then
    jq -n --arg msg "$MESSAGE" --arg ctx "$ADDITIONAL_CONTEXT" \
      '{"systemMessage": $msg, "additionalContext": $ctx}'
  else
    jq -n --arg ctx "$ADDITIONAL_CONTEXT" \
      '{"additionalContext": $ctx}'
  fi
elif [ -n "$MESSAGE" ]; then
  jq -n --arg msg "$MESSAGE" \
    '{"systemMessage": $msg}'
else
  # 安全操作はメッセージなし（トークン節約）
  echo "{}"
fi

# Forbiddenの場合はexit 2でツール実行をブロック（v2.1.90で正常動作）
if [ "$GUARD_CLASS" = "Forbidden" ]; then
  exit 2
fi
