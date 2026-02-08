#!/bin/bash

set -e

# =============================================================================
# Claude Code Configuration Installer
# 初回セットアップ専用 - ~/.claude/ディレクトリ作成とシンボリックリンク設定
#
# 実行タイミング:
#   - 新しいPC・環境での初回セットアップ時のみ
#   - ~/.claude/が存在しない、または再インストールが必要な場合
#
# 使い分け:
#   install.sh: 初回セットアップ（ディレクトリ作成・シンボリックリンク）
#   sync.sh:    設定変更後の同期（to-local/from-local）
# =============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
ENV_FILE="$HOME/.env"

# Load security and i18n libraries (Critical #1, #2対策)
LIB_DIR="${SCRIPT_DIR}/lib"
# shellcheck source=lib/security-functions.sh
source "${LIB_DIR}/security-functions.sh" 2>/dev/null || true
# shellcheck source=lib/i18n.sh
source "${LIB_DIR}/i18n.sh" 2>/dev/null || true
# shellcheck source=lib/print-functions.sh
source "${LIB_DIR}/print-functions.sh"

# =============================================================================
# Utility Functions
# =============================================================================

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

# =============================================================================
# Check Prerequisites
# =============================================================================

check_prerequisites() {
    print_header "前提条件のチェック"

    local missing=()

    # Check for required commands
    if ! command -v node &> /dev/null; then
        missing+=("node")
    fi

    if ! command -v npx &> /dev/null; then
        missing+=("npx")
    fi

    if ! command -v uv &> /dev/null; then
        print_warning "uv がインストールされていません（Serena MCP に必要）"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "以下のコマンドがインストールされていません: ${missing[*]}"
        print_info "インストール方法:"
        echo "  Node.js: https://nodejs.org/ または nvm/nodenv を使用"
        echo "  jq: brew install jq (macOS) / apt install jq (Ubuntu)"
        exit 1
    fi

    print_success "前提条件のチェック完了"
}

# =============================================================================
# Setup Environment Variables
# =============================================================================

setup_env_file() {
    print_header "環境変数の設定"

    if [ -f "$ENV_FILE" ]; then
        print_info "既存の .env ファイルが見つかりました: $ENV_FILE"
        if confirm "環境変数を追加/更新しますか？"; then
            setup_env_interactive
        fi
    else
        print_info ".env ファイルを作成します"
        cp "$SCRIPT_DIR/templates/.env.example" "$ENV_FILE"
        setup_env_interactive
    fi
}

setup_env_interactive() {
    echo ""
    print_info "環境変数を設定します（空欄でスキップ）"
    echo ""

    # GitLab
    read -rp "GITLAB_API_URL (例: https://gitlab.example.com/api/v4): " gitlab_url
    if [ -n "$gitlab_url" ]; then
        update_env_var "GITLAB_API_URL" "$gitlab_url"
    fi

    read -srp "GITLAB_PERSONAL_ACCESS_TOKEN: " gitlab_token
    echo
    if [ -n "$gitlab_token" ]; then
        update_env_var "GITLAB_PERSONAL_ACCESS_TOKEN" "$gitlab_token"
    fi

    # Confluence
    read -rp "CONFLUENCE_URL (例: https://your-domain.atlassian.net): " confluence_url
    if [ -n "$confluence_url" ]; then
        update_env_var "CONFLUENCE_URL" "$confluence_url"
    fi

    read -rp "CONFLUENCE_EMAIL: " confluence_email
    if [ -n "$confluence_email" ]; then
        update_env_var "CONFLUENCE_EMAIL" "$confluence_email"
    fi

    read -srp "CONFLUENCE_API_TOKEN: " confluence_token
    echo
    if [ -n "$confluence_token" ]; then
        update_env_var "CONFLUENCE_API_TOKEN" "$confluence_token"
    fi

    # JIRA
    read -rp "JIRA_URL (例: https://your-domain.atlassian.net): " jira_url
    if [ -n "$jira_url" ]; then
        update_env_var "JIRA_URL" "$jira_url"
    fi

    read -rp "JIRA_EMAIL: " jira_email
    if [ -n "$jira_email" ]; then
        update_env_var "JIRA_EMAIL" "$jira_email"
    fi

    read -srp "JIRA_API_TOKEN: " jira_token
    echo
    if [ -n "$jira_token" ]; then
        update_env_var "JIRA_API_TOKEN" "$jira_token"
    fi

    # OpenAI
    read -srp "OPENAI_API_KEY (o3 search 用): " openai_key
    echo
    if [ -n "$openai_key" ]; then
        update_env_var "OPENAI_API_KEY" "$openai_key"
    fi
    
    # Serena
    read -rp "SERENA_PATH (Serena インストールパス、例: $HOME/serena): " serena_path
    if [ -n "$serena_path" ]; then
        update_env_var "SERENA_PATH" "$serena_path"
    fi

    print_success "環境変数の設定完了"
}

