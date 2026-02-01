#!/usr/bin/env bash
# Setup Hook - --init, --init-only, --maintenance フラグでトリガー
# リポジトリ初期化時の自動セットアップ

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# プロジェクトルート取得
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // "."')

# 依存関係チェック
check_dependencies() {
  local missing=()
  for cmd in git jq; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing dependencies: ${missing[*]}" >&2
    return 1
  fi
  return 0
}

# メイン処理
if ! check_dependencies; then
  cat <<EOF
{
  "error": "Missing required dependencies. Please install: git, jq"
}
EOF
  exit 1
fi

# Serena MCPが有効かチェック
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  cat <<EOF
{
  "systemMessage": "✅ Setup完了 (Serena enabled)",
  "additionalContext": "依存関係チェック完了: git, jq\n\n推奨:\n- /load-guidelines でガイドライン読込\n- Serenaメモリ確認: mcp__serena__list_memories\n- オンボーディング確認: mcp__serena__check_onboarding_performed\n\nProject directory: ${PROJECT_DIR}"
}
EOF
else
  cat <<EOF
{
  "systemMessage": "✅ Setup完了 (Basic mode)",
  "additionalContext": "依存関係チェック完了: git, jq\n\n推奨:\n- /load-guidelines でガイドライン読込\n\nProject directory: ${PROJECT_DIR}"
}
EOF
fi
