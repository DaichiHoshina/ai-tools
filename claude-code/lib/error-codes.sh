#!/usr/bin/env bash
# =============================================================================
# error-codes.sh - 構造化エラーコード（Warning 7対応）
# カテゴリ別エラーコードとメッセージ管理
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/error-codes.sh
#   emit_error "E1001" "Session exceeded 2 hours"
#   error_json "E2001" "Lock acquisition failed"
#
# エラーコード体系:
#   E1xxx: タイムアウト関連
#   E2xxx: ロック関連
#   E3xxx: 進捗追跡関連
#   E4xxx: 入力検証関連
#   E5xxx: サンプリング関連
#
# =============================================================================

set -euo pipefail

# --- 重複読み込み防止 ---
if [[ "${_ERROR_CODES_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_ERROR_CODES_LOADED=true

# =============================================================================
# エラーコード定義
# =============================================================================

# エラーコードからメッセージを取得
# 引数:
#   $1: エラーコード（例: E1001）
# 出力: エラーメッセージ
get_error_message() {
    local code="$1"
    
    case "$code" in
        # E1xxx: タイムアウト
        E1001) echo "Session timeout" ;;
        E1002) echo "Task timeout" ;;
        E1003) echo "Loop interval violation" ;;
        
        # E2xxx: ロック
        E2001) echo "Lock acquisition failed" ;;
        E2002) echo "Lock release failed" ;;
        E2003) echo "Lock expired" ;;
        E2004) echo "Lock conflict detected" ;;
        E2005) echo "Lock owner mismatch" ;;
        
        # E3xxx: 進捗追跡
        E3001) echo "Progress file read error" ;;
        E3002) echo "Progress file write error" ;;
        E3003) echo "Progress directory creation failed" ;;
        E3004) echo "Progress output too large" ;;
        E3005) echo "Session progress not found" ;;
        
        # E4xxx: 入力検証
        E4001) echo "Invalid input parameter" ;;
        E4002) echo "Required parameter missing" ;;
        E4003) echo "Parameter out of range" ;;
        E4004) echo "Invalid file path" ;;
        E4005) echo "Path traversal detected" ;;
        
        # E5xxx: サンプリング
        E5001) echo "Invalid sample rate" ;;
        E5002) echo "Seed generation failed" ;;
        E5003) echo "Sample size calculation error" ;;
        E5004) echo "Empty input list" ;;
        E5005) echo "Sampling algorithm error" ;;
        
        # 未定義コード
        *) echo "Unknown error" ;;
    esac
}

# エラーカテゴリを取得
# 引数:
#   $1: エラーコード（例: E1001）
# 出力: カテゴリ名
get_error_category() {
    local code="$1"
    local prefix="${code:1:1}"  # E1001 → 1
    
    case "$prefix" in
        1) echo "Timeout" ;;
        2) echo "Lock" ;;
        3) echo "Progress" ;;
        4) echo "Input" ;;
        5) echo "Sampling" ;;
        *) echo "Unknown" ;;
    esac
}

# =============================================================================
# エラー出力関数
# =============================================================================

# エラーメッセージをstderrに出力
# 引数:
#   $1: エラーコード（例: E1001）
#   $2: 詳細情報（オプション）
# 出力: stderr に "ERROR [E1001]: Session timeout - detail" 形式
emit_error() {
    local code="$1"
    local detail="${2:-}"
    
    local message
    message=$(get_error_message "$code")
    
    if [[ -n "$detail" ]]; then
        echo "ERROR [$code]: $message - $detail" >&2
    else
        echo "ERROR [$code]: $message" >&2
    fi
}

# エラー情報をJSON形式で出力
# 引数:
#   $1: エラーコード（例: E1001）
#   $2: 詳細情報（オプション）
# 出力: JSON形式のエラー情報
error_json() {
    local code="$1"
    local detail="${2:-}"
    
    local message
    message=$(get_error_message "$code")
    
    local category
    category=$(get_error_category "$code")
    
    # JSON特殊文字をエスケープ
    detail=$(echo "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
    detail="${detail%\\n}"  # 末尾の\nを削除
    
    cat <<EOF
{
  "error": {
    "code": "$code",
    "category": "$category",
    "message": "$message",
    "detail": "$detail"
  }
}
EOF
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# エラーコード一覧を表示
list_error_codes() {
    echo "Error Code Reference:"
    echo ""
    echo "E1xxx: Timeout"
    echo "  E1001: Session timeout"
    echo "  E1002: Task timeout"
    echo "  E1003: Loop interval violation"
    echo ""
    echo "E2xxx: Lock"
    echo "  E2001: Lock acquisition failed"
    echo "  E2002: Lock release failed"
    echo "  E2003: Lock expired"
    echo "  E2004: Lock conflict detected"
    echo "  E2005: Lock owner mismatch"
    echo ""
    echo "E3xxx: Progress"
    echo "  E3001: Progress file read error"
    echo "  E3002: Progress file write error"
    echo "  E3003: Progress directory creation failed"
    echo "  E3004: Progress output too large"
    echo "  E3005: Session progress not found"
    echo ""
    echo "E4xxx: Input"
    echo "  E4001: Invalid input parameter"
    echo "  E4002: Required parameter missing"
    echo "  E4003: Parameter out of range"
    echo "  E4004: Invalid file path"
    echo "  E4005: Path traversal detected"
    echo ""
    echo "E5xxx: Sampling"
    echo "  E5001: Invalid sample rate"
    echo "  E5002: Seed generation failed"
    echo "  E5003: Sample size calculation error"
    echo "  E5004: Empty input list"
    echo "  E5005: Sampling algorithm error"
}
