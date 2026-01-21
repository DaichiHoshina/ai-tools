#!/bin/bash
#
# Kanban インストールスクリプト
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KANBAN_PATH="$SCRIPT_DIR/dist/cli.js"

echo "Kanban インストール開始..."

# 依存関係インストール
echo "依存関係をインストール中..."
cd "$SCRIPT_DIR"
npm install

# ビルド
echo "ビルド中..."
npm run build

# エイリアス設定確認
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
  # エイリアスが既に存在するか確認
  if grep -q "alias kanban=" "$SHELL_RC"; then
    echo "エイリアスは既に設定されています"
  else
    echo "エイリアスを設定中..."
    echo "" >> "$SHELL_RC"
    echo "# Kanban task management" >> "$SHELL_RC"
    echo "alias kanban=\"node $KANBAN_PATH\"" >> "$SHELL_RC"
    echo "エイリアスを $SHELL_RC に追加しました"
    echo "次のコマンドで有効化してください："
    echo "  source $SHELL_RC"
  fi
fi

# 動作確認
echo ""
echo "インストール完了！"
echo ""
echo "使い方："
echo "  kanban init \"Project Name\"  # ボード初期化"
echo "  kanban add \"タスク\"          # タスク追加"
echo "  kanban list                  # タスク一覧"
echo ""
echo "詳細は README.md を参照してください"
