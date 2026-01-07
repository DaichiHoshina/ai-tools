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

# レビュー系検出（統合後のスキル名を使用）
if echo "$PROMPT" | grep -qiE 'review|レビュー|確認して'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}code-quality-review,"
fi

if echo "$PROMPT" | grep -qiE 'security|セキュリティ|脆弱性|error|エラー'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}security-error-review,"
fi

if echo "$PROMPT" | grep -qiE 'test|テスト|doc|ドキュメント'; then
  DETECTED_SKILLS="${DETECTED_SKILLS}docs-test-review,"
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

# 8原則リマインダーは session-start.sh で表示済みのため、ここでは省略
# トークン節約: 毎プロンプトでの重複表示を防止

# 追加コンテキスト
if [ -n "$ADDITIONAL_CONTEXT" ]; then
  CONTEXT_MESSAGE="${CONTEXT_MESSAGE}\n${ADDITIONAL_CONTEXT}"
fi

# JSON出力（検出があった場合のみ）
if [ -n "$SYSTEM_MESSAGE" ]; then
  cat <<EOF
{
  "systemMessage": "$SYSTEM_MESSAGE",
  "additionalContext": "$CONTEXT_MESSAGE"
}
EOF
elif [ -n "$CONTEXT_MESSAGE" ]; then
  # 追加コンテキストのみある場合
  cat <<EOF
{
  "additionalContext": "$CONTEXT_MESSAGE"
}
EOF
fi
# 検出なしの場合は何も出力しない（トークン節約）
