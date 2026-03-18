#!/bin/bash
# =============================================================================
# Hook共通ユーティリティ
# =============================================================================
set -euo pipefail

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
