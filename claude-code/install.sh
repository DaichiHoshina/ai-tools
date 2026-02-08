#!/bin/bash

set -e

# Claude Code Configuration Installer
# 初回セットアップ専用 - ~/.claude/ディレクトリ作成とシンボリックリンク設定

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
ENV_FILE="$HOME/.env"

# Load common library (includes security, i18n, print functions)
LIB_DIR="${SCRIPT_DIR}/lib"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"

# Load modular libraries
# shellcheck source=lib/validator.sh
source "${LIB_DIR}/validator.sh"
# shellcheck source=lib/mcp-installer.sh
source "${LIB_DIR}/mcp-installer.sh"
# shellcheck source=lib/env-configurator.sh
source "${LIB_DIR}/env-configurator.sh"

# Utility Functions

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
            local backup
            backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
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

# Environment Variables (lib/env-configurator.sh)

# setup_env_file, setup_env_interactive, update_env_var は lib/env-configurator.sh にて定義

# Install Claude Code Settings

# 1. ディレクトリ構造のセットアップ
setup_directories() {
    print_info "ディレクトリ構造を作成中..."

    mkdir -p "$CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR/guidelines/common"
    mkdir -p "$CLAUDE_DIR/guidelines/languages"
    mkdir -p "$CLAUDE_DIR/guidelines/design"
    mkdir -p "$CLAUDE_DIR/guidelines/infrastructure"
    mkdir -p "$CLAUDE_DIR/guidelines/summaries"
    mkdir -p "$CLAUDE_DIR/guidelines-archive/design"
    mkdir -p "$CLAUDE_DIR/scripts"
    mkdir -p "$CLAUDE_DIR/commands"
    mkdir -p "$CLAUDE_DIR/agents"
    mkdir -p "$CLAUDE_DIR/skills"
    mkdir -p "$CLAUDE_DIR/lib"

    print_success "ディレクトリ構造を作成しました"
}

# 2. ディレクトリコンテンツのコピー（重複削減 - Critical #2対策）
copy_directory_contents() {
    print_info "ファイルをコピー中..."

    # 共通関数: ディレクトリ内の全ファイルをコピー
    copy_files() {
        local src_dir="$1"
        local dst_dir="$2"
        local label="$3"

        for file in "$src_dir"/*; do
            if [ -f "$file" ]; then
                local filename
                filename=$(basename "$file")
                cp "$file" "$dst_dir/$filename"
            fi
        done
        print_success "${label} をコピーしました"
    }

    # CLAUDE.md（常に上書き）
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    print_success "CLAUDE.md をコピーしました"

    # CANONICAL.md（常に上書き）
    if [ -f "$SCRIPT_DIR/CANONICAL.md" ]; then
        cp "$SCRIPT_DIR/CANONICAL.md" "$CLAUDE_DIR/CANONICAL.md"
        print_success "CANONICAL.md をコピーしました"
    fi

    # AGENTS.md（常に上書き）
    if [ -f "$SCRIPT_DIR/AGENTS.md" ]; then
        cp "$SCRIPT_DIR/AGENTS.md" "$CLAUDE_DIR/AGENTS.md"
        print_success "AGENTS.md をコピーしました"
    fi

    # Guidelines（各カテゴリ）
    copy_files "$SCRIPT_DIR/guidelines/common" "$CLAUDE_DIR/guidelines/common" "guidelines/common"
    copy_files "$SCRIPT_DIR/guidelines/languages" "$CLAUDE_DIR/guidelines/languages" "guidelines/languages"
    copy_files "$SCRIPT_DIR/guidelines/design" "$CLAUDE_DIR/guidelines/design" "guidelines/design"
    copy_files "$SCRIPT_DIR/guidelines/infrastructure" "$CLAUDE_DIR/guidelines/infrastructure" "guidelines/infrastructure"
    copy_files "$SCRIPT_DIR/guidelines/summaries" "$CLAUDE_DIR/guidelines/summaries" "guidelines/summaries"
    copy_files "$SCRIPT_DIR/guidelines-archive/design" "$CLAUDE_DIR/guidelines-archive/design" "guidelines-archive/design"

    # Commands
    copy_files "$SCRIPT_DIR/commands" "$CLAUDE_DIR/commands" "commands"

    # Agents
    copy_files "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents" "agents"

    # Skills（ディレクトリ構造ごとコピー）
    rm -rf "$CLAUDE_DIR/skills"
    cp -r "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills"
    print_success "skills をコピーしました"

    # Scripts
    for file in "$SCRIPT_DIR/scripts/"*; do
        if [ -f "$file" ]; then
            local filename
            filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/scripts/$filename"
            chmod +x "$CLAUDE_DIR/scripts/$filename"
        fi
    done
    print_success "scripts をコピーしました"

    # Lib（セキュリティライブラリ・i18n）
    if [ -d "$SCRIPT_DIR/lib" ]; then
        copy_files "$SCRIPT_DIR/lib" "$CLAUDE_DIR/lib" "lib"
        chmod +x "$CLAUDE_DIR/lib/"*.sh 2>/dev/null || true
    fi

    # statusline.js
    cp "$SCRIPT_DIR/statusline.js" "$CLAUDE_DIR/statusline.js"
    chmod +x "$CLAUDE_DIR/statusline.js"
    print_success "statusline.js をコピーしました"
}

# 3. settings.json の設定
# configure_settings_json は lib/env-configurator.sh にて定義

# 4. 最終処理
finalize_installation() {
    print_info "最終処理を実行中..."

    # Generate gitlab-mcp.sh
    generate_gitlab_mcp_sh
    
    # Generate .mcp.json for ai-tools project
    if [ -d "$SCRIPT_DIR" ]; then
        generate_mcp_json "$SCRIPT_DIR"
    fi

    print_success "最終処理が完了しました"
}

# メイン関数（統合版 - 複雑度5以下）
install_settings() {
    print_header "Claude Code 設定のインストール"

    # Detect node path
    local node_bin_path
    node_bin_path="$(dirname "$(which node)")"
    if [ "${DEBUG:-0}" = "1" ]; then
        print_info "Node.js パス: $node_bin_path"
    fi

    # 1. ディレクトリ作成
    setup_directories

    # 2. ファイルコピー
    copy_directory_contents

    # 3. settings.json設定
    configure_settings_json

    # 4. 最終処理
    finalize_installation

    print_success "Claude Code 設定のインストール完了"
}

# generate_settings_json は lib/env-configurator.sh にて定義
# generate_gitlab_mcp_sh は lib/mcp-installer.sh にて定義
#
# 以下の関数も lib/mcp-installer.sh にて定義:
#   - generate_mcp_json
#   - install_mcp_servers

# 以下の関数は lib/validator.sh にて定義:
#   - verify_installation

# Main

main() {
    print_header "Claude Code Configuration Installer"

    echo "このスクリプトは Claude Code の設定を新しいPCにインストールします。"
    echo ""

    if ! confirm "インストールを開始しますか？" "y"; then
        echo "インストールをキャンセルしました。"
        exit 0
    fi

    check_prerequisites
    setup_env_file
    install_settings
    install_mcp_servers
    verify_installation

    echo ""
    print_info "次のステップ:"
    echo "  1. ~/.env を確認し、必要な API キーを設定してください"
    echo "  2. Claude Code を再起動してください"
    echo "  3. 動作確認: claude --version"
    echo ""
}

# Run main function
main "$@"
