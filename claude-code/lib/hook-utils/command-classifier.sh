#!/bin/bash
# =============================================================================
# hook-utils / command-classifier module
# =============================================================================
if [[ "${_HOOK_UTILS_COMMAND_CLASSIFIER_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_COMMAND_CLASSIFIER_LOADED=1

# =============================================================================
# block log 共通出力関数
# social-hit / private-name どちらのブロックログにも使用する。
# ローテーション判定 (1MB 超で .bak rename)、timestamp 付与、1 行 append が共通実装。
# Usage: _append_block_log <log_file> <tool_name> <hit_term> <target>
# =============================================================================
_append_block_log() {
  local log_file="$1"
  local tool_name="$2"
  local hit_term="$3"
  local target="$4"
  local log_dir
  log_dir=$(dirname "$log_file")
  mkdir -p "$log_dir" 2>/dev/null || true
  _rotate_log_if_needed "$log_file"
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$target" >> "$log_file" 2>/dev/null || true
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

# cat <file> の単純読み取りを検出 (Read ツールで代替可能)
# 対象: cat <file.md/.json/.yaml/.toml/.txt/.sh/.bats> (write 系・pipe 系は除外)
# 除外: cat > / cat >> (write), cat << (heredoc), cat ... | (pipe)
_is_cat_simple_read() {
  local cmd="$1"
  # cat を含むか (先頭 or セパレータの後)
  if ! [[ "$cmd" =~ (^|[[:space:]\;\&\(])(cat)[[:space:]] ]]; then
    return 1
  fi
  # write 系は除外 (cat > / cat >> / cat <<、および後置 redirect `cat file >> out` も含む)
  if [[ "$cmd" =~ (>>?|<<) ]]; then
    return 1
  fi
  # pipe 出力は除外 (cat file | ...)
  if [[ "$cmd" =~ \| ]]; then
    return 1
  fi
  # Read ツールで代替可能な拡張子を持つファイル参照
  if [[ "$cmd" =~ \.(md|json|yaml|yml|toml|txt|sh|bats|env)([[:space:]]|$|[\;\&\|\>2]) ]]; then
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

  # その他のBashコマンドはBoundary扱い (MESSAGE なし = systemMessage を出さず noise と token を削る)
  GUARD_CLASS="Boundary"
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
