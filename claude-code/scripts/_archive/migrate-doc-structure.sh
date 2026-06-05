#!/bin/bash

# 既存の.claudeディレクトリに新しいドキュメント管理構造を追加するマイグレーションスクリプト

set -e

# Load print functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/print-functions.sh
source "${SCRIPT_DIR}/../lib/print-functions.sh"

# .claudeディレクトリの確認
if [ ! -d ".claude" ]; then
    print_error "エラー: .claudeディレクトリが存在しません"
    print_info "新規プロジェクトの場合は ~/.claude/scripts/init-doc-structure.sh を使用してください"
    exit 1
fi

print_info "既存の.claudeディレクトリを検出しました"
echo ""

# 現在の構造を表示
print_info "現在の.claude構造:"
tree .claude 2>/dev/null || find .claude -type f | sort
echo ""

# バックアップの作成
BACKUP_DIR=".claude.backup.$(date +%Y%m%d_%H%M%S)"
print_info ".claudeディレクトリのバックアップを作成しています..."
cp -r .claude "$BACKUP_DIR"
print_success "バックアップを作成しました: $BACKUP_DIR"
echo ""

# 新しいディレクトリ構造の作成
print_info "新しいドキュメント管理ディレクトリを作成しています..."

# design ディレクトリ
if [ ! -d ".claude/design" ]; then
    mkdir -p .claude/design
    print_success "design/ ディレクトリを作成しました"
else
    print_info "design/ ディレクトリは既に存在します"
fi

# specs/features ディレクトリ
if [ ! -d ".claude/specs/features" ]; then
    mkdir -p .claude/specs/features
    print_success "specs/features/ ディレクトリを作成しました"
else
    print_info "specs/features/ ディレクトリは既に存在します"
fi

# history ディレクトリ
if [ ! -d ".claude/history" ]; then
    mkdir -p .claude/history
    print_success "history/ ディレクトリを作成しました"
else
    print_info "history/ ディレクトリは既に存在します"
fi

echo ""

# 既存ファイルの整理提案
print_info "既存ファイルの整理を提案します..."
echo ""

# 仕様書らしきファイルを探す
SPEC_FILES=$(find .claude -maxdepth 1 -type f -name "*spec*.md" -o -name "*仕様*.md" -o -name "*feature*.md" 2>/dev/null || true)
if [ -n "$SPEC_FILES" ]; then
    print_warning "以下のファイルは仕様書のようです:"
    echo "$SPEC_FILES" | while read -r file; do
        [ -n "$file" ] && echo "  - $file"
    done
    echo ""
    read -p "これらをspecs/features/に移動しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$SPEC_FILES" | while read -r file; do
            if [ -n "$file" ] && [ -f "$file" ]; then
                basename_file=$(basename "$file")
                mv "$file" ".claude/specs/features/$basename_file"
                print_success "$basename_file をspecs/features/に移動しました"
            fi
        done
    fi
    echo ""
fi

# PR履歴らしきファイルを探す
PR_FILES=$(find .claude -maxdepth 1 -type f -name "*PR*.md" -o -name "*pr*.md" -o -name "*履歴*.md" 2>/dev/null || true)
if [ -n "$PR_FILES" ]; then
    print_warning "以下のファイルはPR履歴のようです:"
    echo "$PR_FILES" | while read -r file; do
        [ -n "$file" ] && echo "  - $file"
    done
    echo ""
    read -p "これらをhistory/に移動しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$PR_FILES" | while read -r file; do
            if [ -n "$file" ] && [ -f "$file" ]; then
                basename_file=$(basename "$file")
                mv "$file" ".claude/history/$basename_file"
                print_success "$basename_file をhistory/に移動しました"
            fi
        done
    fi
    echo ""
fi

# 設計ドキュメントらしきファイルを探す
DESIGN_FILES=$(find .claude -maxdepth 1 -type f -name "*design*.md" -o -name "*設計*.md" -o -name "*architecture*.md" 2>/dev/null || true)
if [ -n "$DESIGN_FILES" ]; then
    print_warning "以下のファイルは設計ドキュメントのようです:"
    echo "$DESIGN_FILES" | while read -r file; do
        [ -n "$file" ] && echo "  - $file"
    done
    echo ""
    read -p "これらをdesign/に移動しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$DESIGN_FILES" | while read -r file; do
            if [ -n "$file" ] && [ -f "$file" ]; then
                basename_file=$(basename "$file")
                mv "$file" ".claude/design/$basename_file"
                print_success "$basename_file をdesign/に移動しました"
            fi
        done
    fi
    echo ""
fi

# READMEの更新または作成
if [ ! -f ".claude/README.md" ]; then
    print_info "README.mdを作成しています..."
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

---
このプロジェクトは新しいドキュメント管理システムに移行されました。
詳細は `~/.claude/doc-management-guide.md` を参照してください。
EOF
    print_success "README.mdを作成しました"
else
    print_info "既存のREADME.mdが存在します"
    read -p "ドキュメント管理システムの説明を追記しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # バックアップを作成
        cp .claude/README.md .claude/README.md.backup
        echo "" >> .claude/README.md
        echo "---" >> .claude/README.md
        echo "" >> .claude/README.md
        echo "## 📝 ドキュメント管理システム" >> .claude/README.md
        echo "" >> .claude/README.md
        echo "このプロジェクトは新しいドキュメント管理システムを使用しています。" >> .claude/README.md
        echo "" >> .claude/README.md
        echo "### 使い方" >> .claude/README.md
        echo '```bash' >> .claude/README.md
        echo '# 仕様書作成' >> .claude/README.md
        echo '~/.claude/scripts/update-docs.sh feature "機能名" "file-name"' >> .claude/README.md
        echo '' >> .claude/README.md
        echo '# PR履歴記録' >> .claude/README.md
        echo '~/.claude/scripts/add-pr-history.sh <PR番号> "タイトル"' >> .claude/README.md
        echo '' >> .claude/README.md
        echo '# 設計書作成' >> .claude/README.md
        echo '~/.claude/scripts/update-docs.sh design "設計名" "file-name"' >> .claude/README.md
        echo '```' >> .claude/README.md
        print_success "README.mdに説明を追記しました"
    fi
fi

echo ""

# 最終確認
print_info "最終的な.claude構造:"
tree .claude 2>/dev/null || find .claude -type d | sort
echo ""

# 完了メッセージ
print_success "マイグレーションが完了しました！"
echo ""
print_info "次のステップ:"
echo "1. 新しい構造が正しいか確認してください"
echo "2. 問題がある場合は、バックアップから復元できます:"
echo "   rm -rf .claude && mv $BACKUP_DIR .claude"
echo "3. 問題がなければ、バックアップを削除してください:"
echo "   rm -rf $BACKUP_DIR"
echo ""
print_info "今後は以下のコマンドでドキュメントを管理できます:"
echo "- ~/.claude/scripts/update-docs.sh feature \"機能名\" \"file-name\""
echo "- ~/.claude/scripts/add-pr-history.sh <PR番号> \"タイトル\""
echo "- ~/.claude/scripts/update-docs.sh design \"設計名\" \"file-name\""