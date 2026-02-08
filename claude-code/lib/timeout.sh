#!/usr/bin/env bash
# =============================================================================
# timeout.sh - タイムアウト機構（Critical 1対応）
# 自律実行時のセッション・タスク・ループタイムアウト管理
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/timeout.sh
#   start=$(get_epoch)
#   if is_timed_out "$start" 7200; then
#     echo "Timeout!"
#   fi
#
# 環境変数:
#   TIMEOUT_SESSION_SECONDS=7200   # セッションタイムアウト（デフォルト2時間）
#   TIMEOUT_TASK_SECONDS=1800      # タスクタイムアウト（デフォルト30分）
#   TIMEOUT_LOOP_MIN_INTERVAL=300  # ループ最小間隔（デフォルト5分）
#
# =============================================================================

set -euo pipefail

# --- 重複読み込み防止 ---
if [[ "${_TIMEOUT_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_TIMEOUT_LOADED=true

# --- デフォルト値 ---
: "${TIMEOUT_SESSION_SECONDS:=7200}"    # 2時間
: "${TIMEOUT_TASK_SECONDS:=1800}"       # 30分
: "${TIMEOUT_LOOP_MIN_INTERVAL:=300}"   # 5分

# =============================================================================
# 基本関数
# =============================================================================

# Unix epoch秒を取得
# 戻り値: epoch秒（整数）
get_epoch() {
    date +%s
}

# タイムアウト判定
# 引数:
#   $1: 開始時刻（epoch秒）
#   $2: 制限時間（秒）
# 戻り値: 0=タイムアウト, 1=未タイムアウト
is_timed_out() {
    local start="$1"
    local limit="$2"
    local now
    now=$(get_epoch)
    
    local elapsed=$((now - start))
    
    if [[ $elapsed -ge $limit ]]; then
        return 0  # タイムアウト
    else
        return 1  # 未タイムアウト
    fi
}

# 残り時間を秒で取得
# 引数:
#   $1: 開始時刻（epoch秒）
#   $2: 制限時間（秒）
# 戻り値: 残り時間（秒、負の場合は0）
get_remaining_seconds() {
    local start="$1"
    local limit="$2"
    local now
    now=$(get_epoch)
    
    local elapsed=$((now - start))
    local remaining=$((limit - elapsed))
    
    if [[ $remaining -lt 0 ]]; then
        echo "0"
    else
        echo "$remaining"
    fi
}

# 残り時間を人間可読フォーマットに変換
# 引数:
#   $1: 残り時間（秒）
# 出力: "1h02m03s" 形式
format_remaining() {
    local seconds="$1"
    
    if [[ $seconds -le 0 ]]; then
        echo "0s"
        return
    fi
    
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    local result=""
    
    if [[ $hours -gt 0 ]]; then
        result="${hours}h"
    fi
    
    if [[ $minutes -gt 0 ]] || [[ $hours -gt 0 ]]; then
        if [[ $hours -gt 0 ]]; then
            result="${result}$(printf '%02d' $minutes)m"
        else
            result="${result}${minutes}m"
        fi
    fi
    
    if [[ $hours -gt 0 ]] || [[ $minutes -gt 0 ]]; then
        result="${result}$(printf '%02d' $secs)s"
    else
        result="${result}${secs}s"
    fi
    
    echo "$result"
}

# =============================================================================
# セッション・タスクタイムアウト
# =============================================================================

# セッションタイムアウトチェック
# 引数:
#   $1: セッション開始時刻（epoch秒）
# 戻り値: 0=タイムアウト, 1=未タイムアウト
check_session_timeout() {
    local start="$1"
    is_timed_out "$start" "$TIMEOUT_SESSION_SECONDS"
}

# タスクタイムアウトチェック
# 引数:
#   $1: タスク開始時刻（epoch秒）
# 戻り値: 0=タイムアウト, 1=未タイムアウト
check_task_timeout() {
    local start="$1"
    is_timed_out "$start" "$TIMEOUT_TASK_SECONDS"
}

# ループ間隔強制（最後の実行から最小間隔経過までスリープ）
# 引数:
#   $1: 最後の実行時刻（epoch秒）
# 戻り値: なし（必要に応じてスリープ）
enforce_loop_interval() {
    local last="$1"
    local now
    now=$(get_epoch)
    
    local elapsed=$((now - last))
    local wait_time=$((TIMEOUT_LOOP_MIN_INTERVAL - elapsed))
    
    if [[ $wait_time -gt 0 ]]; then
        sleep "$wait_time"
    fi
}

# =============================================================================
# フック連携用JSON出力
# =============================================================================

# タイムアウト状態をJSON形式で出力
# 引数:
#   $1: セッション開始時刻（epoch秒）
#   $2: タスク開始時刻（epoch秒、オプション）
# 出力: JSON形式のステータス
timeout_status_json() {
    local session_start="$1"
    local task_start="${2:-$session_start}"
    
    local now
    now=$(get_epoch)
    
    local session_elapsed=$((now - session_start))
    local task_elapsed=$((now - task_start))
    
    local session_remaining
    session_remaining=$(get_remaining_seconds "$session_start" "$TIMEOUT_SESSION_SECONDS")
    
    local task_remaining
    task_remaining=$(get_remaining_seconds "$task_start" "$TIMEOUT_TASK_SECONDS")
    
    local session_timeout="false"
    if check_session_timeout "$session_start"; then
        session_timeout="true"
    fi
    
    local task_timeout="false"
    if check_task_timeout "$task_start"; then
        task_timeout="true"
    fi
    
    cat <<EOF
{
  "session": {
    "elapsed_seconds": $session_elapsed,
    "remaining_seconds": $session_remaining,
    "remaining_formatted": "$(format_remaining "$session_remaining")",
    "timed_out": $session_timeout
  },
  "task": {
    "elapsed_seconds": $task_elapsed,
    "remaining_seconds": $task_remaining,
    "remaining_formatted": "$(format_remaining "$task_remaining")",
    "timed_out": $task_timeout
  }
}
EOF
}
