#!/usr/bin/env bash
# security-functions.sh - セキュリティ共通関数ライブラリ
# Description: OWASP対策を含むセキュアなスクリプト実装のための共通関数

set -euo pipefail

# ========================================
# sed特殊文字エスケープ関数（OWASP A03対策）
# ========================================
#
# 用途: sed置換時に特殊文字（/, &, \）を安全にエスケープ
# 対策: コマンドインジェクション脆弱性の防止
#
# 使用例:
#   escaped_url=$(escape_for_sed "$GITLAB_API_URL")
#   sed "s|${escaped_url}|replacement|g" file.txt
#
escape_for_sed() {
    local input="$1"

    # sed置換パターンで問題となる特殊文字をエスケープ
    # /  -> \/  (パターン区切り文字)
    # &  -> \&  (マッチした文字列の参照)
    # \  -> \\ (エスケープ文字自体)
    printf '%s\n' "$input" | sed -e 's/[\/&]/\\&/g'
}

# ========================================
# 安全なトークン入力関数（OWASP A02/A07対策）
# ========================================
#
# 用途: APIトークン等の秘密情報を安全に入力・保存
# 対策:
#   - メモリ保持時間の最小化
#   - コアダンプ/メモリダンプ時の露出防止
#   - ファイルパーミッション適切化（600）
#
# 使用例:
#   secure_token_input "GITLAB_PERSONAL_ACCESS_TOKEN" "$ENV_FILE"
#
# 引数:
#   $1: 環境変数名（例: GITLAB_PERSONAL_ACCESS_TOKEN）
#   $2: .envファイルパス
#
secure_token_input() {
    local env_key="$1"
    local env_file="$2"
    local token=""

    # -s フラグで入力中のecho抑制（画面に表示しない）
    # -r フラグでバックスラッシュをそのまま扱う
    read -srp "${env_key}: " token
    echo  # 改行

    if [ -n "$token" ]; then
        # トークンをメモリに保持せず即座にファイルに書き込み
        echo "${env_key}=${token}" >> "$env_file"

        # メモリから即座に削除（コアダンプ対策）
        unset token

        # .envファイルのパーミッション設定（所有者のみ読み書き可能）
        chmod 600 "$env_file"

        echo "✅ ${env_key} を安全に保存しました"
    else
        echo "⚠️ ${env_key} は空のためスキップしました"
    fi
}

# ========================================
# 入力サイズ検証関数（DoS攻撃防止）
# ========================================
#
# 用途: stdin入力のサイズを制限
# 対策: 無制限入力によるDoS攻撃の防止
#
# 使用例:
#   input=$(read_stdin_with_limit 1048576)  # 1MB制限
#
# 引数:
#   $1: 最大バイト数（デフォルト: 1MB = 1048576）
#
# 戻り値:
#   0: 成功
#   1: サイズ超過
#
read_stdin_with_limit() {
    local max_bytes="${1:-1048576}"  # デフォルト1MB
    local input

    # head -c で指定バイト数まで読み込み
    input=$(cat | head -c "$max_bytes")

    # サイズチェック
    if [ ${#input} -ge "$max_bytes" ]; then
        echo "❌ Error: Input size exceeds limit (${max_bytes} bytes)" >&2
        return 1
    fi

    echo "$input"
    return 0
}

# ========================================
# JSON形式検証関数
# ========================================
#
# 用途: JSON形式の妥当性検証
# 対策: 不正な入力によるパースエラー・セキュリティリスク防止
#
# 使用例:
#   if validate_json "$input"; then
#       # JSON処理続行
#   fi
#
# 引数:
#   $1: 検証対象のJSON文字列
#
# 戻り値:
#   0: 有効なJSON
#   1: 無効なJSON
#
validate_json() {
    local json="$1"

    if ! command -v jq &> /dev/null; then
        echo "⚠️ Warning: jq not found, skipping JSON validation" >&2
        return 0  # jqがない場合はスキップ
    fi

    # jq empty で形式チェック（出力なし、エラーのみ）
    if echo "$json" | jq empty > /dev/null 2>&1; then
        return 0
    else
        echo "❌ Error: Invalid JSON format" >&2
        return 1
    fi
}

# ========================================
# ファイルパス検証関数（パストラバーサル防止）
# ========================================
#
# 用途: ファイルパスの安全性検証
# 対策: シンボリックリンク攻撃・ディレクトリトラバーサル防止
#
# 使用例:
#   if validate_file_path "$CLAUDE_DIR" "$HOME/.claude"; then
#       # 安全なパスとして処理続行
#   fi
#
# 引数:
#   $1: 検証対象パス
#   $2: 許可する親ディレクトリ（オプション）
#
# 戻り値:
#   0: 安全なパス
#   1: 危険なパス
#
validate_file_path() {
    local target_path="$1"
    local allowed_parent="${2:-}"

    # ディレクトリが存在しない場合
    if [ ! -e "$target_path" ]; then
        echo "❌ Error: Path does not exist: $target_path" >&2
        return 1
    fi

    # シンボリックリンクを解決して実際のパスを取得
    local real_path
    real_path=$(cd "$target_path" 2>/dev/null && pwd -P)

    if [ -z "$real_path" ]; then
        echo "❌ Error: Cannot access path: $target_path" >&2
        return 1
    fi

    # 親ディレクトリ制約がある場合はチェック
    if [ -n "$allowed_parent" ]; then
        if [[ ! "$real_path" =~ ^"$allowed_parent" ]]; then
            echo "❌ Error: Path outside allowed directory: $real_path" >&2
            return 1
        fi
    fi

    return 0
}

# ========================================
# 使用例（実行時のテスト）
# ========================================
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "=== security-functions.sh テスト ==="
    echo ""

    echo "1. escape_for_sed テスト"
    test_url="https://example.com/api?key=value&id=123"
    escaped=$(escape_for_sed "$test_url")
    echo "  Input:  $test_url"
    echo "  Output: $escaped"
    echo ""

    echo "2. validate_json テスト"
    valid_json='{"key": "value"}'
    invalid_json='{invalid json}'

    if validate_json "$valid_json"; then
        echo "  ✅ Valid JSON: $valid_json"
    fi

    if ! validate_json "$invalid_json"; then
        echo "  ✅ Invalid JSON detected: $invalid_json"
    fi
    echo ""

    echo "3. validate_file_path テスト"
    if validate_file_path "$HOME" "$HOME"; then
        echo "  ✅ Home directory is valid"
    fi
    echo ""

    echo "=== テスト完了 ==="
fi
