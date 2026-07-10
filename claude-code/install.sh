#!/bin/bash

set -euo pipefail

# Claude Code Configuration Installer
# 初回セットアップ専用 - ~/.claude/ディレクトリ作成とシンボリックリンク設定

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
ENV_FILE="$HOME/.env"

# Load common library (includes security, print functions)
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

# private-*/local-* prefix を保護しつつディレクトリ同期
# rsync --exclude で個人非公開設定を上書きから守る
sync_dir_preserving_private() {
    local src="$1"
    local dst="$2"
    mkdir -p "$dst"
    rsync -a --delete \
        --exclude='private-*' --exclude='local-*' \
        "$src/" "$dst/"
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
    # guidelines は repo の実カテゴリを列挙 (固定リストだと後発カテゴリの取りこぼしが起きる)
    for _gdir in "$SCRIPT_DIR/guidelines"/*/; do
        mkdir -p "$CLAUDE_DIR/guidelines/$(basename "$_gdir")"
    done
    mkdir -p "$CLAUDE_DIR/scripts"
    mkdir -p "$CLAUDE_DIR/commands"
    mkdir -p "$CLAUDE_DIR/agents"
    mkdir -p "$CLAUDE_DIR/skills"
    mkdir -p "$CLAUDE_DIR/lib"
    mkdir -p "$CLAUDE_DIR/references"
    mkdir -p "$CLAUDE_DIR/references-private"

    if [ ! -f "$CLAUDE_DIR/references-private/private-name-list.txt" ]; then
        cat > "$CLAUDE_DIR/references-private/private-name-list.txt" <<'EOF'
# private-name block の term list (1 行 1 term、# は comment)
# このファイルは git 管理外。新 PC では他 PC から手動移植してください。
# 個人名 / 会社名 / project 固有名詞を記入すると ai-tools 配下への書込が block されます。
EOF
        print_warning "references-private/private-name-list.txt を placeholder 生成しました。他 PC から term を移植してください (private-name block は term 不在時 silent pass)。"
    fi

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

    # Guidelines（repo の実カテゴリを全て。固定リストだと writing/backend/operations 等の取りこぼしが起きる）
    for _gdir in "$SCRIPT_DIR/guidelines"/*/; do
        local _gname
        _gname=$(basename "$_gdir")
        copy_files "$SCRIPT_DIR/guidelines/$_gname" "$CLAUDE_DIR/guidelines/$_gname" "guidelines/$_gname"
    done

    # Commands
    copy_files "$SCRIPT_DIR/commands" "$CLAUDE_DIR/commands" "commands"

    # Agents
    copy_files "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents" "agents"

    # Skills（ディレクトリ構造ごとコピー、private-*/local-* は保護）
    sync_dir_preserving_private "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills"
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

    # Lib（セキュリティライブラリ）
    if [ -d "$SCRIPT_DIR/lib" ]; then
        copy_files "$SCRIPT_DIR/lib" "$CLAUDE_DIR/lib" "lib"
        chmod +x "$CLAUDE_DIR/lib/"*.sh 2>/dev/null || true
    fi

    # Hooks（ディレクトリ構造ごとコピー、private-*/local-* は保護）
    if [ -d "$SCRIPT_DIR/hooks" ]; then
        sync_dir_preserving_private "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks"
        rm -f "$CLAUDE_DIR/hooks"/test-*.sh 2>/dev/null || true
        chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true
        print_success "hooks をコピーしました"
    fi

    # References（ガイドラインから参照される詳細資料。on-demand-rules/ 等の subdir を含むため rsync）
    if [ -d "$SCRIPT_DIR/references" ]; then
        sync_dir_preserving_private "$SCRIPT_DIR/references" "$CLAUDE_DIR/references"
        print_success "references をコピーしました"
    fi

    # Rules（hooks の social-hit block 等が参照する canonical。欠けると silent pass になる）
    if [ -d "$SCRIPT_DIR/rules" ]; then
        mkdir -p "$CLAUDE_DIR/rules"
        copy_files "$SCRIPT_DIR/rules" "$CLAUDE_DIR/rules" "rules"
    fi

    # Output styles
    if [ -d "$SCRIPT_DIR/output-styles" ]; then
        mkdir -p "$CLAUDE_DIR/output-styles"
        copy_files "$SCRIPT_DIR/output-styles" "$CLAUDE_DIR/output-styles" "output-styles"
    fi

    # Config
    if [ -d "$SCRIPT_DIR/config" ]; then
        mkdir -p "$CLAUDE_DIR/config"
        copy_files "$SCRIPT_DIR/config" "$CLAUDE_DIR/config" "config"
    fi

    # statusline.js
    cp "$SCRIPT_DIR/statusline.js" "$CLAUDE_DIR/statusline.js"
    chmod +x "$CLAUDE_DIR/statusline.js"
    print_success "statusline.js をコピーしました"
}

# 3. settings.json の設定
# configure_settings_json は lib/env-configurator.sh にて定義

# 4. リポジトリ git hooks 設定
# pre-commit / pre-push で skill-lint・行数上限・review-history 検出を強制
setup_git_hooks() {
    local repo_root="${SCRIPT_DIR%/*}"
    if [ ! -d "${repo_root}/.git" ]; then
        print_info "git リポジトリ外のためフック設定をスキップ"
        return 0
    fi
    if [ ! -d "${SCRIPT_DIR}/githooks" ]; then
        print_warning "claude-code/githooks/ が見つかりません"
        return 0
    fi

    local current
    current=$(git -C "${repo_root}" config core.hooksPath 2>/dev/null || true)
    if [ "${current}" = "claude-code/githooks" ]; then
        print_info "core.hooksPath は既に設定済み"
        return 0
    fi

    git -C "${repo_root}" config core.hooksPath claude-code/githooks
    chmod +x "${SCRIPT_DIR}/githooks/"*.sh "${SCRIPT_DIR}/githooks/pre-commit" "${SCRIPT_DIR}/githooks/pre-push" 2>/dev/null || true
    print_success "git hooks を有効化しました (core.hooksPath=claude-code/githooks)"
}

# 5. 最終処理
finalize_installation() {
    print_info "最終処理を実行中..."

    # Generate gitlab-mcp.sh
    generate_gitlab_mcp_sh

    # Generate .mcp.json for ai-tools project
    if [ -d "$SCRIPT_DIR" ]; then
        generate_mcp_json "$SCRIPT_DIR" || print_warning ".mcp.json の生成をスキップしました（後で手動生成可能）"
    fi

    # ~/bin にCLIツールのシンボリックリンクを作成
    mkdir -p "$HOME/bin"
    for cmd in "$CLAUDE_DIR/scripts/codex-review" "$CLAUDE_DIR/scripts/codex-open"; do
        if [ -f "$cmd" ]; then
            local cmd_name
            cmd_name=$(basename "$cmd")
            ln -sf "$cmd" "$HOME/bin/$cmd_name"
            print_success "~/bin/$cmd_name をリンクしました"
        fi
    done

    # リポジトリ git hooks 設定
    setup_git_hooks

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

    # 4. 最終処理（git hooks 設定含む）
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
