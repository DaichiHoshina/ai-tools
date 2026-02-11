#!/usr/bin/env bash
# Test script for pre-skill-use.sh

set -euo pipefail

HOOK_SCRIPT="$(dirname "$0")/pre-skill-use.sh"
SESSION_STATE_FILE="$HOME/.claude/session-state.json"

# テスト用セッションID固定
export CLAUDE_SESSION_ID="test-session-123"

# テスト用ヘルパー関数
print_test() {
    echo ""
    echo "=========================================="
    echo "TEST: $1"
    echo "=========================================="
}

print_result() {
    echo "Result: $1"
}

# セッション状態ファイルをクリーンアップ
cleanup_session_state() {
    if [ -f "$SESSION_STATE_FILE" ]; then
        rm "$SESSION_STATE_FILE"
        echo "Cleaned up session-state.json"
    fi
}

# ===== Test 1: スキル名が空の場合 =====
print_test "Empty skill name"
cleanup_session_state

INPUT='{"skill": ""}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

if [ "$RESULT" = "{}" ]; then
    echo "✅ PASS: Returns empty object when skill name is empty"
else
    echo "❌ FAIL: Expected '{}', got '$RESULT'"
fi

# ===== Test 2: backend-dev スキル（初回読み込み） =====
print_test "backend-dev skill (first load)"
cleanup_session_state

INPUT='{"skill": "backend-dev"}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

# systemMessageに"Auto-loading guidelines"が含まれることを確認
if echo "$RESULT" | jq -e '.systemMessage | contains("Auto-loading")' > /dev/null 2>&1; then
    echo "✅ PASS: Auto-loading message found"
else
    echo "❌ FAIL: Auto-loading message not found"
fi

# session-state.jsonが作成され、golang, commonが記録されることを確認
if [ -f "$SESSION_STATE_FILE" ]; then
    LOADED=$(jq -r '.loaded_guidelines | join(",")' "$SESSION_STATE_FILE")
    echo "Loaded guidelines: $LOADED"

    if echo "$LOADED" | grep -q "golang" && echo "$LOADED" | grep -q "common"; then
        echo "✅ PASS: golang and common are recorded in session-state.json"
    else
        echo "❌ FAIL: Expected golang and common, got '$LOADED'"
    fi
else
    echo "❌ FAIL: session-state.json not created"
fi

# ===== Test 3: backend-dev スキル（2回目読み込み - スキップされるべき） =====
print_test "backend-dev skill (second load - should skip)"

INPUT='{"skill": "backend-dev"}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

# 2回目は何も読み込まれないはず
if [ "$RESULT" = "{}" ]; then
    echo "✅ PASS: No re-loading on second execution"
else
    echo "❌ FAIL: Expected '{}', got '$RESULT'"
fi

# ===== Test 4: react-best-practices スキル（追加読み込み） =====
print_test "react-best-practices skill (additional load)"

INPUT='{"skill": "react-best-practices"}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

# nextjs-reactが追加されるはず（commonは既に読み込み済み）
if echo "$RESULT" | jq -e '.systemMessage | contains("Auto-loading")' > /dev/null 2>&1; then
    echo "✅ PASS: Auto-loading message found for react-best-practices"
else
    echo "⚠️ WARN: Auto-loading message not found (may be expected if all guidelines already loaded)"
fi

if [ -f "$SESSION_STATE_FILE" ]; then
    LOADED=$(jq -r '.loaded_guidelines | join(",")' "$SESSION_STATE_FILE")
    echo "Loaded guidelines: $LOADED"

    # common, golang, nextjs-react, tailwindが含まれることを確認
    if echo "$LOADED" | grep -q "common" && echo "$LOADED" | grep -q "golang" && echo "$LOADED" | grep -q "nextjs-react"; then
        echo "✅ PASS: All guidelines are accumulated in session-state.json"
    else
        echo "❌ FAIL: Expected common, golang, nextjs-react in session state, got '$LOADED'"
    fi
fi

# ===== Test 5: 存在しないスキル =====
print_test "Non-existent skill"

INPUT='{"skill": "non-existent-skill"}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

# 警告メッセージが含まれることを確認
if echo "$RESULT" | jq -e '.systemMessage | contains("not found")' > /dev/null 2>&1; then
    echo "✅ PASS: Warning message for non-existent skill"
else
    echo "❌ FAIL: Expected warning message, got '$RESULT'"
fi

# ===== Test 6: requires-guidelinesが定義されていないスキル =====
print_test "Skill without requires-guidelines"

# cleanup-enforcementはrequires-guidelines: []
INPUT='{"skill": "cleanup-enforcement"}'
RESULT=$(echo "$INPUT" | "$HOOK_SCRIPT")
print_result "$RESULT"

if [ "$RESULT" = "{}" ]; then
    echo "✅ PASS: Returns empty object when requires-guidelines is empty"
else
    echo "❌ FAIL: Expected '{}', got '$RESULT'"
fi

# ===== Cleanup =====
print_test "Cleanup"
cleanup_session_state
echo "✅ All tests completed"
