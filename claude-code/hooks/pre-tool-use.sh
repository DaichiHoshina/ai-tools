#!/usr/bin/env bash
# PreToolUse Hook - protection-mode 必須チェック
# 3層分類: Safe/Boundary/Forbidden
# v2.2.0対応: jq安全出力、パターン検出強化

set -euo pipefail

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'   # exclamation-circle (critical/forbidden)
ICON_WARNING=$'\u25b2'    # exclamation-triangle (boundary)

# JSON入力を読み込む
INPUT=$(cat)

# ツール名を取得
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")

# protection-mode判定変数
GUARD_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""

# ====================================
# AI定型語 / カタカナ造語 block 関数
# PRINCIPLES.md から動的抽出 → 外向き text に grep → hit で exit 2
# ====================================
_principles_file="$HOME/.claude/guidelines/writing/PRINCIPLES.md"

# block ログ出力関数
# 引数: tool_name, hit_term, block|warn
_append_jp_quality_log() {
  local tool_name="$1"
  local hit_term="$2"
  local action="$3"
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-block.log"
  # mkdir は -p で安全に
  mkdir -p "$log_dir" 2>/dev/null || true
  # ファイルサイズ rotation: 1MB 超えたら mv してから新規
  if [[ -f "$log_file" ]]; then
    local fsize
    fsize=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    if [[ "${fsize}" -gt 1048576 ]]; then
      mv "$log_file" "${log_file}.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
    fi
  fi
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$action" >> "$log_file" 2>/dev/null || true
}

