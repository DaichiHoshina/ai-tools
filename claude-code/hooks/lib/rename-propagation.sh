#!/usr/bin/env bash
# rename-propagation checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_RENAME_PROPAGATION_LOADED:-}" == "1" ]]; then
    return 0
fi
_RENAME_PROPAGATION_LOADED=1

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

  # skip: generated / lock / vendored path (git grep しても意味がない)
  case "$file_path" in
    */node_modules/*|*/dist/*|*/build/*|*/.git/*)
      return ;;
    *.lock|*/package-lock.json|*/yarn.lock|*/Cargo.lock|*/go.sum|*/poetry.lock)
      return ;;
    *.min.js|*.min.css|*.map|*.png|*.jpg|*.jpeg|*.gif|*.svg|*.ico|*.woff|*.woff2|*.ttf|*.eot)
      return ;;
  esac

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
