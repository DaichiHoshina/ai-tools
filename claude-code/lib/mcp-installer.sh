#!/usr/bin/env bash
# =============================================================================
# mcp-installer.sh - MCP設定関連
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/mcp-installer.sh
#
# 前提:
#   - common.sh が読み込まれていること（print_* 関数を使用）
#
# =============================================================================
set -euo pipefail

# 重複読み込み防止
if [[ "${_MCP_INSTALLER_LOADED:-}" = "true" ]]; then
    # shellcheck disable=SC2317  # multi-source guard: 以降の関数定義は実際に呼ばれる
    return 0 2>/dev/null || true
fi
_MCP_INSTALLER_LOADED=true

# =============================================================================
# GitLab MCP 設定生成
# =============================================================================

generate_gitlab_mcp_sh() {
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    local claude_dir="${CLAUDE_DIR:-$HOME/.claude}"

    local template
    template=$(cat "$script_dir/templates/gitlab-mcp.sh.template")

    template="${template//__GITLAB_API_URL__/${GITLAB_API_URL:-https://gitlab.example.com/api/v4}}"

    echo "$template" > "$claude_dir/gitlab-mcp.sh"
    chmod +x "$claude_dir/gitlab-mcp.sh"
    print_success "gitlab-mcp.sh を生成しました"
}

# =============================================================================
# MCP JSON 設定生成
# =============================================================================

generate_mcp_json() {
    local project_root="$1"
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

    print_info ".mcp.json を生成中..."

    # Check if template exists
    if [ ! -f "$script_dir/templates/.mcp.json.template" ]; then
        print_warning ".mcp.json.template が見つかりません。スキップします。"
        return
    fi

    # Detect Serena path
    local serena_path="${SERENA_PATH:-}"
    if [ -z "$serena_path" ]; then
        # Try common locations
        for path in "$HOME/ghq/github.com/oraios/serena" "$HOME/serena" "$HOME/projects/serena" "$HOME/workspace/serena"; do
            if [ -d "$path" ]; then
                serena_path="$path"
                break
            fi
        done
    fi

    if [ -z "$serena_path" ]; then
        print_warning "Serena のパスが見つかりません。.mcp.json の生成をスキップします。"
        print_warning "SERENA_PATH を設定して再実行してください: SERENA_PATH=<path> envsubst < templates/.mcp.json.template > .mcp.json"
        return 1
    fi

    # Generate .mcp.json using envsubst
    export SERENA_PATH="$serena_path"
    export PROJECT_ROOT="$project_root"

    envsubst < "$script_dir/templates/.mcp.json.template" > "$project_root/.mcp.json"

    print_success ".mcp.json を生成しました (PROJECT_ROOT=$project_root, SERENA_PATH=$serena_path)"
}

# =============================================================================
# .mcp.json 不在検知 + 自動再生成 (session-start hook 用)
# =============================================================================
# generate_mcp_json は interactive install 用に print_* に依存する。
# session hook は副作用 (stdout 汚染、confirm prompt) を避けるため、
# 標準出力なし + 戻り値で結果を返す stateless 版を別関数で提供する。
#
# 引数:
#   $1 = project_root (cwd)
#   $2 = template path (絶対パス、ai-tools/claude-code/templates/.mcp.json.template 想定)
# 戻り値:
#   0 = 再生成成功
#   1 = template 不在
#   2 = Serena path 検出失敗
#   3 = 既存 .mcp.json あり (no-op)

ensure_project_mcp_json() {
    local project_root="$1"
    local template_path="$2"

    if [[ -f "${project_root}/.mcp.json" ]]; then
        return 3
    fi

    if [[ ! -f "${template_path}" ]]; then
        return 1
    fi

    local serena_path="${SERENA_PATH:-}"
    if [[ -z "${serena_path}" ]]; then
        local path
        for path in \
            "${HOME}/ghq/github.com/oraios/serena" \
            "${HOME}/serena" \
            "${HOME}/projects/serena" \
            "${HOME}/workspace/serena"; do
            if [[ -d "${path}" ]]; then
                serena_path="${path}"
                break
            fi
        done
    fi

    if [[ -z "${serena_path}" ]]; then
        return 2
    fi

    SERENA_PATH="${serena_path}" PROJECT_ROOT="${project_root}" \
        envsubst < "${template_path}" > "${project_root}/.mcp.json"
}

# =============================================================================
# MCP サーバーインストール
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
