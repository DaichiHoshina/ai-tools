#!/bin/bash

# PR履歴追加スクリプト（汎用版）
# 使用例: ~/.claude/scripts/add-pr-history.sh 123 "機能Xの実装" "https://example.com/issue/456"

set -e

# プロジェクトの.claudeディレクトリを探す
find_claude_dir() {
    local current_dir=$(pwd)
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/.claude" ]; then
            echo "$current_dir/.claude"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done
    return 1
}

# .claudeディレクトリを検出
CLAUDE_DIR=$(find_claude_dir)
if [ $? -ne 0 ]; then
    echo "❌ エラー: プロジェクトの.claudeディレクトリが見つかりません"
    echo "💡 ヒント: プロジェクトルートで 'mkdir .claude' を実行してください"
    exit 1
fi

HISTORY_DIR="$CLAUDE_DIR/history"
DATE=$(date +%Y-%m-%d)

# 引数チェック
if [ $# -lt 2 ]; then
    echo "使用方法: $0 <pr_number> <title> [ticket_url] [repo_name]"
    echo "  pr_number: PR番号"
    echo "  title: PRのタイトル"
    echo "  ticket_url: 元チケットのURL（オプション）"
    echo "  repo_name: リポジトリ名（オプション、デフォルト: 現在のディレクトリ名）"
    exit 1
fi

PR_NUMBER=$1
TITLE=$2
TICKET_URL=${3:-"[チケットURL]"}

# リポジトリ名を取得（Gitリポジトリから取得を試みる）
if git rev-parse --git-dir > /dev/null 2>&1; then
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
    if [ -n "$REPO_URL" ]; then
        # GitHub形式のURLから所有者/リポジトリ名を抽出
        REPO_NAME=$(echo "$REPO_URL" | sed -E 's/.*[:\/]([^\/]+\/[^\/]+)(\.git)?$/\1/')
    else
        # リモートURLが設定されていない場合
        REPO_NAME="[owner]/[repository]"
    fi
else
    # Gitリポジトリでない場合
    REPO_NAME=${4:-"[owner]/[repository]"}
fi

FILENAME="PR${PR_NUMBER}.md"
TARGET_FILE="$HISTORY_DIR/$FILENAME"

# ディレクトリ作成
mkdir -p "$HISTORY_DIR"

# 既存ファイルがある場合は確認
if [ -f "$TARGET_FILE" ]; then
    echo "⚠️  警告: $TARGET_FILE は既に存在します"
    read -p "上書きしますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 処理を中止しました"
        exit 1
    fi
fi

# PR履歴ファイルを作成
cat > "$TARGET_FILE" << EOF
# PR #${PR_NUMBER}: ${TITLE}

**作成日**: ${DATE}  
**PR URL**: https://github.com/${REPO_NAME}/pull/${PR_NUMBER}  
**元チケット**: ${TICKET_URL}  
**ステータス**: Open

## 🎯 概要
[このPRで実装した内容の概要を2-3行で記述]

## 📋 実装内容

### 追加機能
- [追加した機能を記述]

### 修正内容
- [修正した内容を記述]

## 🔧 技術的変更点

### 変更ファイル
\`\`\`
[変更したファイルのリストを記述]
\`\`\`

## 📊 影響範囲
- **影響する機能**: [機能名]
- **破壊的変更**: なし

## ✅ チェックリスト
- [ ] TypeScriptエラー: 0
- [ ] Lint警告: 0
- [ ] テスト: すべて通過
- [ ] ビルド: 成功

---
**マージ日**: [マージ後に更新]  
**レビュアー**: [レビュー後に更新]
EOF

echo "✅ PR履歴を作成しました: $TARGET_FILE"
echo "📝 [xxx] 部分を適切な内容に置き換えてください"

# CLAUDE.mdへの追記を確認
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    read -p "CLAUDE.mdの実装履歴に追記しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 実装履歴セクションを探して追記
        echo "" >> "$CLAUDE_MD"
        echo "### $(date +%Y年%m月) - PR #${PR_NUMBER}" >> "$CLAUDE_MD"
        echo "- **概要**: ${TITLE}" >> "$CLAUDE_MD"
        echo "- **詳細**: [history/PR${PR_NUMBER}.md](history/PR${PR_NUMBER}.md)" >> "$CLAUDE_MD"
        
        echo "✅ CLAUDE.mdに追記しました"
    fi
fi