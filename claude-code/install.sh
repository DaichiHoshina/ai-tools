#!/bin/bash

set -e

# =============================================================================
# Claude Code Configuration Installer
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
ENV_FILE="$HOME/.env"

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

# Prompt for confirmation
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
    read -p "GITLAB_API_URL (例: https://gitlab.example.com/api/v4): " gitlab_url
    if [ -n "$gitlab_url" ]; then
        update_env_var "GITLAB_API_URL" "$gitlab_url"
    fi

    read -p "GITLAB_PERSONAL_ACCESS_TOKEN: " gitlab_token
    if [ -n "$gitlab_token" ]; then
        update_env_var "GITLAB_PERSONAL_ACCESS_TOKEN" "$gitlab_token"
    fi

    # Confluence
    read -p "CONFLUENCE_URL (例: https://your-domain.atlassian.net): " confluence_url
    if [ -n "$confluence_url" ]; then
        update_env_var "CONFLUENCE_URL" "$confluence_url"
    fi

    read -p "CONFLUENCE_EMAIL: " confluence_email
    if [ -n "$confluence_email" ]; then
        update_env_var "CONFLUENCE_EMAIL" "$confluence_email"
    fi

    read -p "CONFLUENCE_API_TOKEN: " confluence_token
    if [ -n "$confluence_token" ]; then
        update_env_var "CONFLUENCE_API_TOKEN" "$confluence_token"
    fi

    # JIRA
    read -p "JIRA_URL (例: https://your-domain.atlassian.net): " jira_url
    if [ -n "$jira_url" ]; then
        update_env_var "JIRA_URL" "$jira_url"
    fi

    read -p "JIRA_EMAIL: " jira_email
    if [ -n "$jira_email" ]; then
        update_env_var "JIRA_EMAIL" "$jira_email"
    fi

    read -p "JIRA_API_TOKEN: " jira_token
    if [ -n "$jira_token" ]; then
        update_env_var "JIRA_API_TOKEN" "$jira_token"
    fi

    # OpenAI
    read -p "OPENAI_API_KEY (o3 search 用): " openai_key
    if [ -n "$openai_key" ]; then
        update_env_var "OPENAI_API_KEY" "$openai_key"
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
# Install Claude Code Settings
# =============================================================================

install_settings() {
    print_header "Claude Code 設定のインストール"

    # Create .claude directory if not exists
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

    # Detect node path
    local node_bin_path
    node_bin_path="$(dirname "$(which node)")"
    print_info "Node.js パス: $node_bin_path"

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
            local backup="$CLAUDE_DIR/settings.json.backup.$(date +%Y%m%d%H%M%S)"
            cp "$CLAUDE_DIR/settings.json" "$backup"
            print_info "バックアップ: $backup"
            generate_settings_json "$node_bin_path"
        fi
    else
        generate_settings_json "$node_bin_path"
    fi

    # Copy CLAUDE.md (always overwrite)
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    print_success "CLAUDE.md をコピーしました"

    # Copy guidelines (common)
    for file in "$SCRIPT_DIR/guidelines/common/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines/common/$filename"
        fi
    done
    print_success "guidelines/common をコピーしました"

    # Copy guidelines (languages)
    for file in "$SCRIPT_DIR/guidelines/languages/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines/languages/$filename"
        fi
    done
    print_success "guidelines/languages をコピーしました"

    # Copy guidelines (design)
    for file in "$SCRIPT_DIR/guidelines/design/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines/design/$filename"
        fi
    done
    print_success "guidelines/design をコピーしました"

    # Copy guidelines (infrastructure)
    for file in "$SCRIPT_DIR/guidelines/infrastructure/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines/infrastructure/$filename"
        fi
    done
    print_success "guidelines/infrastructure をコピーしました"

    # Copy guidelines (summaries)
    for file in "$SCRIPT_DIR/guidelines/summaries/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines/summaries/$filename"
        fi
    done
    print_success "guidelines/summaries をコピーしました"

    # Copy guidelines-archive (design)
    for file in "$SCRIPT_DIR/guidelines-archive/design/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/guidelines-archive/design/$filename"
        fi
    done
    print_success "guidelines-archive/design をコピーしました"

    # Copy commands
    for file in "$SCRIPT_DIR/commands/"*.md; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/commands/$filename"
        fi
    done
    print_success "commands をコピーしました"

    # Copy agents
    for file in "$SCRIPT_DIR/agents/"*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/agents/$filename"
        fi
    done
    print_success "agents をコピーしました"

    # Copy skills (directory structure)
    rm -rf "$CLAUDE_DIR/skills"
    cp -r "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills"
    print_success "skills をコピーしました"

    # Copy scripts
    for file in "$SCRIPT_DIR/scripts/"*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            cp "$file" "$CLAUDE_DIR/scripts/$filename"
            chmod +x "$CLAUDE_DIR/scripts/$filename"
        fi
    done
    print_success "scripts をコピーしました"

    # Copy statusline.js
    cp "$SCRIPT_DIR/statusline.js" "$CLAUDE_DIR/statusline.js"
    chmod +x "$CLAUDE_DIR/statusline.js"
    print_success "statusline.js をコピーしました"

    # Generate gitlab-mcp.sh
    generate_gitlab_mcp_sh

    print_success "Claude Code 設定のインストール完了"
}

generate_settings_json() {
    local node_bin_path="$1"

    # Read template and replace placeholders
    local template
    template=$(cat "$SCRIPT_DIR/templates/settings.json.template")

    # Replace placeholders
    template="${template//__HOME__/$HOME}"
    template="${template//__NODE_PATH__/$node_bin_path}"
    template="${template//__GITLAB_API_URL__/${GITLAB_API_URL:-https://gitlab.example.com/api/v4}}"
    template="${template//__CONFLUENCE_URL__/${CONFLUENCE_URL:-https://your-domain.atlassian.net}}"
    template="${template//__CONFLUENCE_EMAIL__/${CONFLUENCE_EMAIL:-your-email@example.com}}"
    template="${template//__CONFLUENCE_API_TOKEN__/${CONFLUENCE_API_TOKEN:-your-token}}"
    template="${template//__JIRA_URL__/${JIRA_URL:-https://your-domain.atlassian.net}}"
    template="${template//__JIRA_EMAIL__/${JIRA_EMAIL:-your-email@example.com}}"
    template="${template//__JIRA_API_TOKEN__/${JIRA_API_TOKEN:-your-token}}"

    echo "$template" > "$CLAUDE_DIR/settings.json"
    print_success "settings.json を生成しました"
}

generate_gitlab_mcp_sh() {
    local template
    template=$(cat "$SCRIPT_DIR/templates/gitlab-mcp.sh.template")

    template="${template//__GITLAB_API_URL__/${GITLAB_API_URL:-https://gitlab.example.com/api/v4}}"

    echo "$template" > "$CLAUDE_DIR/gitlab-mcp.sh"
    chmod +x "$CLAUDE_DIR/gitlab-mcp.sh"
    print_success "gitlab-mcp.sh を生成しました"
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
