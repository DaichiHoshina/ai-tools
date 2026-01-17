#!/usr/bin/env bash
# SessionStart Hook - ai-tools 10原則対応（kenron必須）
# セッション開始時にSerena memoryリストを確認

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# Serena MCPが有効かチェック
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  # additionalContextとしてSerena memory情報を提供
  cat <<EOF
{
  "systemMessage": "📋 Serena MCP is active. Use /serena to access project memory.",
  "additionalContext": "# Session Start Actions (MUST DO)\n1. Call mcp__serena__list_memories to see available memories\n2. Call mcp__serena__check_onboarding_performed to verify project state\n3. Read relevant memories if needed for the task\n\n# Available Tools\n- Serena MCP: Project-specific memory and code analysis\n- Context7: Latest tech documentation\n- Playwright: Browser automation\n\n# 🔒 kenron（圏論的思考法）- 必須\n## 3層分類（全操作に適用）\n- **Safe射（即実行）**: Read, Glob, Grep, git status/log/diff, 分析\n- **Boundary射（要確認）**: Edit, Write, Bash(変更系), git commit/push\n- **Forbidden射（拒否）**: rm -rf /, secrets漏洩, git push --force\n\n# 10原則\n1. **kenron**: 上記3層分類で判断（必須）\n2. **mem**: serena memory 読み込み・更新\n3. **serena**: /serena でコマンド実行\n4. **guidelines**: load-guidelines で言語ガイドライン読み込み\n5. **自動処理禁止**: 整形・lint・テスト修正は要確認\n6. **完了通知**: afplay ~/notification.mp3\n7. **型安全**: any禁止、as控える\n8. **コマンド提案**: /dev, /flow, /review, /plan\n9. **確認済**: 不明点は確認してから実行\n10. **manager**: タスクはagentに委託"
}
EOF
else
  # Serenaが無効の場合は警告
  cat <<EOF
{
  "systemMessage": "⚠️  Serena MCP is not configured for this project.",
  "additionalContext": "Consider configuring Serena MCP for better project memory management."
}
EOF
fi
