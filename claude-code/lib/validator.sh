#!/usr/bin/env bash
# =============================================================================
# validator.sh - インストール検証処理
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/validator.sh
#
# 前提:
#   - common.sh が読み込まれていること（print_* 関数を使用）
#
# =============================================================================

# 重複読み込み防止
if [[ "${_VALIDATOR_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_VALIDATOR_LOADED=true

# =============================================================================
# 前提条件チェック
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
# インストール検証
# =============================================================================

verify_installation() {
    print_header "インストールの確認"

    local errors=0
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

    # Check files
    if [ -f "$claude_dir/settings.json" ]; then
        print_success "settings.json が存在します"
    else
        print_error "settings.json が見つかりません"
        ((errors++))
    fi

    if [ -f "$script_dir/.mcp.json" ]; then
        print_success ".mcp.json が存在します"
    else
        print_warning ".mcp.json が見つかりません（後で手動で作成してください）"
    fi

    if [ -f "$claude_dir/CLAUDE.md" ]; then
        print_success "CLAUDE.md が存在します"
    else
        print_error "CLAUDE.md が見つかりません"
        ((errors++))
    fi

    if [ -f "$claude_dir/statusline.js" ]; then
        print_success "statusline.js が存在します"
    else
        print_error "statusline.js が見つかりません"
        ((errors++))
    fi

    # Check directories
    for dir in guidelines scripts commands agents skills; do
        if [ -d "$claude_dir/$dir" ]; then
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