update_env_var() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        # Update existing
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        rm -f "${ENV_FILE}.bak"
    else
        # Add new
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# =============================================================================
# Install Claude Code Settings (分割リファクタリング版 - Critical #1, #2対策)
# =============================================================================

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
configure_settings_json() {
    print_info "settings.json を設定中..."

    # Load environment variables
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi

    # Generate settings.json from template
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        print_warning "settings.json が既に存在します"
        if confirm "上書きしますか？（既存はバックアップされます）"; then
            local backup
            backup="$CLAUDE_DIR/settings.json.backup.$(date +%Y%m%d%H%M%S)"
            cp "$CLAUDE_DIR/settings.json" "$backup"
            print_info "バックアップ: $backup"
            generate_settings_json
        fi
    else
        generate_settings_json
    fi

    print_success "settings.json を設定しました"
}

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

generate_settings_json() {
    print_info "settings.json を生成中..."
    
    # Check if template exists
    if [ ! -f "$SCRIPT_DIR/templates/settings.json.template" ]; then
        print_error "settings.json.template が見つかりません。"
        return 1
    fi
    
    # Phase 2でMCP設定は.mcp.jsonに分離済みのため、単純コピーで十分
    if cp "$SCRIPT_DIR/templates/settings.json.template" "$CLAUDE_DIR/settings.json"; then
        print_success "settings.json を生成しました"
    else
        print_error "settings.json の生成に失敗しました"
        return 1
    fi
}

generate_gitlab_mcp_sh() {
    local template
    template=$(cat "$SCRIPT_DIR/templates/gitlab-mcp.sh.template")

    template="${template//__GITLAB_API_URL__/${GITLAB_API_URL:-https://gitlab.example.com/api/v4}}"

    echo "$template" > "$CLAUDE_DIR/gitlab-mcp.sh"
    chmod +x "$CLAUDE_DIR/gitlab-mcp.sh"
    print_success "gitlab-mcp.sh を生成しました"
}

generate_mcp_json() {
    local project_root="$1"
    
    print_info ".mcp.json を生成中..."
    
    # Check if template exists
    if [ ! -f "$SCRIPT_DIR/templates/.mcp.json.template" ]; then
        print_warning ".mcp.json.template が見つかりません。スキップします。"
        return
    fi
    
    # Detect Serena path
    local serena_path="${SERENA_PATH:-}"
    if [ -z "$serena_path" ]; then
        # Try common locations
        for path in "$HOME/serena" "$HOME/projects/serena" "$HOME/workspace/serena"; do
            if [ -d "$path" ]; then
                serena_path="$path"
                break
            fi
        done
    fi
    
    if [ -z "$serena_path" ]; then
        print_warning "Serena のパスが見つかりません。SERENA_PATH 環境変数を設定してください。"
        serena_path="/path/to/serena"
    fi
    
    # Generate .mcp.json using envsubst
    export SERENA_PATH="$serena_path"
    export PROJECT_ROOT="$project_root"
    
    envsubst < "$SCRIPT_DIR/templates/.mcp.json.template" > "$project_root/.mcp.json"
    
    print_success ".mcp.json を生成しました (PROJECT_ROOT=$project_root, SERENA_PATH=$serena_path)"
}


# =============================================================================
# Install MCP Servers
# =============================================================================

install_mcp_servers() {
    print_header "MCP サーバーのインストール"

    if confirm "グローバル MCP サーバーをインストールしますか？"; then
        print_info "MCP サーバーをインストール中..."

        # Install global npm packages
        npm install -g mcp-confluence-server mcp-jira-server @anthropic-ai/claude-code 2>/dev/null || {
            print_warning "一部の npm パッケージのインストールに失敗しました"
        }

        print_success "MCP サーバーのインストール完了"
    fi
}

# =============================================================================
# Verify Installation
# =============================================================================

verify_installation() {
    print_header "インストールの確認"

    local errors=0

    # Check files
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        print_success "settings.json が存在します"
    else
        print_error "settings.json が見つかりません"
        ((errors++))
    fi
    
    if [ -f "$SCRIPT_DIR/.mcp.json" ]; then
        print_success ".mcp.json が存在します"
    else
        print_warning ".mcp.json が見つかりません（後で手動で作成してください）"
    fi

    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        print_success "CLAUDE.md が存在します"
    else
        print_error "CLAUDE.md が見つかりません"
        ((errors++))
    fi

    if [ -f "$CLAUDE_DIR/statusline.js" ]; then
        print_success "statusline.js が存在します"
    else
        print_error "statusline.js が見つかりません"
        ((errors++))
    fi

    # Check directories
    for dir in guidelines scripts commands agents skills; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            print_success "$dir/ が存在します"
        else
            print_warning "$dir/ が見つかりません"
        fi
    done

    if [ $errors -eq 0 ]; then
        echo ""
        print_success "インストールが正常に完了しました！"
    else
        echo ""
        print_error "インストールに問題があります。エラーを確認してください。"
    fi
}

# =============================================================================
# Main
# =============================================================================

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
