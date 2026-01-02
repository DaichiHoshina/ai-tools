#!/usr/bin/env bash
# UserPromptSubmit Hook - 8原則自動化の中核
# プロンプトから技術スタックを自動検出し、適切なガイドライン・スキルを推奨

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# プロンプトを取得
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# 技術スタック検出
DETECTED_LANGS=""
DETECTED_SKILLS=""
ADDITIONAL_CONTEXT=""

# 言語検出
if echo "$PROMPT" | grep -qiE '\bgo\b|golang|\.go\b|go\.mod'; then
  DETECTED_LANGS="${DETECTED_LANGS}go,"
  DETECTED_SKILLS="${DETECTED_SKILLS}go-backend,"
fi

if echo "$PROMPT" | grep -qiE 'typescript|\.ts\b|\.tsx\b|tsconfig'; then
  DETECTED_LANGS="${DETECTED_LANGS}ts,"
  DETECTED_SKILLS="${DETECTED_SKILLS}typescript-backend,"
fi

if echo "$PROMPT" | grep -qiE 'react|next\.js|nextjs|\.jsx\b'; then
  DETECTED_LANGS="${DETECTED_LANGS}react,"
  DETECTED_SKILLS="${DETECTED_SKILLS}react-nextjs,"
fi

# インフラ検出
if echo "$PROMPT" | grep -qiE 'docker|dockerfile|docker-compose'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}docker-troubleshoot,"
fi

if echo "$PROMPT" | grep -qiE 'kubernetes|k8s|kubectl|deployment\.yaml'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}kubernetes,"
fi

if echo "$PROMPT" | grep -qiE 'terraform|\.tf\b|tfvars'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}terraform,"
fi

# レビュー系検出
if echo "$PROMPT" | grep -qiE 'review|レビュー|確認して'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}code-smell-review,type-safety-review,"
fi

if echo "$PROMPT" | grep -qiE 'security|セキュリティ|脆弱性'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}security-review,"
fi

if echo "$PROMPT" | grep -qiE 'performance|パフォーマンス|遅い|高速化'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}performance-review,"
fi

# 設計系検出
if echo "$PROMPT" | grep -qiE 'architecture|アーキテクチャ|設計'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}clean-architecture-ddd,"
fi

# Serena検出
if echo "$PROMPT" | grep -qiE '/serena|serena mcp|memory'; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\n- 🧠 Serena MCP detected: Use mcp__serena__* tools for project analysis"
fi

# 結果生成
SYSTEM_MESSAGE=""
CONTEXT_MESSAGE=""

# 言語検出結果
if [ -n "$DETECTED_LANGS" ]; then
  # 末尾のカンマを削除
  DETECTED_LANGS="${DETECTED_LANGS%,}"
  SYSTEM_MESSAGE="🔍 Tech stack detected: $DETECTED_LANGS"
  CONTEXT_MESSAGE="# Auto-Detected Configuration\n\n"
  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}**Languages**: $DETECTED_LANGS\n"
  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}**Recommendation**: Run \`/load-guidelines\` to apply language-specific guidelines\n\n"
fi

# スキル検出結果
if [ -n "$DETECTED_SKILLS" ]; then
  DETECTED_SKILLS="${DETECTED_SKILLS%,}"

  if [ -n "$SYSTEM_MESSAGE" ]; then
    SYSTEM_MESSAGE="${SYSTEM_MESSAGE} | Skills: $DETECTED_SKILLS"
  else
    SYSTEM_MESSAGE="💡 Suggested skills: $DETECTED_SKILLS"
  fi

  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}**Suggested Skills**: $DETECTED_SKILLS\n"
  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}Consider using appropriate skills for this task.\n\n"
fi

# 8原則リマインダー（常に表示）
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}# 8 Principles Checklist\n\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}1. ✅ **mem**: Check Serena memory for related information\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}2. ✅ **serena**: Use /serena commands for project operations\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}3. ✅ **guidelines**: Load language guidelines before implementation\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}4. ⚠️  **自動処理禁止**: Never auto-format/lint/build without permission\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}5. 🔔 **完了通知**: Task completion will trigger notification\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}6. 🔒 **型安全**: Avoid \`any\`, minimize \`as\` usage\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}7. 💡 **コマンド提案**: Suggest appropriate commands (/dev, /review, /plan)\n"
CONTEXT_MESSAGE="${CONTEXT_MESSAGE}8. ✋ **確認済**: Confirm unclear points before execution\n"

# 追加コンテキスト
if [ -n "$ADDITIONAL_CONTEXT" ]; then
  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}\n${ADDITIONAL_CONTEXT}"
fi

# JSON出力
if [ -n "$SYSTEM_MESSAGE" ]; then
  cat <<EOF
{
  "systemMessage": "$SYSTEM_MESSAGE",
  "additionalContext": "$CONTEXT_MESSAGE"
}
EOF
else
  # 検出なしの場合は8原則のみ表示
  cat <<EOF
{
  "additionalContext": "$CONTEXT_MESSAGE"
}
EOF
fi