# code block (``` ... ``` および ` ... `) を除去したテキストを返す
_strip_code_blocks() {
  local text="$1"
  # fenced code block (``` ... ```) を除去 (POSIX awk 互換)
  local stripped
  stripped=$(printf '%s' "$text" | awk '
    /^```/ { in_block = !in_block; next }
    !in_block { print }
  ')
  # inline code (` ... `) を除去
  stripped=$(printf '%s' "$stripped" | sed "s/\`[^\`]*\`/ /g")
  printf '%s' "$stripped"
}

# 指定 key の list を PRINCIPLES.md から抽出 (「**<key>**: 語1 / 語2 / ...」行)
_extract_term_list() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  local line
  line=$(grep -m1 "^\*\*${key}\*\*:" "$file" 2>/dev/null || true)
  [[ -z "$line" ]] && return 0
  local body="${line#*: }"
  printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$' || true
}

# AI定型語を PRINCIPLES.md から抽出 (後方互換 wrapper)
_extract_ai_jargon() {
  local file="$1"
  _extract_term_list "$file" "AI定型語"
}

# 外向き text に対して指定 key の list を grep し、hit 語を stdout に出力
# 返り値: hit あり=1, なし=0
_check_term_list() {
  local text="$1"
  local key="$2"
  [[ -z "$text" ]] && return 0
  [[ -f "$_principles_file" ]] || return 0
  # code block を除去してからチェック
  local clean_text
  clean_text=$(_strip_code_blocks "$text")
  local found=()
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    if printf '%s' "$clean_text" | grep -qF "$word"; then
      found+=("$word")
    fi
  done < <(_extract_term_list "$_principles_file" "$key")
  if [[ ${#found[@]} -gt 0 ]]; then
    printf '%s\n' "${found[@]}"
    return 1
  fi
  return 0
}

# 後方互換: AI定型語チェック
_check_ai_jargon() {
  local text="$1"
  _check_term_list "$text" "AI定型語"
}

# 外向き text を AI語 + カタカナ造語チェックし、hit 時に Forbidden block をセットする
# 呼び出し元: tool ごとの case 節
_block_if_ai_jargon() {
  local text="$1"
  local context_label="$2"  # "commit message" / "PR body" 等
  local hit_words
  # AI定型語 チェック (block)
  if ! hit_words=$(_check_term_list "$text" "AI定型語"); then
    GUARD_CLASS="Forbidden"
    local word_list
    word_list=$(printf '%s' "$hit_words" | tr '\n' ',' | sed 's/,$//')
    MESSAGE="${ICON_CRITICAL} AI定型語 block: [${word_list}] (${context_label})"
    ADDITIONAL_CONTEXT="AI定型語を削除または具体表現に置換して再実行してください。source: guidelines/writing/PRINCIPLES.md"
    _append_jp_quality_log "$context_label" "$word_list" "block"
    return
  fi
  # カタカナ造語 チェック (block)
  if ! hit_words=$(_check_term_list "$text" "カタカナ造語禁止"); then
    GUARD_CLASS="Forbidden"
    local word_list
    word_list=$(printf '%s' "$hit_words" | tr '\n' ',' | sed 's/,$//')
    MESSAGE="${ICON_CRITICAL} カタカナ造語 block: [${word_list}] (${context_label})"
    ADDITIONAL_CONTEXT="カタカナ造語を削除または説明的表現に置換して再実行してください。source: guidelines/writing/PRINCIPLES.md"
    _append_jp_quality_log "$context_label" "$word_list" "block"
  fi
}

# ====================================
# Bash コマンド分類ヘルパー関数
# ====================================
_is_serena_replaceable() {
  # Bash で読み出してる対象がコードファイルで、かつ Serena symbolic tools で代替可能か判定する
  # 振替推奨: cat/head/tail/grep <code_file>
  # 除外: grep -r/-R/--include= (ディレクトリ再帰探索は Bash 必須)、find / xargs / awk / sed の複雑系
  local cmd="$1"
  # 再帰オプションが付く grep は除外
  if [[ "$cmd" =~ grep[[:space:]]+([^|]*[[:space:]])?-[A-Za-z]*[rR] ]]; then
    return 1
  fi
  if [[ "$cmd" =~ grep[[:space:]]+[^|]*--include= ]]; then
    return 1
  fi
  # cat/head/tail/grep でコードファイル拡張子を直接参照
  if [[ "$cmd" =~ (^|[[:space:]\|\;\&\(])(cat|head|tail|grep)[[:space:]] ]] \
     && [[ "$cmd" =~ \.(ts|tsx|js|jsx|go|py|rs|rb|java|kt|swift|cpp|hpp|cs|scala|php)([[:space:]]|$|[\;\&\|\>]) ]]; then
    return 0
  fi
  return 1
}

classify_bash_command() {
  local cmd="$1"
  local cmd_without_msg_arg

  # commit message 内の危険語リテラル誤発火を防止
  # git commit -m "..." / -m '...' / -F file の引数値内容を除外してから危険語マッチ評価
  # v2.2.3: ヒアドキュメント (cat <<EOF...EOF) 本文も除去（git commit -m "$(cat <<'EOF' ... EOF)" 対策）
  cmd_without_msg_arg="$cmd"

  # HEREDOC 本文除去（POSIX awk 互換、行ごと処理）
  # 開始: <<-?[[:space:]]*['"]?DELIM['"]? を検出 → in_h=1、開始行のマーカー以降を切り捨て
  # 終端: 行全体が DELIM と一致（<<- は先頭タブ削減許容）→ in_h=0、終端行はスキップ
  # <<<here-string は <<<DELIM が "[A-Za-z_]" 直前の文字制約で不一致のため誤検出されない
  case "$cmd_without_msg_arg" in
    *'<<'*)
      cmd_without_msg_arg=$(printf '%s' "$cmd_without_msg_arg" | awk '
        BEGIN { in_h = 0; delim = ""; tab_strip = 0 }
        {
          if (in_h) {
            line = $0
            if (tab_strip) { sub(/^\t+/, "", line) }
            if (line == delim) { in_h = 0; delim = ""; tab_strip = 0 }
            next
          }
          pos = match($0, /<<-?[[:space:]]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)
          if (pos > 0) {
            m = substr($0, pos, RLENGTH)
            if (substr(m, 3, 1) == "-") { tab_strip = 1 }
            d = m
            sub(/^<<-?[[:space:]]*['"'"'"]?/, "", d)
            sub(/['"'"'"]?$/, "", d)
            delim = d
            in_h = 1
            print substr($0, 1, pos - 1)
            next
          }
          print
        }
      ')
      ;;
  esac

  if [[ "$cmd_without_msg_arg" =~ git[[:space:]]+commit[[:space:]] ]]; then
    cmd_without_msg_arg=$(printf '%s' "$cmd_without_msg_arg" \
      | sed -E 's/-m[[:space:]]*"[^"]*"/ /g' \
      | sed -E "s/-m[[:space:]]*'[^']*'/ /g" \
      | sed -E 's/-F[[:space:]]+[^[:space:]]+/ /g')
  fi

  # 禁止操作チェック（危険なコマンド）
  # grep外部プロセスを bash [[ =~ ]] に置換して高速化（v2.2.1）
  # /dev/null へのリダイレクトは安全、それ以外の /dev/ は禁止
  local _dev_forbidden=0
  if [[ "$cmd_without_msg_arg" =~ [0-9]*\>[[:space:]]*/dev/ ]] && ! [[ "$cmd_without_msg_arg" =~ [0-9]*\>[[:space:]]*/dev/null ]]; then
    _dev_forbidden=1
  fi
  if [[ "$_dev_forbidden" -eq 1 ]] || [[ "$cmd_without_msg_arg" =~ (rm[[:space:]]+-rf[[:space:]]+/|rm[[:space:]]+-rf[[:space:]]+\*|:\(\)\{|sudo[[:space:]]+rm|git[[:space:]]+push[[:space:]]+--force|git[[:space:]]+push[[:space:]]+-f) ]]; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} 禁止: 危険なコマンド検出"
    ADDITIONAL_CONTEXT="破壊的コマンド検出。実行を中止し安全な代替手段を提案"
    return
  fi

  # 自動処理禁止チェック
  if [[ "$cmd" =~ (npm[[:space:]]run[[:space:]]lint|prettier|eslint[[:space:]]--fix|go[[:space:]]fmt|autopep8|black[[:space:]]) ]]; then
    GUARD_CLASS="Boundary"
    MESSAGE="${ICON_WARNING} 要確認: 自動整形"
    return
  fi

  # 変更系コマンド
  if [[ "$cmd" =~ (git[[:space:]]commit|git[[:space:]]push|git[[:space:]]merge|git[[:space:]]rebase|npm[[:space:]]install|pip[[:space:]]install|go[[:space:]]mod|docker[[:space:]]build|docker[[:space:]]push) ]]; then
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: 変更系コマンド"
    return
  fi

  # 読み取り系コマンド（チェーン・パイプを含まない単純コマンドのみ）
  if [[ "$cmd" =~ ^(git[[:space:]](status|log|diff|branch)|ls[[:space:]]|pwd$|echo[[:space:]]|cat[[:space:]]|which[[:space:]]|type[[:space:]]) ]] && ! [[ "$cmd" =~ [\;\&\|] ]]; then
    GUARD_CLASS="Safe"
    return
  fi

  # その他のBashコマンドはBoundary扱い
  GUARD_CLASS="Boundary"
  MESSAGE="🔶 要確認: Bashコマンド"
}

# ====================================
# Edit/Write 内容の危険パターン検出
# security-guidance plugin（eval/exec 系）と相補的：
# クラウドメタデータSSRF・SQL文字列連結・機密情報リテラルを検出
# 機密リテラル系は Forbidden に昇格してブロック
# ====================================
detect_dangerous_patterns() {
  local content="$1"
  local detected=()
  local has_secret=0

  # 機密情報リテラル（Forbidden 昇格対象）
  if printf '%s' "$content" | grep -qE 'AKIA[A-Z0-9]{16}'; then
    detected+=("AWS Access Key literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'ghp_[A-Za-z0-9]{36}'; then
    detected+=("GitHub PAT literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'sk-[A-Za-z0-9]{40,}'; then
    detected+=("API key literal (sk-...)")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'xox[bp]-[A-Za-z0-9-]{20,}'; then
    detected+=("Slack token literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE -- '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'; then
    detected+=("Private key literal")
    has_secret=1
  fi

  # SSRF クラウドメタデータ（Boundary 警告）
  if printf '%s' "$content" | grep -qE '(169\.254\.169\.254|metadata\.google\.internal|100\.100\.100\.200)'; then
    detected+=("SSRF cloud metadata access")
  fi

  # SQL 文字列連結（Boundary 警告）
  if printf '%s' "$content" | grep -qE '(f"|f'\''|`)(SELECT|INSERT|UPDATE|DELETE)[[:space:]].*\{[^}]+\}'; then
    detected+=("SQL string interpolation (f-string/template)")
  elif printf '%s' "$content" | grep -qE '(SELECT|INSERT|UPDATE|DELETE)[[:space:]].*\$\{[^}]+\}'; then
    detected+=("SQL template literal injection")
  fi

  # 一般的な password ハードコード
  if printf '%s' "$content" | grep -qE '(api_key|password|secret|access_token|auth_token)[[:space:]]*[=:][[:space:]]*['\''"][a-zA-Z0-9_/+=-]{20,}'; then
    detected+=("Hardcoded credential assignment")
  fi

  if [ ${#detected[@]} -eq 0 ]; then
    return
  fi

  local joined
  joined=$(IFS='; '; echo "${detected[*]}")

  if [ "$has_secret" -eq 1 ]; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} 機密情報リテラル検出: ${joined}"
    ADDITIONAL_CONTEXT="ハードコードされた認証情報を検出。環境変数 or secret manager を使用すること。コミット前に履歴からも除去要"
  else
    MESSAGE="${ICON_WARNING} 危険パターン: ${joined}"
    ADDITIONAL_CONTEXT="security-guidance plugin と相補検出。SSRFはホワイトリスト・SQLはプレースホルダで防ぐ"
  fi
}

