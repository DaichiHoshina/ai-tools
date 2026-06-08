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

# セッションID取得: stdin JSON の .session_id を優先 (他 hook と同様の方式)
# CLAUDE_CODE_SESSION_ID env は Claude Code v2.1.90+ で export される場合があるため fallback で参照
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${SESSION_ID}}"

# protection-mode判定変数
GUARD_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""

# ====================================
# AI定型語 / カタカナ造語 block 関数
# PRINCIPLES.md から動的抽出 → 外向き text に grep → hit で exit 2
# ====================================
_principles_file="$HOME/.claude/guidelines/writing/NG-DICTIONARY.md"

# _extract_term_list の per-process cache (同一プロセス内で同 key の grep を1回に削減)
declare -A _term_list_cache=()
_term_list_cache_loaded=0

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
# per-process cache: 同 file+key の grep を1回に削減
_extract_term_list() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  local cache_key="${file}::${key}"
  if [[ -v "_term_list_cache[${cache_key}]" ]]; then
    local cached="${_term_list_cache[${cache_key}]}"
    [[ -n "$cached" ]] && printf '%s\n' "${cached}"
    return 0
  fi
  local line
  line=$(grep -m1 "^\*\*${key}\*\*:" "$file" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    _term_list_cache["${cache_key}"]=""
    return 0
  fi
  local body="${line#*: }"
  local result
  result=$(printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$' || true)
  _term_list_cache["${cache_key}"]="${result}"
  [[ -n "$result" ]] && printf '%s\n' "${result}"
  return 0
}

# AI定型語を PRINCIPLES.md から抽出 (後方互換 wrapper)
_extract_ai_jargon() {
  local file="$1"
  _extract_term_list "$file" "AI定型語"
}

# 必須 key sanity check: hook が exact match 参照する key が抽出 0 件なら fail-loud
# PRINCIPLES.md key rename / 記法破壊を早期検出して silent pass を防ぐ
# session 内 cache: _assert_required_keys_done=1 でスキップ (重複検査防止)
_assert_required_keys_done=${_assert_required_keys_done:-0}
_assert_required_keys() {
  [[ "$_assert_required_keys_done" -eq 1 ]] && return 0
  _assert_required_keys_done=1
  # PRINCIPLES.md 不在時は別経路で既に silent pass → この検査はスキップ
  [[ -f "$_principles_file" ]] || return 0
  local required_keys=("AI定型語" "カタカナ造語禁止" "断定語 (warn-only)" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)")
  local key
  for key in "${required_keys[@]}"; do
    local result
    result=$(_extract_term_list "$_principles_file" "$key")
    if [[ -z "$result" ]]; then
      printf '[hook-error] PRINCIPLES.md key '"'"'%s'"'"' 抽出 0 件 — rename or 記法破壊の可能性。silent pass 防止のため exit 2 で fail-loud。\n' "$key" >&2
      exit 2
    fi
  done
}

# inject byte size log 出力関数
# 引数: tool_name, bytes, status(ok|over)
_append_jp_quality_inject_log() {
  local tool_name="$1"
  local bytes="$2"
  local status_str="$3"
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-inject.log"
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
  printf '%s | tool=%s | bytes=%s | threshold=1500 | status=%s\n' \
    "$ts" "$tool_name" "$bytes" "$status_str" >> "$log_file" 2>/dev/null || true
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
# 全 block category を一括収集して exit 2 + まとめて提示する (逐次 block 廃止)
# 呼び出し元: tool ごとの case 節
_block_if_ai_jargon() {
  local text="$1"
  local context_label="$2"  # "commit message" / "PR body" 等
  # 必須 key sanity check (session 内 cache 済なら即 return)
  _assert_required_keys

  # inject byte size 計測: 全 block list の合計抽出 byte 数を計算してログ出力
  local _inject_keys=("AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)")
  local _inject_total=0
  local _inject_key
  for _inject_key in "${_inject_keys[@]}"; do
    local _inject_terms
    _inject_terms=$(_extract_term_list "$_principles_file" "$_inject_key" 2>/dev/null || true)
    _inject_total=$(( _inject_total + ${#_inject_terms} ))
  done
  local _inject_status="ok"
  [[ "$_inject_total" -gt 1500 ]] && _inject_status="over"
  _append_jp_quality_inject_log "$context_label" "$_inject_total" "$_inject_status"

  # --- block category 定義 ---
  # 各要素: "key|label|guidance"
  # label: bats テスト互換の表示名 (例: "難読漢語 block")
  local _block_categories=(
    "AI定型語|AI定型語 block|AI定型語を削除または具体表現に置換してください"
    "カタカナ造語禁止|カタカナ造語 block|カタカナ造語を削除または説明的表現に置換してください"
    "難読漢語 (block)|難読漢語 block|難読漢語を平易な語に置換してください"
    "非日常英語 (block)|非日常英語 block|日常で使う英語または日本語に置換してください"
    "弱い表現 (block)|弱い表現 block|弱い表現を断定または「検証が必要」に置換してください"
    "冗長表現 (block)|冗長表現 block|冗長表現を短縮形に置換してください (例: することができる → できる、を行う → する)"
  )

  # block hit: key → hit_words の連想配列
  declare -A _hit_by_key=()
  local _hit_words
  local _cat_entry _cat_key _cat_label _cat_guidance
  local _has_block=0

  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    if ! _hit_words=$(_check_term_list "$text" "$_cat_key"); then
      _hit_by_key["${_cat_key}"]="${_hit_words}"
      _has_block=1
    fi
  done

  # warn-only チェック (block 有無に関係なく実行)
  local _warn_words=""
  if ! _warn_words=$(_check_term_list "$text" "断定語 (warn-only)"); then
    local _warn_list
    _warn_list=$(printf '%s' "$_warn_words" | tr '\n' ',' | sed 's/,$//')
    _append_jp_quality_log "$context_label" "$_warn_list" "warn"
  fi

  # block なし → return
  if [[ "$_has_block" -eq 0 ]]; then
    return
  fi

  # --- 全 hit を一括集計してメッセージ構築 ---
  GUARD_CLASS="Forbidden"

  # 全 hit 用語をカンマ区切りで結合 (log 用)
  local _all_terms_list=""
  local _detail_lines=""
  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    # label: 2番目フィールド (key|label|guidance から抽出)
    local _rest="${_cat_entry#*|}"
    _cat_label="${_rest%%|*}"
    _cat_guidance="${_rest#*|}"
    if [[ -v "_hit_by_key[${_cat_key}]" ]]; then
      local _wl
      _wl=$(printf '%s' "${_hit_by_key[${_cat_key}]}" | tr '\n' ',' | sed 's/,$//')
      if [[ -n "$_all_terms_list" ]]; then
        _all_terms_list="${_all_terms_list},${_wl}"
      else
        _all_terms_list="${_wl}"
      fi
      # _detail_lines に label を使う (bats テスト "難読漢語 block" 等と互換)
      _detail_lines="${_detail_lines}  ${_cat_label}: [${_wl}] → ${_cat_guidance}"$'\n'
    fi
  done

  # log は全 hit 用語をカンマ区切りで1行
  _append_jp_quality_log "$context_label" "$_all_terms_list" "block"

  # systemMessage: 検出用語一覧
  MESSAGE="${ICON_CRITICAL} NG用語 block (${context_label}): [${_all_terms_list}]"

  # additionalContext: category 別詳細 + source
  ADDITIONAL_CONTEXT="以下のNG用語を修正して再実行してください。source: guidelines/writing/NG-DICTIONARY.md
${_detail_lines}"

  # 各 block category の block list も表示 (回避参考)
  local _ref_lines=""
  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    if [[ -v "_hit_by_key[${_cat_key}]" ]]; then
      local _full_list
      _full_list=$(_extract_term_list "$_principles_file" "$_cat_key" 2>/dev/null | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g' || true)
      _ref_lines="${_ref_lines}  ${_cat_key} block list: ${_full_list}"$'\n'
    fi
  done
  if [[ -n "$_ref_lines" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}
block list (この session で全て回避):
${_ref_lines}"
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

    # 旧名の残存検索（.md, .sh, .ts/.tsx, .js, .py, .json, .yaml, .toml, .bats）
    local grep_results
    grep_results=$(find "$search_root" \
      -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.bats" \) \
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

    # slug 形式 anchor の残存検索 (#old-slug)
    # slug 化: 小文字化 / 英数・スペース・ハイフン以外除去 / 空白→ハイフン
    local old_slug
    old_slug=$(printf '%s' "$old_title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g')
    if [ -n "$old_slug" ] && [ ${#old_slug} -gt 3 ]; then
      local slug_pattern="#${old_slug}"
      local slug_results
      slug_results=$(find "$search_root" \
        -type f \( -name "*.md" -o -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.toml" -o -name "*.bats" \) \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -exec grep -lF "$slug_pattern" {} \; 2>/dev/null | head -20)
      if [ -n "$slug_results" ]; then
        local slug_list
        slug_list="${slug_results//$'\n'/','}"; slug_list="${slug_list%,}"
        local slug_warn="${ICON_WARNING} anchor slug 残存: 「${slug_pattern}」が残存（${slug_list}）。bats anchor・cross-ref 同期確認推奨"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${slug_warn}"
        else
          ADDITIONAL_CONTEXT="${slug_warn}"
        fi
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
# social-hit block
# ~/ai-tools/ public repo への社内 product 名 / 社内識別子の書き込みを hard block
# term list は ~/.claude/rules/public-repo-private-data-block.md の
# "social-hit (block)" key から動的抽出 (PRINCIPLES.md と同じ記法)
# ====================================
_social_hit_rule_file="$HOME/.claude/rules/public-repo-private-data-block.md"

# social-hit block ログ出力関数
_append_social_hit_log() {
  local tool_name="$1"
  local hit_term="$2"
  local file_path="$3"
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/social-hit-block.log"
  mkdir -p "$log_dir" 2>/dev/null || true
  if [[ -f "$log_file" ]]; then
    local fsize
    fsize=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    if [[ "${fsize}" -gt 1048576 ]]; then
      mv "$log_file" "${log_file}.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
    fi
  fi
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$file_path" >> "$log_file" 2>/dev/null || true
}

# ai-tools public repo への social-hit term 書き込みを block する
# 引数: file_path, content
_check_social_hit() {
  local file_path="$1"
  local content="$2"
  [[ -z "$file_path" ]] && return 0
  [[ -z "$content" ]] && return 0

  # rule file 不在時は silent pass (未 sync 環境への配慮)
  [[ -f "$_social_hit_rule_file" ]] || return 0

  # ai-tools/ 配下の path のみ判定対象
  local ai_tools_prefix="$HOME/ai-tools/"
  # HOME を展開した絶対パスで前方一致
  if [[ "$file_path" != "${ai_tools_prefix}"* ]]; then
    return 0
  fi

  # 自己除外 (allowlist): rule 説明文として term を保持する file は判定対象外
  local rel_path="${file_path#"${ai_tools_prefix}"}"
  case "$rel_path" in
    claude-code/rules/public-repo-private-data-block.md|\
    claude-code/CLAUDE.md|\
    claude-code/hooks/pre-tool-use.sh)
      return 0
      ;;
  esac

  # social-hit term 抽出 + grep
  local found=()
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    if printf '%s' "$content" | grep -qF "$word"; then
      found+=("$word")
    fi
  done < <(_extract_term_list "$_social_hit_rule_file" "social-hit (block)")

  if [[ ${#found[@]} -gt 0 ]]; then
    local word_list
    word_list=$(printf '%s' "${found[*]}" | tr ' ' ',')
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} social-hit block: [${word_list}] file=${file_path}"
    ADDITIONAL_CONTEXT="ai-tools repo は public。社内 product 名 / 識別子を public repo に書き込めません。
対処: file_path を ~/.claude/references-private/ に切り替えるか、term を削除 / 匿名化して再実行してください。
ログ: ~/.claude/logs/social-hit-block.log"
    printf '[social-hit-block] term=%s file=%s\n' "$word_list" "$file_path" >&2
    _append_social_hit_log "$TOOL_NAME" "$word_list" "$file_path"
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

  # jsonl path 構築 (user-prompt-submit.sh と同一 slug 変換)
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  [[ ! -f "$_JSONL" ]] && return 0

  # session start epoch
  local _NOW
  printf -v _NOW '%(%s)T' -1
  local _TS_RAW
  _TS_RAW=$(head -20 "$_JSONL" 2>/dev/null | grep -m1 '"timestamp":"' | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4) || true
  [[ -z "$_TS_RAW" ]] && return 0
  local _TS_TRIM="${_TS_RAW%%.*}"
  _TS_TRIM="${_TS_TRIM%Z}"
  local _START_EPOCH
  _START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$_TS_TRIM" "+%s" 2>/dev/null) || return 0
  local _ELAPSED=$(( _NOW - _START_EPOCH ))

  # msg count
  local _MSG_COUNT
  _MSG_COUNT=$(grep -c '"type":"user"\|"type":"assistant"' "$_JSONL" 2>/dev/null) || _MSG_COUNT=0

  local _AGE_H=$(( _ELAPSED / 3600 ))
  local _REASON=""
  (( _ELAPSED >= 10800 )) && _REASON="age=${_AGE_H}h"
  if (( _MSG_COUNT >= 1000 )); then
    [[ -n "$_REASON" ]] && _REASON="${_REASON} / "
    _REASON="${_REASON}messages=${_MSG_COUNT}"
  fi
  [[ -z "$_REASON" ]] && return 0

  # 発火: state file 書き込み + log 追記 + additionalContext 追加
  mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
  touch "$_WARN_FILE" 2>/dev/null || true
  local _TS_LABEL
  _TS_LABEL=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
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
  # hook source は allowlist 対象のため social-hit term literal 記載可 (rules/public-repo-private-data-block.md)
  local _IS_LARGE_REPO=0
  case "$file_path" in
    "${HOME}"/ghq/github.com/snkrdunk/* | \
    "${HOME}"/ghq/github.com/snkrdunk-loadtest/* | \
    "${HOME}"/ghq/github.com/snkrdunk-terraform/*)
      _IS_LARGE_REPO=1 ;;
    *)
      _IS_LARGE_REPO=0 ;;
  esac

  # src 拡張子チェック
  local _IS_SRC=0
  case "$file_path" in
    *.go|*.ts|*.tsx|*.py|*.dart|*.tf) _IS_SRC=1 ;;
  esac

  if [[ "$_IS_LARGE_REPO" -eq 1 && "$_IS_SRC" -eq 1 ]]; then
    # hit: counter をインクリメント
    local _CUR=0
    [[ -f "$_COUNT_FILE" ]] && read -r _CUR < "$_COUNT_FILE" 2>/dev/null || _CUR=0
    _CUR=$(( _CUR + 1 ))
    printf '%s\n' "$_CUR" > "$_COUNT_FILE" 2>/dev/null || true

    # threshold 判定 (>= 5)
    if (( _CUR >= 5 )) && [[ ! -f "$_WARN_FILE" ]]; then
      touch "$_WARN_FILE" 2>/dev/null || true
      local _SUGGEST="[delegation-suggest] last ${_CUR} edits on large-repo source. Next edit-class op → consider developer-agent delegation"
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
  local _today=$(date +%Y%m%d)
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
  local _aitools_dir="$HOME/ai-tools"
  local _writing_commits=""
  local _aitools_real
  _aitools_real=$(cd "$_aitools_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  local _project_real
  _project_real=$(cd "$_project_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  if [[ -n "$_aitools_real" && "$_aitools_real" != "$_project_real" ]]; then
    _writing_commits=$(git -C "$_aitools_dir" log --since="midnight" --pretty=format:'%h %s' --no-merges \
      -- "claude-code/guidelines/" "claude-code/CLAUDE.md" 2>/dev/null | head -n "${_commit_cap}" || true)
    if [[ -z "$_writing_commits" ]] && ! git -C "$_aitools_dir" rev-parse --git-dir >/dev/null 2>&1; then
      mkdir -p "$_inject_log_dir" 2>/dev/null || true
      printf '[%s] today-commit inject: git log failed at %s (writing path)\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_aitools_dir" >> "$_inject_log_file" 2>/dev/null || true
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

    # large-repo 連続 Edit 委譲 signal (warn-only)
    _EDIT_PATH_FOR_LARGE=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    _check_large_repo_consecutive_edit "$SESSION_ID" "$_EDIT_PATH_FOR_LARGE"

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

    # social-hit block: ai-tools public repo への社内 product 名書き込み防止
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      _SOCIAL_HIT_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
      if [ -n "$_SOCIAL_HIT_PATH" ]; then
        _check_social_hit "$_SOCIAL_HIT_PATH" "$EDIT_CONTENT"
      fi
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

    # 書く系 tool: 今日の commit inject（writing 規約更新を最新規範で反映させる）
    _inject_today_commits
    fi  # end: cwd-guard Forbidden skip
    ;;

  "Bash")
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
    classify_bash_command "$COMMAND"

    # AI定型語チェック: git commit / gh / glab の外向き text を抽出して block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      # --- git commit: -m オプション値を抽出 (commit-tree / commit-graph は除外) ---
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
        _commit_msg=""
        # -m "..." 形式
        if [[ "$COMMAND" =~ -m[[:space:]]+'([^'\'']*)' ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
          _commit_msg="${BASH_REMATCH[1]}"
        fi
        [[ -n "$_commit_msg" ]] && _block_if_ai_jargon "$_commit_msg" "commit message"
      fi

      # --- gh pr create / gh pr edit / gh pr review / gh pr merge / gh issue create / gh issue comment ---
      # --- gh release create ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && { \
          [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] || \
          [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; }; then
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
        # --notes "..." or --notes '...' (gh release create)
        if [[ "$COMMAND" =~ --notes[[:space:]]+'([^'\'']*)' ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --notes[[:space:]]\"([^\"]*)\" ]]; then
          _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_gh_text" ]]; then
          _gh_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
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

    # 書く系 Bash コマンド: 今日の commit inject
    # 対象: git commit / gh pr|issue|release / glab mr|issue|release
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]] \
         || [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] \
         || [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]] \
         || [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]] \
         || [[ "$COMMAND" =~ glab[[:space:]]+release[[:space:]]+create ]]; then
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

    # AI定型語チェック: text / content param を抽出して block
    _mcp_text=$(jq -r '.tool_input.text // .tool_input.content // empty' <<< "$INPUT")
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
    PARALLEL_REVIEW=$'【並列 self-review (強制 echo)】\n1. Manager 経由なら allocation 中の formula_trace を user に 2 行 echo:\n   formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / <PASS|FAIL> (basis=<T_i_basis>)\n   fan-out: N=<n>, targets=<file count>\n2. Manager 未経由の直接 Task 発火 (例: explore-agent / developer-agent 単発) は 1 行 echo:\n   judgment: N=<n> / independent_tasks=<count> / parallel=<reason or \'single-task\'>\n3. 独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1)\n4. echo 抜けは under-parallel risk (canonical: references/PARALLEL-PATTERNS.md)'

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
      GUARD_CLASS="Boundary"
      MESSAGE="${ICON_WARNING} general-purpose agent（CLAUDE.md「原則使わない」、最大コスト源）"
      ADDITIONAL_CONTEXT="代替: claude-code-guide / Explore / 直接 grep+find / serena MCP（references/performance-insights.md 参照）
${PARALLEL_REVIEW}${PREP_WARN}"
    else
      ADDITIONAL_CONTEXT="${PARALLEL_REVIEW}${PREP_WARN}"
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
