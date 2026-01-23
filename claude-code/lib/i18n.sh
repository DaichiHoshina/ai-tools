#!/usr/bin/env bash
# i18n.sh - 国際化（多言語）サポートライブラリ
# Description: 日本語/英語メッセージの統一管理（Warning #6対策）

set -euo pipefail

# ========================================
# 言語設定
# ========================================
# デフォルト: 日本語
# 環境変数 LANGUAGE で変更可能（ja, en）
export LANGUAGE="${LANGUAGE:-ja}"

# ========================================
# 日本語メッセージ定義
# ========================================
declare -gA messages_ja=(
    # エラーメッセージ
    [ERROR_STATUSLINE]="⚠️ ステータス表示に失敗: コンテキストウィンドウ情報が利用不可です"
    [ERROR_PARSING]="❌ JSON解析エラー: 入力データが不正です"
    [ERROR_FILE_NOT_FOUND]="❌ ファイルが見つかりません: %s"
    [ERROR_PERMISSION]="❌ パーミッションエラー: %s へのアクセスが拒否されました"
    [ERROR_NETWORK]="❌ ネットワークエラー: 接続に失敗しました"
    [ERROR_TIMEOUT]="⏱️ タイムアウト: 処理時間が制限を超えました"
    [ERROR_UNKNOWN]="❌ 予期しないエラーが発生しました"

    # 情報メッセージ
    [INFO_STACK_DETECTED]="🔍 技術スタック検出: %s"
    [INFO_SKILL_RECOMMENDED]="💡 推奨スキル: %s"
    [INFO_PROCESSING]="⏳ 処理中..."
    [INFO_COMPLETE]="✅ 完了しました"
    [INFO_SAVED]="✅ 保存しました: %s"

    # 警告メッセージ
    [WARN_TOKEN_HIGH]="⚠️ トークン使用率が高くなっています（%d%%）"
    [WARN_TOKEN_CRITICAL]="🔴 トークン使用率が危険域です（%d%%） - /reload を推奨"
    [WARN_AUTO_FORMAT]="🔶 kenron:Boundary射 - 自動整形（10原則:自動処理禁止）"
    [WARN_DEPRECATED]="⚠️ 非推奨: %s は将来のバージョンで削除されます"

    # 確認メッセージ
    [CONFIRM_CONTINUE]="続行しますか？ [Y/n]"
    [CONFIRM_DELETE]="本当に削除しますか？ この操作は取り消せません [Y/n]"
    [CONFIRM_OVERWRITE]="ファイルを上書きしますか？ [Y/n]"

    # 成功メッセージ
    [SUCCESS_INSTALL]="✅ インストールが完了しました"
    [SUCCESS_SYNC]="✅ 同期が完了しました"
    [SUCCESS_TOKEN_SAVED]="✅ トークンを安全に保存しました"

    # ヘルプメッセージ
    [HELP_RELOAD]="💡 復旧方法:"
    [HELP_STEP_1]="  1. /reload を実行"
    [HELP_STEP_2]="  2. ~/.claude/sync.sh from-local で更新"
    [HELP_STEP_3]="  3. Claude Code を再起動"

    # Git関連
    [GIT_STATUS_CLEAN]="作業ディレクトリはクリーンです"
    [GIT_STATUS_MODIFIED]="変更されたファイル: %s"
    [GIT_COMMIT_SUCCESS]="✅ コミットしました: %s"
)

