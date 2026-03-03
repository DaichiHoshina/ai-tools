#!/bin/bash

set -euo pipefail

# =============================================================================
# Claude Code Configuration Sync Script
# ai-tools リポジトリと ~/.claude/ の双方向同期
#
# 実行タイミング:
#   - リポジトリ更新後: ./sync.sh to-local（リポジトリ → ~/.claude/）
#   - ローカル変更後: ./sync.sh from-local（~/.claude/ → リポジトリ）
#   - 差分確認: ./sync.sh diff
#
# 使い分け:
#   install.sh: 初回セットアップ（ディレクトリ作成・シンボリックリンク）
#   sync.sh:    設定変更後の同期（to-local/from-local）
# =============================================================================
# ⚠️ 注意: libファイルをsourceする際、変数名の衝突に注意
# - 各libファイル内では _LIB_PREFIX_ 付きの変数名を使用すること
# - 例: SCRIPT_DIR → _PRINT_LIB_DIR
# =============================================================================

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
# shellcheck source=lib/print-functions.sh
source "${LIB_DIR}/print-functions.sh"

# jq存在チェック（将来の拡張用）
check_jq() {
    command -v jq &> /dev/null
}

# =============================================================================
# Utility Functions
# =============================================================================

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
        "VERSION"
        "CLAUDE.md"
        "CANONICAL.md"
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
                if ! rm -rf "${dst:?}"; then
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

    # 単体ファイル同期
    local files=("VERSION" "CLAUDE.md" "CANONICAL.md")
    for file in "${files[@]}"; do
        if [ -f "$CLAUDE_DIR/$file" ]; then
            if ! cp "$CLAUDE_DIR/$file" "$SCRIPT_DIR/$file"; then
                print_error "コピー失敗: $file"
                return 1
            fi
            print_success "$file"
        fi
    done

    # Directories
    local dirs=("commands" "guidelines" "skills" "agents" "scripts" "lib" "output-styles" "hooks" "rules")
    for dir in "${dirs[@]}"; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            # 例外伝播の明示化（Critical #7対策）
            if ! rm -rf "${SCRIPT_DIR:?}/${dir}"; then
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

    # 共通マスキング関数を使用（security-functions.sh）
    content=$(mask_secrets "$content")

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
        local gitlab_url=""
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            if [ "$key" = "GITLAB_API_URL" ] && [ -n "$value" ]; then
                gitlab_url="$value"
            fi
        done < "$HOME/.env"
        [ -n "$gitlab_url" ] && content="${content//$gitlab_url/__GITLAB_API_URL__}"
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

    local items=("VERSION" "CLAUDE.md" "CANONICAL.md" "commands" "guidelines" "skills" "agents" "scripts" "statusline.js" "output-styles" "hooks" "rules")
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
# Version Check
# =============================================================================

check_version() {
    local repo_version
    local local_version

    repo_version=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")
    local_version=$(cat "$CLAUDE_DIR/VERSION" 2>/dev/null || echo "unknown")

    if [ "$repo_version" != "$local_version" ]; then
        print_warning "Version mismatch detected:"
        echo "  Repository: $repo_version"
        echo "  Local:      $local_version"
        echo ""
        if [ "$repo_version" != "unknown" ] && [ "$local_version" != "unknown" ]; then
            print_info "Run 'git log --oneline' to see changes between versions"
        fi
        echo ""
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
    # バージョンチェック（diff以外）
    if [ "${1:-}" != "diff" ] && [ -n "${1:-}" ]; then
        check_version
    fi

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
