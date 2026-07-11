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
# 秘匿情報マスキング関数
# ========================================
#
# 用途: settings.json等のコンテンツから秘匿情報をマスク
# sync.sh等から呼び出し
#
# 引数:
#   $1: マスク対象のコンテンツ文字列
# 出力: マスク済みコンテンツ（stdout）
#
mask_secrets() {
    local content="$1"
    local env_file="${ENV_FILE:-$HOME/.env}"

    # HOMEパスをマスク
    content="${content//$HOME/__HOME__}"

    # Node.jsパスをマスク
    local node_path
    node_path="$(dirname "$(which node)" 2>/dev/null || echo "/usr/local/bin")"
    content="${content//$node_path/__NODE_PATH__}"

    # .envからキー名ベースで検出（*_KEY, *_TOKEN, *_SECRET, *_PASSWORD）
    if [ -f "$env_file" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            if [[ "$key" =~ _(KEY|TOKEN|SECRET|PASSWORD|URL|EMAIL)$ ]] && [ -n "$value" ]; then
                content="${content//$value/__${key}__}"
            fi
        done < "$env_file"
    fi

    # 既知のトークンパターンをフォールバックマスク
    content=$(echo "$content" | sed -E 's/ATATT3x[A-Za-z0-9_=-]+/__CONFLUENCE_API_TOKEN__/g')
    content=$(echo "$content" | sed -E 's/sk-proj-[A-Za-z0-9_-]+/__OPENAI_API_KEY__/g')
    content=$(echo "$content" | sed -E 's/BSA[A-Za-z0-9_-]+/__BRAVE_API_KEY__/g')

    echo "$content"
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

    echo "=== テスト完了 ==="
fi
