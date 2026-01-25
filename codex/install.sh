#!/bin/bash

set -e

# =============================================================================
# Codex Configuration Installer (Level 4: Full Sync with Claude Code)
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_DIR="$HOME/.codex"

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

confirm() {
    local message="$1"
    local default="${2:-n}"

    if [ "$default" = "y" ]; then
        read -p "$message [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -p "$message [y/N]: " answer
        answer="${answer:-n}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}

# Create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$3"

    if [ -L "$target" ]; then
        print_warning "シンボリックリンク $name が既に存在します"
        if confirm "上書きしますか？"; then
            rm -f "$target"
            ln -sf "$source" "$target"
            print_success "更新: $name"
        else
            print_info "スキップ: $name"
        fi
    elif [ -e "$target" ]; then
        print_warning "ファイル/ディレクトリ $name が既に存在します"
        if confirm "バックアップして上書きしますか？"; then
            local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
            mv "$target" "$backup"
            print_info "バックアップ: $backup"
            ln -sf "$source" "$target"
            print_success "作成: $name"
        else
            print_info "スキップ: $name"
        fi
    else
        ln -sf "$source" "$target"
        print_success "作成: $name"
    fi
}

# Copy template file
copy_template() {
    local template="$1"
    local target="$2"
    local name="$3"

    if [ -e "$target" ]; then
        print_info "$name は既に存在します（スキップ）"
    else
        cp "$template" "$target"
        print_success "作成: $name"
    fi
}

# =============================================================================
# Check Prerequisites
# =============================================================================

check_prerequisites() {
    print_header "前提条件のチェック"

    if ! command -v codex &> /dev/null; then
        print_error "Codex がインストールされていません"
        print_info "インストール方法:"
        echo "  npm install -g codex-cli"
        exit 1
    fi

    print_success "前提条件のチェック完了"
}

# =============================================================================
# Setup Directories
# =============================================================================

setup_directories() {
    print_header "ディレクトリ構造のセットアップ"

    mkdir -p "$CODEX_DIR"
    mkdir -p "$CODEX_DIR/hooks"

    print_success "ディレクトリ構造を作成しました"
}

# =============================================================================
# Create Symlinks
# =============================================================================

create_symlinks() {
    print_header "シンボリックリンクの作成"

    local SHARED_RESOURCES=("agents" "skills" "guidelines" "commands" "lib")

    for resource in "${SHARED_RESOURCES[@]}"; do
        local source="$AI_TOOLS_DIR/claude-code/$resource"
        local target="$CODEX_DIR/$resource"

        if [ -d "$source" ]; then
            create_symlink "$source" "$target" "$resource"
        else
            print_warning "$resource が見つかりません: $source"
        fi
    done

    print_success "シンボリックリンクの作成完了"
}

# =============================================================================
# Copy Template Files
# =============================================================================

copy_templates() {
    print_header "テンプレートファイルのコピー"

    # config.toml
    if [ -f "$SCRIPT_DIR/config.toml.example" ]; then
        copy_template "$SCRIPT_DIR/config.toml.example" "$CODEX_DIR/config.toml" "config.toml"
    fi

    # AGENTS.md
    if [ -f "$SCRIPT_DIR/AGENTS.md.example" ]; then
        copy_template "$SCRIPT_DIR/AGENTS.md.example" "$CODEX_DIR/AGENTS.md" "AGENTS.md"
    fi

    # COMMANDS.md
    if [ -f "$SCRIPT_DIR/COMMANDS.md" ]; then
        cp "$SCRIPT_DIR/COMMANDS.md" "$CODEX_DIR/COMMANDS.md"
        print_success "更新: COMMANDS.md"
    fi

    # Hooks
    for hook in session-start session-end user-prompt-submit pre-tool-use stop pre-compact; do
        local template="$SCRIPT_DIR/hooks/${hook}.sh.example"
        local target="$CODEX_DIR/hooks/${hook}.sh"

        if [ -f "$template" ]; then
            copy_template "$template" "$target" "hooks/${hook}.sh"
            chmod +x "$target" 2>/dev/null || true
        fi
    done

    print_success "テンプレートファイルのコピー完了"
}

# =============================================================================
# Verify Installation
# =============================================================================

verify_installation() {
    print_header "インストールの確認"

    local errors=0

    # Check symlinks
    for resource in agents skills guidelines commands lib; do
        if [ -L "$CODEX_DIR/$resource" ]; then
            print_success "$resource/ のシンボリックリンクが存在します"
        else
            print_error "$resource/ のシンボリックリンクが見つかりません"
            ((errors++))
        fi
    done

    # Check config files
    if [ -f "$CODEX_DIR/config.toml" ]; then
        print_success "config.toml が存在します"
    else
        print_warning "config.toml が見つかりません（オプション）"
    fi

    if [ -f "$CODEX_DIR/AGENTS.md" ]; then
        print_success "AGENTS.md が存在します"
    else
        print_warning "AGENTS.md が見つかりません（オプション）"
    fi

    if [ $errors -eq 0 ]; then
        echo ""
        print_success "インストールが正常に完了しました！"
    else
        echo ""
        print_error "インストールに問題があります。エラーを確認してください。"
        exit 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header "Codex Configuration Installer (Level 4)"

    echo "このスクリプトは Claude Code のリソースを Codex と完全同期します。"
    echo "シンボリックリンクにより agents, skills, guidelines, commands, lib を共有します。"
    echo ""

    if ! confirm "インストールを開始しますか？" "y"; then
        echo "インストールをキャンセルしました。"
        exit 0
    fi

    check_prerequisites
    setup_directories
    create_symlinks
    copy_templates
    verify_installation

    echo ""
    print_info "次のステップ:"
    echo "  1. ~/.codex/config.toml を確認・編集してください"
    echo "  2. ~/.codex/hooks/*.sh を必要に応じてカスタマイズ"
    echo "  3. Codex を起動して動作確認: codex"
    echo ""
    print_info "利用可能な機能:"
    echo "  - 8種類のエージェント (po, manager, developer, explore, ...)"
    echo "  - 24種類のスキル (review, TDD, brainstorm, ...)"
    echo "  - 29種類のガイドライン (Go, TypeScript, React, ...)"
    echo "  - 19種類のコマンド (/flow, /dev, /review, /cpr, ...)"
    echo ""
}

# Run main function
main "$@"
