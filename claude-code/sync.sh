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

# Load security library (Critical #4, #7対策)
LIB_DIR="${SCRIPT_DIR}/lib"
# shellcheck source=lib/security-functions.sh
source "${LIB_DIR}/security-functions.sh" 2>/dev/null || {
    # Fallback: escape_for_sed を直接定義
    escape_for_sed() {
        printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'
    }
}

# jq存在チェック（settings.json処理に必要）
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_warning "jq がインストールされていません（brew install jq）"
        print_info "sed fallback モードで動作します"
        return 1
    fi
    return 0
}
HAS_JQ=$(check_jq && echo "true" || echo "false")

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

# sed特殊文字エスケープ関数（セキュリティライブラリで定義済みの場合はスキップ）
if ! command -v escape_for_sed &> /dev/null; then
    escape_for_sed() {
        printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'
    }
fi

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
        "lib"
        "statusline.js"
        "output-styles"
        "hooks"
        "rules"
    )

    for item in "${items[@]}"; do
        local src="$SCRIPT_DIR/$item"
        local dst="$CLAUDE_DIR/$item"

        if [ -e "$src" ]; then
            if [ -d "$src" ]; then
                # 例外伝播の明示化（Critical #7対策）
                if ! rm -rf "$dst"; then
                    print_error "削除失敗: $dst"
                    return 1
                fi
                if ! cp -r "$src" "$dst"; then
                    print_error "コピー失敗: $src -> $dst"
                    return 1
                fi
                # hooksディレクトリの場合、テストファイルを除外
                if [ "$item" = "hooks" ]; then
                    rm -f "$dst"/test-*.sh 2>/dev/null || true
                    print_info "  → テストファイル(test-*.sh)を除外"
                fi
            else
                if ! cp "$src" "$dst"; then
                    print_error "コピー失敗: $src -> $dst"
                    return 1
                fi
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
        if ! cp "$CLAUDE_DIR/CLAUDE.md" "$SCRIPT_DIR/CLAUDE.md"; then
            print_error "コピー失敗: CLAUDE.md"
            return 1
        fi
        print_success "CLAUDE.md"
    fi

    # Directories
    local dirs=("commands" "guidelines" "skills" "agents" "scripts" "lib" "output-styles" "hooks" "rules")
    for dir in "${dirs[@]}"; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            # 例外伝播の明示化（Critical #7対策）
            if ! rm -rf "$SCRIPT_DIR/$dir"; then
                print_error "削除失敗: $SCRIPT_DIR/$dir"
                return 1
            fi
            if ! cp -r "$CLAUDE_DIR/$dir" "$SCRIPT_DIR/$dir"; then
                print_error "コピー失敗: $dir"
                return 1
            fi
            # hooksディレクトリの場合、テストファイルを除外
            if [ "$dir" = "hooks" ]; then
                rm -f "$SCRIPT_DIR/$dir"/test-*.sh 2>/dev/null || true
                print_info "  → テストファイル(test-*.sh)を除外"
            fi
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
    content=$(echo "$content" | sed -E 's/BSA[A-Za-z0-9_-]+/__BRAVE_API_KEY__/g')

    # 秘密情報マスク強化: .envからキー名ベースで検出（*_KEY, *_TOKEN, *_SECRET, *_PASSWORD）
    if [ -f "$HOME/.env" ]; then
        while IFS='=' read -r key value; do
            # コメント行と空行をスキップ
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # 機密キー名パターンをチェック
            if [[ "$key" =~ _(KEY|TOKEN|SECRET|PASSWORD)$ ]] && [ -n "$value" ]; then
                local escaped_value
                escaped_value=$(escape_for_sed "$value")
                local placeholder="__${key}__"
                content=$(echo "$content" | sed "s|$escaped_value|$placeholder|g")
            fi
        done < "$HOME/.env"
    fi

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

    local items=("CLAUDE.md" "commands" "guidelines" "skills" "agents" "scripts" "statusline.js" "output-styles" "hooks" "rules")
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