# ====================================
# Rename propagation 検知
# Heading / section / symbol rename 検知 → cross-ref 残存 warning
# ====================================
detect_rename_propagation() {
  local old_str="$1"
  local new_str="$2"
  local file_path="${3:-.}"

  # skip: 新名が空、旧名 ≤ 3 文字（false positive 多い）
  if [ -z "$new_str" ] || [ ${#old_str} -le 3 ]; then
    return
  fi

  # Heading rename pattern: "## OldName" → "## NewName" or "### OldName" → "### NewName"
  if [[ "$old_str" =~ ^(#{2,3})[[:space:]]+.+$ ]] && [[ "$new_str" =~ ^(#{2,3})[[:space:]]+.+$ ]]; then
    # heading rename 検知
    # grep 対象: 旧名の heading 記号や anchor reference を検索
    local heading_level="${BASH_REMATCH[1]}"
    local old_title=$(echo "$old_str" | sed -E "s/^${heading_level}[[:space:]]+//" | sed 's/[[:space:]]*$//')
    local new_title=$(echo "$new_str" | sed -E "s/^${heading_level}[[:space:]]+//" | sed 's/[[:space:]]*$//')

    # repo root を取得: file_path のディレクトリから git root を探す
    local search_root="."
    if [ -n "$file_path" ] && [ "$file_path" != "." ] && [ -d "$(dirname "$file_path")" ]; then
      # file_path から git root を探す
      local dir_path
      dir_path="$(dirname "$file_path")"
      search_root=$(cd "$dir_path" && git rev-parse --show-toplevel 2>/dev/null) || search_root="$dir_path"
    else
      # fallback: current directory から git root を探す
      search_root=$(git rev-parse --show-toplevel 2>/dev/null) || search_root="."
    fi

    # 旧名の残存検索（.md, .sh, .ts/.tsx, .js, .py, .json, .yaml, .toml）
    local grep_results
    grep_results=$(find "$search_root" \
      -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \) \
      -not -path "*/.git/*" \
      -not -path "*/node_modules/*" \
      -not -path "*/dist/*" \
      -not -path "*/build/*" \
      -exec grep -l "$old_title" {} \; 2>/dev/null | head -20)

    if [ -n "$grep_results" ]; then
      local file_count
      # bash builtin で行数カウント (wc -l fork 削減)
      if [[ -z "$grep_results" ]]; then
        file_count=0
      else
        local _tmp_fc="${grep_results//$'\n'/}"
        file_count=$(( ${#grep_results} - ${#_tmp_fc} + 1 ))
      fi
      local file_list
      # bash builtin で改行→カンマ変換 (tr fork 削減)
      file_list="${grep_results//$'\n'/','}"; file_list="${file_list%,}"

      local rename_warn="${ICON_WARNING} Rename検知: 旧heading「${old_title}」→「${new_title}」、${file_count}ファイルに残存（${file_list}）。cross-ref同期確認推奨"
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${rename_warn}"
      else
        ADDITIONAL_CONTEXT="${rename_warn}"
      fi
    fi
    return
  fi

  # Symbol rename pattern: 識別子 1 個のみ置換（foo_bar / camelCase / PascalCase）
  # 前後の context が同じ = rename likely
  # 単語の一部のみ置換は除外（false positive）
  if [[ "$old_str" =~ [^a-zA-Z0-9_]?([a-zA-Z_][a-zA-Z0-9_]*)[^a-zA-Z0-9_]? ]] && [[ "$new_str" =~ [^a-zA-Z0-9_]?([a-zA-Z_][a-zA-Z0-9_]*)[^a-zA-Z0-9_]? ]]; then
    # 置換個数を数える（1 個のみ rename と判定）
    local _old_idents _new_idents
    mapfile -t _old_idents < <(grep -o '[a-zA-Z_][a-zA-Z0-9_]*' <<< "$old_str")
    mapfile -t _new_idents < <(grep -o '[a-zA-Z_][a-zA-Z0-9_]*' <<< "$new_str")
    local old_count=${#_old_idents[@]}
    local new_count=${#_new_idents[@]}

    # identifier 1 個のみの置換と判定
    if [ "$old_count" -eq 1 ] && [ "$new_count" -eq 1 ]; then
      local old_ident="${_old_idents[0]}"
      local new_ident="${_new_idents[0]}"

      if [ "$old_ident" != "$new_ident" ]; then
        # repo root を取得: file_path のディレクトリから git root を探す
        local search_root="."
        if [ -n "$file_path" ] && [ "$file_path" != "." ] && [ -d "$(dirname "$file_path")" ]; then
          # file_path から git root を探す
          local dir_path
          dir_path="$(dirname "$file_path")"
          search_root=$(cd "$dir_path" && git rev-parse --show-toplevel 2>/dev/null) || search_root="$dir_path"
        else
          # fallback: current directory から git root を探す
          search_root=$(git rev-parse --show-toplevel 2>/dev/null) || search_root="."
        fi

        # 旧 identifier の残存検索
        local grep_results
        grep_results=$(find "$search_root" \
          -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" \) \
          -not -path "*/.git/*" \
          -not -path "*/node_modules/*" \
          -not -path "*/dist/*" \
          -not -path "*/build/*" \
          -exec grep -l "\b${old_ident}\b" {} \; 2>/dev/null | head -20)

        if [ -n "$grep_results" ]; then
          local file_count
          # bash builtin で行数カウント (wc -l fork 削減)
          if [[ -z "$grep_results" ]]; then
            file_count=0
          else
            local _tmp_fc="${grep_results//$'\n'/}"
            file_count=$(( ${#grep_results} - ${#_tmp_fc} + 1 ))
          fi
          local file_list
          # bash builtin で改行→カンマ変換 (tr fork 削減)
          file_list="${grep_results//$'\n'/','}"; file_list="${file_list%,}"

          local rename_warn="${ICON_WARNING} Rename検知: 「${old_ident}」→「${new_ident}」、${file_count}ファイルに残存（${file_list}）。cross-ref同期確認推奨"
          if [ -n "$ADDITIONAL_CONTEXT" ]; then
            ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${rename_warn}"
          else
            ADDITIONAL_CONTEXT="${rename_warn}"
          fi
        fi
      fi
    fi
  fi
}

# ====================================
# protection-mode 3層分類判定
# ====================================

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
  "Edit"|"Write"|"MultiEdit")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: ファイル編集"

    # 直編集ガード: ~/.claude/{synced_dir}/... で repo source 存在時に redirect 推奨
    # sync.sh to-local で上書き消失するため、必ず repo source を編集する規約
    _EDIT_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    if [ -n "$_EDIT_PATH" ] && [[ "$_EDIT_PATH" == "$HOME/.claude/"* ]]; then
      _REL_PATH="${_EDIT_PATH#"$HOME/.claude/"}"
      _FIRST_COMP="${_REL_PATH%%/*}"
      case "$_FIRST_COMP" in
        commands|skills|hooks|agents|rules|guidelines|config|references|CLAUDE.md)
          _REPO_PATH="$HOME/ai-tools/claude-code/$_REL_PATH"
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
    EDIT_CONTENT=$(jq -r '
      if .tool_input.content then .tool_input.content
      elif .tool_input.new_string then .tool_input.new_string
      elif .tool_input.edits then [.tool_input.edits[].new_string] | join("\n")
      else "" end
    ' <<< "$INPUT")
    if [ -n "$EDIT_CONTENT" ]; then
      detect_dangerous_patterns "$EDIT_CONTENT"
    fi

    # Rename propagation detection (Edit tool only has old_string/new_string)
    _OLD_STRING=$(jq -r '.tool_input.old_string // empty' <<< "$INPUT")
    _NEW_STRING=$(jq -r '.tool_input.new_string // empty' <<< "$INPUT")
    _FILE_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    if [ -n "$_OLD_STRING" ] && [ -n "$_NEW_STRING" ]; then
      detect_rename_propagation "$_OLD_STRING" "$_NEW_STRING" "$_FILE_PATH"
    fi

    # Sonnet delegation declaration grep (CLAUDE.md Auto-Delegation "Edit/Write declaration rule")
    # fetch last 30 lines of latest assistant message from transcript_path; check for "Inline exception" / "Inline prohibited"
    _TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$INPUT")
    if [ -n "$_TRANSCRIPT" ] && [ -f "$_TRANSCRIPT" ]; then
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
      if [ "$_DECL_FOUND" != "found" ]; then
        _DECL_WARN="⚠ Sonnet 委譲宣言抜け: CLAUDE.md Auto-Delegation rule 違反。Edit/Write 前に 1 行宣言してください: 'Inline exception (reason: ...) → parent inline execution' または 'Inline prohibited (reason: ...) → delegate to developer-agent'"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DECL_WARN}"
        else
          ADDITIONAL_CONTEXT="${_DECL_WARN}"
        fi
      fi
    fi
    ;;

  "Bash")
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
    classify_bash_command "$COMMAND"

    # AI定型語チェック: git commit / gh / glab の外向き text を抽出して block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      # --- git commit: -m オプション値を抽出 ---
      if [[ "$COMMAND" =~ git[[:space:]]+commit ]]; then
        _commit_msg=""
        # -m "..." 形式
        if [[ "$COMMAND" =~ -m[[:space:]]+'([^'\'']*)' ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        fi
        [[ -n "$_commit_msg" ]] && _block_if_ai_jargon "$_commit_msg" "commit message"
      fi

      # --- gh pr create / gh pr edit / gh issue create / gh issue comment / gh pr comment ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment) ]]; then
        _gh_text=""
        # --body "..." or --body '...'
        if [[ "$COMMAND" =~ --body[[:space:]]+'([^'\'']*)' ]]; then
          _gh_text="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --body[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${BASH_REMATCH[1]}"
        fi
        # --title "..." or --title '...' (append to check text)
        if [[ "$COMMAND" =~ --title[[:space:]]+'([^'\'']*)' ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_gh_text" ]]; then
          _gh_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment)' | head -1)
          _block_if_ai_jargon "$_gh_text" "${_gh_subcmd:-gh}"
        fi
      fi

      # --- glab mr create / glab issue create / glab mr note ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
        _glab_text=""
        if [[ "$COMMAND" =~ --description[[:space:]]+'([^'\'']*)' ]]; then
          _glab_text="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --description[[:space:]]\"([^\"]*)\" ]]; then
          _glab_text="${BASH_REMATCH[1]}"
        fi
        if [[ "$COMMAND" =~ --title[[:space:]]+'([^'\'']*)' ]]; then
          _glab_text="${_glab_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
          _glab_text="${_glab_text} ${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_glab_text" ]]; then
          _glab_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
          _block_if_ai_jargon "$_glab_text" "${_glab_subcmd:-glab}"
        fi
      fi
    fi

    # Serena substitution hint: notify Claude when Bash code-file read is detected
    # structurally prevents Bash ratio 51% (analytics) violating CLAUDE.md "Tool selection" principle
    if [ "$GUARD_CLASS" != "Forbidden" ] && _is_serena_replaceable "$COMMAND"; then
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}; 🔍 Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      else
        ADDITIONAL_CONTEXT="🔍 Bash でコードファイル参照検出、Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols (CLAUDE.md「Tool selection」原則、analytics で Bash 51% 振替余地大)"
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

  "mcp__claude_ai_Notion__notion-create-pages"|"mcp__claude_ai_Notion__notion-update-page"|"mcp__claude_ai_Notion__notion-create-comment"|"mcp__claude_ai_Slack__slack_send_message")
    GUARD_CLASS="Safe"
    # 実投稿系 MCP 使用前に PRINCIPLES 再注入（analytics で上位使用、確定送信のみ対象）
    # 除外: slack_send_message_draft / slack_create_canvas / slack_update_canvas
    #   理由: draft / canvas 編集は実投稿前段階、書き直し前提のためノイズ防止
    ADDITIONAL_CONTEXT="📝 投稿前自問5点: ①「で、つまり何？」と思わせないか ②初見が途中で止まらないか ③各段落の役割（背景/理由/具体例/結論/注意点）明確か ④抽象名詞の羅列で段落が終わってないか ⑤bullet 5連続+地の文0の金太郎飴か。詳細: claude-code/guidelines/writing/PRINCIPLES.md"

    # AI定型語チェック: text / content param を抽出して block
    _mcp_text=$(jq -r '.tool_input.text // .tool_input.content // empty' <<< "$INPUT")
    if [[ -n "$_mcp_text" ]]; then
      _block_if_ai_jargon "$_mcp_text" "$TOOL_NAME"
    fi
    ;;

  "Task")
    GUARD_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    # ただし general-purpose は CLAUDE.md「原則使わない」最大コスト源 → Boundary 警告
    SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT")
    if [ "${SUBAGENT_TYPE}" = "general-purpose" ]; then
      GUARD_CLASS="Boundary"
      MESSAGE="${ICON_WARNING} general-purpose agent（CLAUDE.md「原則使わない」、最大コスト源）"
      ADDITIONAL_CONTEXT="代替: claude-code-guide / Explore / 直接 grep+find / serena MCP（references/performance-insights.md 参照）"
    fi
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
  jq -n --arg msg "$MESSAGE" --arg ctx "$ADDITIONAL_CONTEXT" \
    '{"systemMessage": $msg, "additionalContext": $ctx}'
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
