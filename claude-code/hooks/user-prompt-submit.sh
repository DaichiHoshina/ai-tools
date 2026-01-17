#!/usr/bin/env bash
# UserPromptSubmit Hook - 9原則自動化の中核
# プロンプトから技術スタックを自動検出し、適切なガイドライン・スキルを推奨
# 最適化: 検出パターンを1パス処理に統合

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# プロンプトを取得（小文字変換で1回のみ処理）
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# 技術スタック検出（統合パターンマッチング）
DETECTED_LANGS=""
DETECTED_SKILLS=""
ADDITIONAL_CONTEXT=""

# 言語検出（1パス処理）
case "$PROMPT_LOWER" in
  *go*|*golang*|*.go*|*go.mod*) DETECTED_LANGS="${DETECTED_LANGS}go," ; DETECTED_SKILLS="${DETECTED_SKILLS}go-backend," ;;
esac
case "$PROMPT_LOWER" in
  *typescript*|*.ts*|*.tsx*|*tsconfig*) DETECTED_LANGS="${DETECTED_LANGS}ts," ; DETECTED_SKILLS="${DETECTED_SKILLS}typescript-backend," ;;
esac
case "$PROMPT_LOWER" in
  *react*|*next.js*|*nextjs*|*.jsx*) DETECTED_LANGS="${DETECTED_LANGS}react," ; DETECTED_SKILLS="${DETECTED_SKILLS}react-best-practices," ;;
esac

# インフラ検出
case "$PROMPT_LOWER" in
  *docker*|*dockerfile*|*docker-compose*) DETECTED_SKILLS="${DETECTED_SKILLS}docker-troubleshoot," ;;
esac
case "$PROMPT_LOWER" in
  *kubernetes*|*k8s*|*kubectl*|*deployment.yaml*) DETECTED_SKILLS="${DETECTED_SKILLS}kubernetes," ;;
esac
case "$PROMPT_LOWER" in
  *terraform*|*.tf*|*tfvars*) DETECTED_SKILLS="${DETECTED_SKILLS}terraform," ;;
esac

# レビュー系検出（統合後のスキル名）
case "$PROMPT_LOWER" in
  *review*|*レビュー*|*確認して*) DETECTED_SKILLS="${DETECTED_SKILLS}code-quality-review," ;;
esac
case "$PROMPT_LOWER" in
  *security*|*セキュリティ*|*脆弱性*|*error*|*エラー*) DETECTED_SKILLS="${DETECTED_SKILLS}security-error-review," ;;
esac
case "$PROMPT_LOWER" in
  *test*|*テスト*|*doc*|*ドキュメント*) DETECTED_SKILLS="${DETECTED_SKILLS}docs-test-review," ;;
esac

# 設計系検出
case "$PROMPT_LOWER" in
  *architecture*|*アーキテクチャ*|*設計*) DETECTED_SKILLS="${DETECTED_SKILLS}clean-architecture-ddd," ;;
esac

# Serena検出
case "$PROMPT_LOWER" in
  */serena*|*serena*mcp*|*memory*) ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\n- 🧠 Serena MCP detected: Use mcp__serena__* tools for project analysis" ;;
esac

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
  cat <<EOF
{
  "additionalContext": "$CONTEXT_MESSAGE"
}
EOF
fi
# 検出なしの場合は何も出力しない（トークン節約）