# ========================================
# 英語メッセージ定義
# ========================================
declare -gA messages_en=(
    # Error messages
    [ERROR_STATUSLINE]="⚠️ Status display failed: Context window information unavailable"
    [ERROR_PARSING]="❌ JSON parsing error: Invalid input data"
    [ERROR_FILE_NOT_FOUND]="❌ File not found: %s"
    [ERROR_PERMISSION]="❌ Permission denied: Access to %s denied"
    [ERROR_NETWORK]="❌ Network error: Connection failed"
    [ERROR_TIMEOUT]="⏱️ Timeout: Processing time exceeded limit"
    [ERROR_UNKNOWN]="❌ An unexpected error occurred"

    # Info messages
    [INFO_STACK_DETECTED]="🔍 Tech stack detected: %s"
    [INFO_SKILL_RECOMMENDED]="💡 Recommended skill: %s"
    [INFO_PROCESSING]="⏳ Processing..."
    [INFO_COMPLETE]="✅ Completed"
    [INFO_SAVED]="✅ Saved: %s"

    # Warning messages
    [WARN_TOKEN_HIGH]="⚠️ Token usage is high (%d%%)"
    [WARN_TOKEN_CRITICAL]="🔴 Token usage is critical (%d%%) - /reload recommended"
    [WARN_AUTO_FORMAT]="🔶 kenron:Boundary - Auto-formatting (Rule 10: No auto-processing)"
    [WARN_DEPRECATED]="⚠️ Deprecated: %s will be removed in future versions"

    # Confirmation messages
    [CONFIRM_CONTINUE]="Continue? [Y/n]"
    [CONFIRM_DELETE]="Really delete? This operation cannot be undone [Y/n]"
    [CONFIRM_OVERWRITE]="Overwrite file? [Y/n]"

    # Success messages
    [SUCCESS_INSTALL]="✅ Installation completed"
    [SUCCESS_SYNC]="✅ Synchronization completed"
    [SUCCESS_TOKEN_SAVED]="✅ Token saved securely"

    # Help messages
    [HELP_RELOAD]="💡 Recovery steps:"
    [HELP_STEP_1]="  1. Run /reload"
    [HELP_STEP_2]="  2. Update with ~/.claude/sync.sh from-local"
    [HELP_STEP_3]="  3. Restart Claude Code"

    # Git related
    [GIT_STATUS_CLEAN]="Working directory is clean"
    [GIT_STATUS_MODIFIED]="Modified files: %s"
    [GIT_COMMIT_SUCCESS]="✅ Committed: %s"
)

# ========================================
# メッセージ取得関数
# ========================================
#
# 使用例:
#   msg "ERROR_STATUSLINE"
#   msg "INFO_STACK_DETECTED" "go, typescript"
#   msg "WARN_TOKEN_HIGH" 85
#
# 引数:
#   $1: メッセージキー
#   $@: printf形式のパラメータ（オプション）
#
# 戻り値:
#   ローカライズされたメッセージ
#
msg() {
    local key="$1"
    shift

    # 言語別のメッセージ配列を参照
    local message_var="messages_${LANGUAGE}[$key]"

    # 配列から値を取得（nameref使用）
    local message
    if [ "$LANGUAGE" = "ja" ]; then
        message="${messages_ja[$key]:-}"
    else
        message="${messages_en[$key]:-}"
    fi

    # メッセージが見つからない場合はキーをそのまま表示
    if [ -z "$message" ]; then
        echo "[$key]"
        return 1
    fi

    # パラメータがある場合はprintf形式で展開
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "$message\n" "$@"
    else
        echo "$message"
    fi
}

# ========================================
# 言語切り替え関数
# ========================================
#
# 使用例:
#   set_language "en"
#
# 引数:
#   $1: 言語コード（ja, en）
#
set_language() {
    local lang="$1"

    case "$lang" in
        ja|en)
            export LANGUAGE="$lang"
            ;;
        *)
            echo "⚠️ Warning: Unsupported language '$lang'. Using 'ja' as default." >&2
            export LANGUAGE="ja"
            ;;
    esac
}

# ========================================
# エラー出力ヘルパー関数
# ========================================
#
# 使用例:
#   error_msg "ERROR_FILE_NOT_FOUND" "/path/to/file"
#
# 引数:
#   $1: メッセージキー
#   $@: printf形式のパラメータ（オプション）
#
error_msg() {
    msg "$@" >&2
}

# ========================================
# 使用例（実行時のテスト）
# ========================================
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "=== i18n.sh テスト ==="
    echo ""

    echo "1. 日本語メッセージテスト"
    set_language "ja"
    msg "ERROR_STATUSLINE"
    msg "INFO_STACK_DETECTED" "go, typescript"
    msg "WARN_TOKEN_HIGH" 85
    echo ""

    echo "2. 英語メッセージテスト"
    set_language "en"
    msg "ERROR_STATUSLINE"
    msg "INFO_STACK_DETECTED" "go, typescript"
    msg "WARN_TOKEN_HIGH" 85
    echo ""

    echo "3. エラーメッセージテスト（stderr）"
    error_msg "ERROR_FILE_NOT_FOUND" "/tmp/missing-file.txt"
    echo ""

    echo "4. 存在しないキーテスト"
    msg "UNKNOWN_KEY"
    echo ""

    echo "=== テスト完了 ==="
fi
