#!/bin/bash
# =============================================================================
# Hook共通ユーティリティ
# =============================================================================
set -euo pipefail

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
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
  fi
}

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

# Stop/StopFailure共通の通知送信
# Usage: send_stop_notification "$INPUT" "タイトル接尾辞" "サウンド名" "ntfyタグ" "ntfy優先度"
send_stop_notification() {
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

  local notify_msg="${last_msg:0:80}"
  if [ ${#last_msg} -gt 80 ]; then
    notify_msg="${notify_msg}..."
  fi

  local title="Claude Code [${project_name}]"
  if [ -n "$title_suffix" ]; then
    title="${title} ${title_suffix}"
  fi

  if command -v terminal-notifier &>/dev/null; then
    terminal-notifier \
      -title "$title" \
      -message "${notify_msg}" \
      -contentImage "$HOME/.claude/claude-icon.png" \
      -sound "$sound" \
      -execute "osascript -e 'tell application \"iTerm\" to activate'" &
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
  wt_id=$(echo "${target_dir}" | sed 's|/|-|g')
  main_id=$(echo "${main_repo}" | sed 's|/|-|g')

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
