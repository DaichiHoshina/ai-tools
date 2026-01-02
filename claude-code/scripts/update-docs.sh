#!/bin/bash

# ドキュメント自動更新スクリプト（汎用版）
# 使用例: ~/.claude/scripts/update-docs.sh feature "ユーザー招待機能" "user-invitation"

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

GLOBAL_TEMPLATES_DIR="$HOME/.claude/templates"

# 引数チェック
if [ $# -lt 2 ]; then
    echo "使用方法: $0 <type> <name> [filename]"
    echo "  type: feature, pr, design のいずれか"
    echo "  name: ドキュメントのタイトル"
    echo "  filename: ファイル名（オプション）"
    exit 1
fi

TYPE=$1
NAME=$2
FILENAME=${3:-$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')}
DATE=$(date +%Y-%m-%d)

case $TYPE in
    "feature")
        TEMPLATE="$GLOBAL_TEMPLATES_DIR/feature-spec-template.md"
        TARGET_DIR="$CLAUDE_DIR/specs/features"
        TARGET_FILE="$TARGET_DIR/${FILENAME}.md"
        ;;
    "pr")
        TEMPLATE="$GLOBAL_TEMPLATES_DIR/pr-history-template.md"
        TARGET_DIR="$CLAUDE_DIR/history"
        TARGET_FILE="$TARGET_DIR/PR-${FILENAME}.md"
        ;;
    "design")
        TEMPLATE="$GLOBAL_TEMPLATES_DIR/design-doc-template.md"
        TARGET_DIR="$CLAUDE_DIR/design"
        TARGET_FILE="$TARGET_DIR/${FILENAME}.md"
        ;;
    *)
        echo "エラー: typeは feature, pr, design のいずれかを指定してください"
        exit 1
        ;;
esac

# ディレクトリ作成
mkdir -p "$TARGET_DIR"

# テンプレートをコピーして基本情報を置換
if [ -f "$TEMPLATE" ]; then
    cp "$TEMPLATE" "$TARGET_FILE"
    
    # 基本的な置換（macOSとLinux両対応）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/\[機能名\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i '' "s/\[タイトル\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i '' "s/\[設計名\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i '' "s/\[YYYY-MM-DD\]/$DATE/g" "$TARGET_FILE" 2>/dev/null || true
    else
        # Linux
        sed -i "s/\[機能名\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i "s/\[タイトル\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i "s/\[設計名\]/$NAME/g" "$TARGET_FILE" 2>/dev/null || true
        sed -i "s/\[YYYY-MM-DD\]/$DATE/g" "$TARGET_FILE" 2>/dev/null || true
    fi
    
    echo "✅ ドキュメントを作成しました: $TARGET_FILE"
    echo "📝 テンプレートの [xxx] 部分を適切な内容に置き換えてください"
else
    echo "❌ エラー: テンプレートが見つかりません: $TEMPLATE"
    echo "💡 ヒント: ~/.claude/scripts/init-doc-structure.sh を実行してセットアップしてください"
    exit 1
fi