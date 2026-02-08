#!/usr/bin/env bash
# =============================================================================
# env-configurator.sh - 環境変数・設定関連
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/env-configurator.sh
#
# 前提:
#   - common.sh が読み込まれていること（print_*, sed_inplace 関数を使用）
#
# =============================================================================

# 重複読み込み防止
if [[ "${_ENV_CONFIGURATOR_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_ENV_CONFIGURATOR_LOADED=true

# =============================================================================
# 環境変数ファイル設定
# =============================================================================

setup_env_file() {
    local env_file="${ENV_FILE:-$HOME/.env}"
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

    print_header "環境変数の設定"

    if [ -f "$env_file" ]; then
        print_info "既存の .env ファイルが見つかりました: $env_file"
        if confirm "環境変数を追加/更新しますか？"; then
            setup_env_interactive
        fi
    else
        print_info ".env ファイルを作成します"
        cp "$script_dir/templates/.env.example" "$env_file"
        setup_env_interactive
    fi
}

# =============================================================================
# インタラクティブ環境変数設定
# =============================================================================

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

# =============================================================================
# 環境変数更新
# =============================================================================

update_env_var() {
    local key="$1"
    local value="$2"
    local env_file="${ENV_FILE:-$HOME/.env}"

    if grep -q "^${key}=" "$env_file" 2>/dev/null; then
        # Update existing
        sed_inplace "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Add new
        echo "${key}=${value}" >> "$env_file"
    fi
}

# =============================================================================
# settings.json 設定
# =============================================================================

configure_settings_json() {
    local env_file="${ENV_FILE:-$HOME/.env}"
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    print_info "settings.json を設定中..."

    # Load environment variables
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
    fi

    # Generate settings.json from template
    if [ -f "$claude_dir/settings.json" ]; then
        print_warning "settings.json が既に存在します"
        if confirm "上書きしますか？（既存はバックアップされます）"; then
            local backup
            backup="$claude_dir/settings.json.backup.$(date +%Y%m%d%H%M%S)"
            cp "$claude_dir/settings.json" "$backup"
            print_info "バックアップ: $backup"
            generate_settings_json
        fi
    else
        generate_settings_json
    fi

    print_success "settings.json を設定しました"
}

# =============================================================================
# settings.json 生成
# =============================================================================

generate_settings_json() {
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    print_info "settings.json を生成中..."

    # Check if template exists
    if [ ! -f "$script_dir/templates/settings.json.template" ]; then
        print_error "settings.json.template が見つかりません。"
        return 1
    fi

    # Phase 2でMCP設定は.mcp.jsonに分離済みのため、単純コピーで十分
    if cp "$script_dir/templates/settings.json.template" "$claude_dir/settings.json"; then
        print_success "settings.json を生成しました"
    else
        print_error "settings.json の生成に失敗しました"
        return 1
    fi
}
