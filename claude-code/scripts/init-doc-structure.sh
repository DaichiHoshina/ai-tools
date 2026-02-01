#!/bin/bash

# ドキュメント構造初期化スクリプト
# 新しいプロジェクトで.claudeディレクトリ構造を作成します

set -e

# Load print functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/print-functions.sh
source "${SCRIPT_DIR}/../lib/print-functions.sh"

# プロジェクトルートの確認
if [ ! -d ".git" ] && [ ! -f "package.json" ] && [ ! -f "Cargo.toml" ] && [ ! -f "go.mod" ]; then
    print_error "警告: プロジェクトルートディレクトリで実行してください"
    read -p "現在のディレクトリで続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# .claudeディレクトリの作成
print_info ".claudeディレクトリ構造を作成しています..."

# ディレクトリ作成
mkdir -p .claude/{design,specs/features,history}

# CLAUDE.mdの作成（プロジェクト固有設定用）
if [ ! -f ".claude/CLAUDE.md" ]; then
    cat > .claude/CLAUDE.md << 'EOF'
# プロジェクト固有設定

## プロジェクト概要
[このプロジェクトの概要を記述]

## 技術スタック
- [使用している主要な技術を列挙]

## 開発規約
[プロジェクト固有のコーディング規約や命名規則を記述]

## 重要な注意事項
[開発時に特に注意すべき点を記述]

---
**注**: グローバル設定は `~/.claude/CLAUDE.md` を参照してください。
EOF
    print_success "CLAUDE.mdを作成しました"
else
    print_info "CLAUDE.mdは既に存在します（スキップ）"
fi

# READMEの作成
if [ ! -f ".claude/README.md" ]; then
    cat > .claude/README.md << 'EOF'
# .claude ドキュメント管理

このディレクトリはプロジェクトのドキュメントを体系的に管理するためのものです。

## ディレクトリ構造

```
.claude/
├── README.md          # このファイル
├── CLAUDE.md          # プロジェクト固有の設定
├── design/            # 設計ドキュメント
├── specs/             # 仕様書
│   ├── system.md      # システム全体仕様（必要に応じて）
│   └── features/      # 機能別仕様書
└── history/           # PR履歴
```

## 使い方

### 新しい仕様書を作成
```bash
~/.claude/scripts/update-docs.sh feature "機能名" "ファイル名"
```

### PR履歴を記録
```bash
~/.claude/scripts/add-pr-history.sh <PR番号> "タイトル" "チケットURL"
```

### 設計ドキュメントを作成
```bash
~/.claude/scripts/update-docs.sh design "設計名" "ファイル名"
```

## 注意事項

- テンプレートとスクリプトはグローバル（`~/.claude/`）のものを使用します
- プロジェクト固有の設定は `CLAUDE.md` に記載してください
- 機密情報やAPIキーなどは記載しないでください

---
詳細は `~/.claude/README.md` を参照してください。
EOF
    print_success "READMEを作成しました"
else
    print_info "READMEは既に存在します（スキップ）"
fi

# .gitignoreの確認と更新
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.claude/settings\.local\.json" .gitignore; then
        echo "" >> .gitignore
        echo "# Claude local settings" >> .gitignore
        echo ".claude/settings.local.json" >> .gitignore
        print_success ".gitignoreを更新しました"
    fi
fi

# 完了メッセージ
echo ""
print_success "ドキュメント構造の初期化が完了しました！"
echo ""
print_info "次のステップ:"
echo "1. .claude/CLAUDE.md にプロジェクト固有の設定を記載してください"
echo "2. 必要に応じて最初の仕様書を作成してください:"
echo "   ~/.claude/scripts/update-docs.sh feature \"最初の機能\" \"first-feature\""
echo ""
print_info "ヒント: グローバルスクリプトは以下から使用できます:"
echo "- ~/.claude/scripts/update-docs.sh"
echo "- ~/.claude/scripts/add-pr-history.sh"