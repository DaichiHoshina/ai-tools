#!/bin/bash

set -e

# =============================================================================
# Claude Code Configuration Sync Script
# ai-tools リポジトリと ~/.claude/ の双方向同期
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# =============================================================================
# Utility Functions
# =============================================================================

print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

confirm() {
    local message="$1"
    read -p "$message [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# =============================================================================
# Sync: to-local (リポジトリ → ローカル)
# =============================================================================

sync_to_local() {
    print_header "リポジトリ → ローカル 同期"

    local items=(
        "CLAUDE.md"
        "commands"
        "guidelines"
        "skills"
        "agents"
        "scripts"
        "statusline.js"
        "output-styles"
        "hooks"
    )

    for item in "${items[@]}"; do
        local src="$SCRIPT_DIR/$item"
        local dst="$CLAUDE_DIR/$item"

        if [ -e "$src" ]; then
            if [ -d "$src" ]; then
                rm -rf "$dst"
                cp -r "$src" "$dst"
            else
                cp "$src" "$dst"
            fi
            print_success "$item"
        else
            print_warning "$item が見つかりません"
        fi
    done

    print_success "ローカルへの同期が完了しました"
}

# =============================================================================
# Sync: from-local (ローカル → リポジトリ)
# =============================================================================

sync_from_local() {
    print_header "ローカル → リポジトリ 同期"

    # CLAUDE.md
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        cp "$CLAUDE_DIR/CLAUDE.md" "$SCRIPT_DIR/CLAUDE.md"
        print_success "CLAUDE.md"
    fi

    # Directories
    local dirs=("commands" "guidelines" "skills" "agents" "scripts" "output-styles" "hooks")
    for dir in "${dirs[@]}"; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            rm -rf "$SCRIPT_DIR/$dir"
            cp -r "$CLAUDE_DIR/$dir" "$SCRIPT_DIR/$dir"
            print_success "$dir/"
        fi
    done

    # statusline.js
    if [ -f "$CLAUDE_DIR/statusline.js" ]; then
        cp "$CLAUDE_DIR/statusline.js" "$SCRIPT_DIR/statusline.js"
        print_success "statusline.js"
    fi

    # Templates (センシティブ情報をマスク)
    sync_settings_template
    sync_gitlab_mcp_template

    print_success "リポジトリへの同期が完了しました"
}

sync_settings_template() {
    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        return
    fi

    local content
    content=$(cat "$CLAUDE_DIR/settings.json")
    content=$(echo "$content" | sed "s|$HOME|__HOME__|g")

    local node_path
    node_path="$(dirname "$(which node)" 2>/dev/null || echo "/usr/local/bin")"
    content=$(echo "$content" | sed "s|$node_path|__NODE_PATH__|g")

    if [ -f "$HOME/.env" ]; then
        set -a; source "$HOME/.env"; set +a
        [ -n "$GITLAB_API_URL" ] && content=$(echo "$content" | sed "s|$GITLAB_API_URL|__GITLAB_API_URL__|g")
        [ -n "$CONFLUENCE_URL" ] && content=$(echo "$content" | sed "s|$CONFLUENCE_URL|__CONFLUENCE_URL__|g")
        [ -n "$CONFLUENCE_EMAIL" ] && content=$(echo "$content" | sed "s|$CONFLUENCE_EMAIL|__CONFLUENCE_EMAIL__|g")
        [ -n "$CONFLUENCE_API_TOKEN" ] && content=$(echo "$content" | sed "s|$CONFLUENCE_API_TOKEN|__CONFLUENCE_API_TOKEN__|g")
        [ -n "$JIRA_URL" ] && content=$(echo "$content" | sed "s|$JIRA_URL|__JIRA_URL__|g")
        [ -n "$JIRA_EMAIL" ] && content=$(echo "$content" | sed "s|$JIRA_EMAIL|__JIRA_EMAIL__|g")
        [ -n "$JIRA_API_TOKEN" ] && content=$(echo "$content" | sed "s|$JIRA_API_TOKEN|__JIRA_API_TOKEN__|g")
        [ -n "$OPENAI_API_KEY" ] && content=$(echo "$content" | sed "s|$OPENAI_API_KEY|__OPENAI_API_KEY__|g")
    fi

    content=$(echo "$content" | sed -E 's/ATATT3x[A-Za-z0-9_=-]+/__CONFLUENCE_API_TOKEN__/g')
    content=$(echo "$content" | sed -E 's/sk-proj-[A-Za-z0-9_-]+/__OPENAI_API_KEY__/g')

    mkdir -p "$SCRIPT_DIR/templates"
    echo "$content" > "$SCRIPT_DIR/templates/settings.json.template"
    print_success "templates/settings.json.template"
}

sync_gitlab_mcp_template() {
    if [ ! -f "$CLAUDE_DIR/gitlab-mcp.sh" ]; then
        return
    fi

    local content
    content=$(cat "$CLAUDE_DIR/gitlab-mcp.sh")

    if [ -f "$HOME/.env" ]; then
        set -a; source "$HOME/.env"; set +a
        [ -n "$GITLAB_API_URL" ] && content=$(echo "$content" | sed "s|$GITLAB_API_URL|__GITLAB_API_URL__|g")
    fi

    content=$(echo "$content" | sed -E 's|https://[^/]+/api/v4|__GITLAB_API_URL__|g')

    mkdir -p "$SCRIPT_DIR/templates"
    echo "$content" > "$SCRIPT_DIR/templates/gitlab-mcp.sh.template"
    print_success "templates/gitlab-mcp.sh.template"
}

# =============================================================================
# Diff
# =============================================================================

show_diff() {
    print_header "差分確認"

    local items=("CLAUDE.md" "commands" "guidelines" "skills" "agents" "scripts" "statusline.js" "output-styles" "hooks")
    local has_diff=false

    for item in "${items[@]}"; do
        local src="$SCRIPT_DIR/$item"
        local dst="$CLAUDE_DIR/$item"

        if [ -e "$src" ] && [ -e "$dst" ]; then
            if [ -d "$src" ]; then
                local diff_output
                diff_output=$(diff -rq "$src" "$dst" 2>/dev/null || true)
                if [ -n "$diff_output" ]; then
                    echo -e "${YELLOW}$item/:${NC}"
                    echo "$diff_output" | head -10
                    has_diff=true
                fi
            else
                if ! diff -q "$src" "$dst" > /dev/null 2>&1; then
                    echo -e "${YELLOW}$item:${NC} 差分あり"
                    has_diff=true
                fi
            fi
        elif [ -e "$src" ] && [ ! -e "$dst" ]; then
            echo -e "${BLUE}$item:${NC} ローカルに存在しない"
            has_diff=true
        elif [ ! -e "$src" ] && [ -e "$dst" ]; then
            echo -e "${GREEN}$item:${NC} リポジトリに存在しない"
            has_diff=true
        fi
    done

    if [ "$has_diff" = false ]; then
        print_success "差分なし（同期済み）"
    fi
}

# =============================================================================
# Main
# =============================================================================

usage() {
    echo "Usage: $0 [to-local|from-local|diff]"
    echo ""
    echo "  to-local    リポジトリ → ~/.claude/ に反映"
    echo "  from-local  ~/.claude/ → リポジトリ に反映"
    echo "  diff        差分を表示"
}

main() {
    case "${1:-}" in
        to-local)
            show_diff
            echo ""
            if confirm "ローカルに反映しますか？"; then
                sync_to_local
            fi
            ;;
        from-local)
            show_diff
            echo ""
            if confirm "リポジトリに反映しますか？"; then
                sync_from_local
            fi
            ;;
        diff)
            show_diff
            ;;
        "")
            usage
            ;;
        *)
            print_error "不明なコマンド: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
