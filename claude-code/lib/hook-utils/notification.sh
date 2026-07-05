#!/bin/bash
# =============================================================================
# hook-utils / notification module
# =============================================================================
if [[ "${_HOOK_UTILS_NOTIFICATION_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_NOTIFICATION_LOADED=1

# Stop/StopFailure共通の通知送信
# Usage: send_stop_notification "$INPUT" "タイトル接尾辞" "サウンド名" "ntfyタグ" "ntfy優先度"
send_stop_notification() {
  # 明示 OFF (CLAUDE_STOP_NOTIFY=0) の時だけ関数側でも早期 return する。
  # 通常は caller 側 (hooks/stop.sh / stop-failure.sh) の gate 判定に従う。
  if [[ "${CLAUDE_STOP_NOTIFY:-1}" == "0" ]]; then
    return 0
  fi

  local input="$1"
  local title_suffix="${2:-}"
  local sound="${3:-Glass}"
  local ntfy_tags="${4:-robot}"
  local ntfy_priority="${5:-default}"

  # user turn 以外からの呼び出しを skip する (実測 2026-07-05 /tmp/stop-hook-env-probe):
  # - session_id なし = bats fixture / 手動 smoke (実 event は必ず session_id を持つ)
  # - cursor_version あり = Claude Code 以外の editor (Cursor) が同 script を実行した場合
  # - Stop event で background_tasks に running あり = agent / background shell 実行中。
  #   task 完了後に main loop が再開し、次の user turn の Stop で改めて通知する
  if printf '%s' "$input" | jq -e '
      (has("session_id") | not)
      or has("cursor_version")
      or ((.hook_event_name == "Stop")
          and ([.background_tasks[]? | select(.status == "running")] | length > 0))
    ' >/dev/null 2>&1; then
    return 0
  fi

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
