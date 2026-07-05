#!/bin/bash
# =============================================================================
# Hook共通ユーティリティ
# =============================================================================
# 多重 source 防止
if [[ "${_HOOK_UTILS_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_LOADED=1

set -euo pipefail

# shellcheck source=../hooks/lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/thresholds.sh"
# shellcheck source=../hooks/lib/portable-stat.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/portable-stat.sh"

# -----------------------------------------------------------------------------
# 共通アイコン (Nerd Fonts / Unicode)
# 各hookでの重複定義と表記ブレ（ICON_WARN vs ICON_WARNING、✓ vs ✓）を解消。
# hook-utils.sh を source した hook はこの変数をそのまま参照できる。
# -----------------------------------------------------------------------------
: "${ICON_SUCCESS:=$'✓'}"    # check-circle
: "${ICON_WARNING:=$'▲'}"    # exclamation-triangle
: "${ICON_ERROR:=$'✗'}"      # x-mark
: "${ICON_FORBIDDEN:=$'⊗'}"  # ban
: "${ICON_CRITICAL:=$'◉'}"   # filled circle (critical event)
: "${ICON_IDLE:=$'☾'}"       # moon (idle/sleep)
# 後方互換: ICON_WARN は ICON_WARNING のエイリアス
: "${ICON_WARN:=${ICON_WARNING}}"

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

# Stop/StopFailure共通の通知送信
# Usage: send_stop_notification "$INPUT" "タイトル接尾辞" "サウンド名" "ntfyタグ" "ntfy優先度"
send_stop_notification() {
  # デスクトップ通知 (terminal-notifier + ntfy.sh) は default で完全無効化。
  # 復活させたい時は CLAUDE_STOP_NOTIFY=1 を export する。
  # caller 側 (hooks/stop.sh / stop-failure.sh) の env gate と二重にする hard-off。
  if [[ "${CLAUDE_STOP_NOTIFY:-0}" != "1" ]]; then
    return 0
  fi

  local input="$1"
  local title_suffix="${2:-}"
  local sound="${3:-Glass}"
  local ntfy_tags="${4:-robot}"
  local ntfy_priority="${5:-default}"

  local last_msg default_msg
  default_msg="作業が完了しました"
  last_msg=$(echo "$input" | jq -r ".last_assistant_message // \"${default_msg}\"")
  local cwd
  cwd=$(echo "$input" | jq -r '.cwd // ""')
  local project_name
  project_name=$(basename "${cwd:-unknown}")

  # short-message skip: 通知本文が閾値未満なら通知しない (「test」等の一言応答による noise 抑制)。
  # 閾値は CLAUDE_STOP_NOTIFY_MIN_LEN で変更可 (default 8)。0 で skip 無効化。
  local min_len="${CLAUDE_STOP_NOTIFY_MIN_LEN:-8}"
  if [[ "${min_len}" != "0" ]] && [[ ${#last_msg} -lt ${min_len} ]]; then
    return 0
  fi

  local notify_msg="${last_msg:0:80}"
  if [ ${#last_msg} -gt 80 ]; then
    notify_msg="${notify_msg}..."
  fi

  local title="Claude Code [${project_name}]"
  if [ -n "$title_suffix" ]; then
    title="${title} ${title_suffix}"
  fi

  if command -v terminal-notifier &>/dev/null; then
    local -a notifier_args=(
      -title "$title"
      -message "${notify_msg}"
      -contentImage "$HOME/.claude/claude-icon.png"
      -execute "osascript -e 'tell application \"iTerm\" to activate'"
    )
    # 空文字なら -sound 自体を省略 (terminal-notifier の default 音再生を回避)
    if [ -n "$sound" ]; then
      notifier_args+=(-sound "$sound")
    fi
    terminal-notifier "${notifier_args[@]}" &
  fi

  local ntfy_topic="${CLAUDE_NTFY_TOPIC:-}"
  if [ -n "$ntfy_topic" ]; then
    curl -sf \
      -H "Title: ${title}" \
      -H "Tags: ${ntfy_tags}" \
      -H "Priority: ${ntfy_priority}" \
      -d "${notify_msg}" \
      "https://ntfy.sh/${ntfy_topic}" &>/dev/null &
  fi
}

# terminalSequence (v2.1.141+) 用エスケープシーケンス生成
# OSC 0 (window title) + OSC 9 (iTerm2 notification) + BEL を結合。
# Claude Code allowlist: OSC 0/1/2/9/99/777 と BEL のみ許可。
# Usage: build_terminal_sequence "WINDOW_TITLE" "NOTIFY_BODY" [include_bell:true|false]
# Output: stdout に raw escape sequence (JSON 埋め込みは jq --arg で安全化)
build_terminal_sequence() {
  local title="$1"
  local body="${2:-}"
  local include_bell="${3:-true}"
  # ESC = \x1b, BEL = \x07
  local esc=$'\x1b'
  local bel=$'\x07'
  local seq=""
  [ -n "$title" ] && seq+="${esc}]0;${title}${bel}"
  [ -n "$body" ] && seq+="${esc}]9;${body}${bel}"
  [ "$include_bell" = "true" ] && seq+="${bel}"
  printf '%s' "$seq"
}

# git worktreeのmemoryディレクトリをメインリポジトリにシンボリックリンク
# Usage: ensure_worktree_memory_link "/path/to/worktree"
ensure_worktree_memory_link() {
  local target_dir="$1"
  [[ -z "${target_dir}" ]] && return 0

  local git_dir common_dir
  git_dir=$(git -C "${target_dir}" rev-parse --git-dir 2>/dev/null) || return 0
  common_dir=$(git -C "${target_dir}" rev-parse --git-common-dir 2>/dev/null) || return 0

  # 相対パスなら絶対パスに変換
  [[ "${git_dir}" != /* ]] && git_dir="${target_dir}/${git_dir}"
  [[ "${common_dir}" != /* ]] && common_dir="${target_dir}/${common_dir}"

  # python3でパス正規化（cd+pwdはchpwdフック等で余計な出力が混入する）
  local abs_git abs_common
  abs_git=$(python3 -c "import os; print(os.path.realpath('${git_dir}'))")
  abs_common=$(python3 -c "import os; print(os.path.realpath('${common_dir}'))")

  # worktreeでなければ何もしない
  [[ "${abs_git}" == "${abs_common}" ]] && return 0

  # メインリポジトリのパス = git-common-dirの親
  local main_repo
  main_repo=$(dirname "${abs_common}")

  # パスをプロジェクトIDに変換（/ → -）
  local wt_id main_id
  wt_id=${target_dir//\//-}
  main_id=${main_repo//\//-}

  local projects_dir="${HOME}/.claude/projects"
  local wt_mem="${projects_dir}/${wt_id}/memory"
  local main_mem="${projects_dir}/${main_id}/memory"

  # 既にシンボリックリンクなら何もしない
  [[ -L "${wt_mem}" ]] && return 0

  # メインのmemoryディレクトリを確保
  mkdir -p "${main_mem}"
  mkdir -p "${projects_dir}/${wt_id}"

  # 既存memoryがあればメインに移動
  if [[ -d "${wt_mem}" ]]; then
    cp -rn "${wt_mem}/"* "${main_mem}/" 2>/dev/null || true
    rm -rf "${wt_mem}"
  fi

  ln -s "${main_mem}" "${wt_mem}"
}

# =============================================================================
# ISO8601 UTC timestamp → epoch 秒 変換関数 (クロスプラットフォーム)
# BSD (date -j) → GNU (date -d) の順に試行する。fractional 秒 (.225) / 末尾 Z は除去。
# 変換失敗の場合は stdout 空で rc=1 を返す。
# Usage: epoch=$(_iso8601_to_epoch "2026-06-12T01:02:03.000Z") || ...
# =============================================================================
_iso8601_to_epoch() {
  local ts="${1:-}"
  [[ -n "$ts" ]] || return 1
  local _trim="${ts%%.*}"  # .225Z → 除去
  _trim="${_trim%Z}"        # 末尾 Z 除去 (fractional なし場合)
  # jsonl timestamp は UTC。BSD は date -j -f、GNU は date -d で解釈
  TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$_trim" "+%s" 2>/dev/null \
    || TZ=UTC date -d "${_trim}Z" "+%s" 2>/dev/null \
    || return 1
}

# =============================================================================
# JSONL session epoch 解決関数
# session_id + cwd から JSONL path を導出し、先頭 timestamp を epoch 整数に変換して stdout へ出力する。
# JSONL 不在 / timestamp 不在 / date 変換失敗の場合は stdout 空で rc=1 を返す。
# Usage: epoch=$(_resolve_session_jsonl_epoch "$session_id" "$cwd") || return 0
# =============================================================================
_resolve_session_jsonl_epoch() {
  local session_id="$1"
  local cwd="$2"
  # slug 変換: / → -、. → -
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  [[ -f "$_JSONL" ]] || return 1
  local _TS_RAW
  _TS_RAW=$(head -20 "$_JSONL" 2>/dev/null | grep -m1 '"timestamp":"' | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4) || true
  [[ -n "$_TS_RAW" ]] || return 1
  _iso8601_to_epoch "$_TS_RAW" || return 1
}

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
  if [[ -f "$log_file" ]]; then
    local fsize
    fsize=$(portable_stat_size "$log_file")
    if [[ "${fsize}" -gt ${_TH_LOG_MAX_BYTES} ]]; then
      local _bak_ts; printf -v _bak_ts '%(%Y%m%d%H%M%S)T' -1
      mv "$log_file" "${log_file}.${_bak_ts}.bak" 2>/dev/null || true
    fi
  fi
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$target" >> "$log_file" 2>/dev/null || true
}

# =============================================================================
# ai-tools repo path helper
# symlink (~/ai-tools/) と ghq 実 path の両方を OR 判定するユーティリティ。
# symlink が存在しない環境でも block が正常動作するよう両 prefix を列挙する。
# =============================================================================

# ai-tools repo の path prefix list を改行区切りで出力する。
# symlink と ghq 実 path の両方を返す。
_aitools_prefixes() {
  printf '%s\n' \
    "$HOME/ai-tools/" \
    "$HOME/ghq/github.com/DaichiHoshina/ai-tools/"
}

# 与えられた path が ai-tools 配下かどうかを判定する。
# 戻り値: 0=ai-tools 配下 / 1=配下でない
# usage: _is_aitools_path "$path"
_is_aitools_path() {
  local p="$1"
  local prefix
  while IFS= read -r prefix; do
    [[ "$p" == "${prefix}"* ]] && return 0
  done < <(_aitools_prefixes)
  return 1
}

# 与えられた path が Claude Code auto-memory dir かどうかを判定する。
# 対象 dir:
#   - ~/.claude/projects/*/memory/    (session-bound auto-memory)
#   - ~/.claude/agent-memory/          (subagent 共通 memory 出力先)
# AI 自己分析の生記録 (work-context / writing_failure / pending-improvements 等) は
# 外向き prose 規則の対象外なので、jp-quality / NG 語 / 連続漢字 hook で skip 用に使う。
# 戻り値: 0=auto-memory 配下 / 1=配下でない
# usage: _is_auto_memory_path "$path"
_is_auto_memory_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/projects/"*"/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/agent-memory/"* ]] && return 0
  return 1
}

# 与えられた path が /plan コマンドの plan 保存 dir かどうかを判定する。
# 対象 dir:
#   - ~/.claude/plans/   (`/plan` コマンドの設計書出力先)
# plan は AI 自身の作業計画 (要件・Architecture・Phase 分解) であり、
# 外向き prose ではないため jp-quality / NG 語 hook の skip 対象にする。
# 戻り値: 0=plans 配下 / 1=配下でない
# usage: _is_plans_path "$path"
_is_plans_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/plans/"* ]] && return 0
  return 1
}

# memory file 判定: NG-DICTIONARY / private-name 等の文体 block を skip する対象 path
# canonical: CLAUDE.md § Memory write target + user 指示 (2026-06-30): memory save 時に NG word 検出を skip する
# 対象:
#   - ~/ai-tools/memory/         (ai-tools repo の memory write 先)
#   - ~/.claude/projects/*/memory/  (Claude Code auto-memory)
#   - ~/.claude/agent-memory/    (agent 共有 memory)
#   - */.serena/memories/        (Serena 旧 memory、書込自体は別 hook で block)
# usage: _is_memory_path "$path"
_is_memory_path() {
  local p="$1"
  [[ "$p" == "$HOME/ai-tools/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/projects/"*"/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/agent-memory/"* ]] && return 0
  [[ "$p" == *"/.serena/memories/"* ]] && return 0
  return 1
}

# 与えられた path が ~/.claude/references-private/ 配下かどうかを判定する。
# references-private は user 管理の private メモ dir。外向き prose 規則の対象外とする。
# 戻り値: 0=references-private 配下 / 1=配下でない
# usage: _is_references_private_path "$path"
_is_references_private_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/references-private/"* ]] && return 0
  return 1
}

# ai-tools repo 相対 path を取得する (prefix 除去後)。
# どの prefix にも match しない場合は空文字を出力して 1 を返す。
# usage: rel=$(_aitools_relpath "$path")
_aitools_relpath() {
  local p="$1"
  local prefix
  while IFS= read -r prefix; do
    if [[ "$p" == "${prefix}"* ]]; then
      printf '%s' "${p#"${prefix}"}"
      return 0
    fi
  done < <(_aitools_prefixes)
  return 1
}

# 実在する ai-tools repo dir を 1 つ返す (ghq 実 path 優先、symlink fallback)。
# どちらも存在しなければ ghq canonical path を返す (呼出側で -d チェック想定)。
# usage: dir=$(_aitools_dir)
_aitools_dir() {
  local ghq="$HOME/ghq/github.com/DaichiHoshina/ai-tools"
  local symlink="$HOME/ai-tools"
  if [[ -d "$ghq" ]]; then
    printf '%s' "$ghq"
  elif [[ -d "$symlink" ]]; then
    printf '%s' "$symlink"
  else
    printf '%s' "$ghq"
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
