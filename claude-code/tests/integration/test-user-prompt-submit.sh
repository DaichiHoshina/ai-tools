#!/usr/bin/env bash
# user-prompt-submit.sh テストスイート
# P1実装の検出パターンを検証

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/user-prompt-submit.sh"
TEST_PASSED=0
TEST_FAILED=0

# テスト実行関数
run_test() {
  local test_name="$1"
  local input_json="$2"
  local expected_pattern="$3"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🧪 Test: $test_name"

  local output
  output=$(echo "$input_json" | bash "$HOOK_SCRIPT" 2>&1 || true)

  if echo "$output" | grep -qE "$expected_pattern"; then
    echo "✅ PASS"
    TEST_PASSED=$((TEST_PASSED + 1))
  else
    echo "❌ FAIL"
    echo "Expected pattern: $expected_pattern"
    echo "Actual output: $output"
    TEST_FAILED=$((TEST_FAILED + 1))
  fi
  echo ""
}

echo "========================================="
echo "user-prompt-submit.sh テスト開始"
echo "========================================="
echo ""

# ========================================
# 1. キーワード検出テスト（既存機能）
# ========================================

run_test "キーワード検出: Go言語" \
  '{"prompt": "Go言語でAPIを実装してください"}' \
  "backend-dev|golang"

run_test "キーワード検出: TypeScript" \
  '{"prompt": "TypeScriptでバックエンドを作る"}' \
  "backend-dev|typescript"

run_test "キーワード検出: React" \
  '{"prompt": "Reactコンポーネントを作成"}' \
  "react-best-practices|react"

run_test "キーワード検出: Docker" \
  '{"prompt": "Dockerfileを最適化したい"}' \
  "container-ops"

run_test "キーワード検出: Kubernetes" \
  '{"prompt": "k8sのdeploymentを修正"}' \
  "kubernetes"

run_test "キーワード検出: レビュー" \
  '{"prompt": "コードレビューをお願いします"}' \
  "comprehensive-review"

run_test "キーワード検出: セキュリティ" \
  '{"prompt": "セキュリティの脆弱性をチェック"}' \
  "comprehensive-review"

# ========================================
# 2. エラーログ検出テスト（新機能）
# ========================================

run_test "エラー検出: Docker接続エラー" \
  '{"prompt": "Cannot connect to the Docker daemon が出ます"}' \
  "container-ops"

run_test "エラー検出: Kubernetes Pod失敗" \
  '{"prompt": "CrashLoopBackOff エラーが発生しています"}' \
  "kubernetes"

run_test "エラー検出: TypeScript型エラー" \
  '{"prompt": "Property does not exist on type エラー"}' \
  "backend-dev"

run_test "エラー検出: Go未定義エラー" \
  '{"prompt": "undefined: myFunction というエラー"}' \
  "backend-dev"

run_test "エラー検出: CVE脆弱性" \
  '{"prompt": "CVE-2024-1234 の対応が必要"}' \
  "comprehensive-review"

# ========================================
# 3. 複合検出テスト
# ========================================

run_test "複合: Go + API設計" \
  '{"prompt": "Go言語でREST APIを設計"}' \
  "backend-dev.*api-design|api-design.*backend-dev"

run_test "複合: TypeScript + セキュリティ" \
  '{"prompt": "TypeScriptのセキュリティレビュー"}' \
  "backend-dev.*security|security.*backend-dev"

run_test "複合: React + テスト" \
  '{"prompt": "Reactコンポーネントのテストを追加"}' \
  "react.*test|test.*react"

# ========================================
# 4. 検出なしテスト
# ========================================

run_test "検出なし: 一般的な質問" \
  '{"prompt": "今日の天気はどうですか？"}' \
  "^$"

# ========================================
# テスト結果サマリー
# ========================================

echo "========================================="
echo "テスト結果サマリー"
echo "========================================="
echo "✅ PASSED: $TEST_PASSED"
echo "❌ FAILED: $TEST_FAILED"
echo "TOTAL: $((TEST_PASSED + TEST_FAILED))"
echo ""

if [ $TEST_FAILED -eq 0 ]; then
  echo "🎉 すべてのテストが成功しました！"
  exit 0
else
  echo "⚠️ 失敗したテストがあります。上記を確認してください。"
  exit 1
fi
