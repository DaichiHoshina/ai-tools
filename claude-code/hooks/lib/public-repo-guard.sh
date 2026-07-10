#!/usr/bin/env bash
# public-repo guard checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_PUBLIC_REPO_GUARD_LOADED:-}" == "1" ]]; then
    return 0
fi
_PUBLIC_REPO_GUARD_LOADED=1

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
    claude-code/CLAUDE.global.md|\
    claude-code/hooks/pre-tool-use.sh|\
    claude-code/hooks/lib/public-repo-guard.sh|\
    claude-code/hooks/lib/agent-guard.sh|\
    claude-code/hooks/lib/write-checkers.sh|\
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
# cwd が ai-tools 配下でない場合は skip する (public repo 保護は ai-tools cwd 限定、
# snkrdunk 等の private repo cwd での gh pr / gh issue 系は自 project の名前を含んで正常)。
_check_social_hit_in_text() {
  local label="$1"
  local text="$2"
  [[ -z "$text" ]] && return 0
  [[ -f "$_social_hit_rule_file" ]] || return 0

  # cwd 判定: ai-tools 配下 cwd のみで発火。それ以外の repo cwd (snkrdunk 等) では skip。
  # pre-tool-use.sh L83 で先に取得済み。fallback は $PWD (hook shell の起動 dir)。
  local _cwd="${_CWD_FOR_SPLIT:-$PWD}"
  if ! _is_aitools_path "$_cwd"; then
    return 0
  fi

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
