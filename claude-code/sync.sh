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

# 同期対象（apply_changes / show_diff の共通定義）
# 二重管理によるドリフト防止のためここで一元管理する。
# 追加するファイル/ディレクトリはここにのみ書き、両関数で参照する。
SYNC_ITEMS=(
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
    "sync.sh"
    "output-styles"
    "hooks"
    "rules"
    "config"
    "references"
)

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
# gh skill Protection Functions
# gh skill（GitHub公式 Agent Skills マネージャ）経由でインストールされたスキルを
# sync.sh の削除から保護する。frontmatter の metadata ブロックに github-repo:
# が注入されるため、これを検知して退避→復元する。
# =============================================================================

has_gh_skill_metadata() {
    local skill_file="$1"
    [ -f "$skill_file" ] || return 1
    grep -qE "^[[:space:]]+github-repo:[[:space:]]+https://github\.com/" "$skill_file" 2>/dev/null
}

preserve_gh_skills() {
    local dst="$1" bak_dir="$2"
    [ -d "$dst" ] || return 0
    local d skill_file
    for d in "${dst}"/*/; do
        [ -d "$d" ] || continue
        skill_file=""
        [ -f "${d}SKILL.md" ] && skill_file="${d}SKILL.md"
        [ -z "$skill_file" ] && [ -f "${d}skill.md" ] && skill_file="${d}skill.md"
        if [ -n "$skill_file" ] && has_gh_skill_metadata "$skill_file"; then
            mv "$d" "${bak_dir}/"
        fi
    done
}

restore_gh_skills() {
    local dst="$1" bak_dir="$2"
    [ -d "$bak_dir" ] || return 0
    local d
    for d in "${bak_dir}"/*/; do
        [ -d "$d" ] || continue
        mv "$d" "${dst}/"
    done
}

# =============================================================================
# Repo Freshness Check
# sync_to_local 実行前に origin/main の未取り込みコミットを警告。
# race condition（push 直後の sync が古い workspace を反映する事故）を防ぐ。
# =============================================================================

check_repo_freshness() {
    local repo_root="${SCRIPT_DIR}/.."

    if ! command -v git &>/dev/null; then
        return 0
    fi
    if ! git -C "${repo_root}" rev-parse --git-dir &>/dev/null; then
        return 0
    fi

    # fetch 失敗（オフライン等）は無視
    git -C "${repo_root}" fetch --quiet 2>/dev/null || return 0

    # upstream 未設定なら skip
    local upstream
    upstream=$(git -C "${repo_root}" rev-parse --abbrev-ref '@{u}' 2>/dev/null) || return 0

    local behind
    behind=$(git -C "${repo_root}" rev-list --count "HEAD..@{u}" 2>/dev/null || echo "0")

    if [ "${behind}" -gt 0 ]; then
        print_warning "リモート ${upstream} に ${behind} 件の未取り込みコミットあり"
        echo "  → 'git pull --rebase' を推奨（--skip-git-check で抑制可）" >&2
        echo "  未取り込みコミット:" >&2
        git -C "${repo_root}" log --oneline "HEAD..@{u}" 2>/dev/null | head -5 | sed 's/^/    /' >&2
        echo "" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# Settings Hooks Diff Check
# =============================================================================

sync_settings_hooks() {
    if ! check_jq; then
        print_warning "jq が見つかりません。settings.json hooks の同期をスキップします"
        return
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ] || [ ! -f "$live" ]; then
        return
    fi

    local template_hooks
    template_hooks=$(jq '.hooks // {}' "$template" 2>/dev/null)

    # テンプレートのhooksをマージ（テンプレート優先、ユーザー追加分は保持）
    local tmpfile
    tmpfile=$(mktemp)
    if jq --argjson th "$template_hooks" '.hooks = ((.hooks // {}) + $th)' "$live" > "$tmpfile"; then
        mv "$tmpfile" "$live"
        print_success "settings.json hooks を同期しました"
    else
        rm -f "$tmpfile"
        print_error "settings.json hooks のマージに失敗しました"
    fi
}

check_settings_hooks_diff() {
    if ! check_jq; then
        return
    fi

    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"

    if [ ! -f "$template" ] || [ ! -f "$live" ]; then
        return
    fi

    local template_hooks live_hooks
    template_hooks=$(jq -S '.hooks // {}' "$template" 2>/dev/null)
    live_hooks=$(jq -S '.hooks // {}' "$live" 2>/dev/null)

    if [ "$template_hooks" != "$live_hooks" ]; then
        print_info "settings.json hooks:"
        diff <(echo "$template_hooks") <(echo "$live_hooks") | head -20 || true
    fi
}

# =============================================================================
# Sync: to-local (リポジトリ → ローカル)
# =============================================================================

sync_to_local() {
    print_header "リポジトリ → ローカル 同期"

    # race condition 対策: push 直後の origin/main 未取り込み状態で
    # workspace が古いまま反映されると、追加されたファイルが取りこぼされる。
    if [ "${SKIP_GIT_CHECK:-false}" != "true" ]; then
        check_repo_freshness || true
    fi

    local items=("${SYNC_ITEMS[@]}")

    for item in "${items[@]}"; do
        local src="$SCRIPT_DIR/$item"
        local dst="$CLAUDE_DIR/$item"

        if [ -e "$src" ]; then
            if [ -d "$src" ]; then
                # skills のみ gh skill 管理のディレクトリを退避してから削除
                local gh_bak=""
                if [ "$item" = "skills" ] && [ -d "$dst" ]; then
                    gh_bak=$(mktemp -d)
                    preserve_gh_skills "$dst" "$gh_bak"
                fi
                # 例外伝播の明示化（Critical #7対策）
                if ! rm -rf "${dst:?}"; then
                    print_error "削除失敗: $dst"
                    [ -n "$gh_bak" ] && rm -rf "$gh_bak"
                    return 1
                fi
                if ! cp -r "$src" "$dst"; then
                    print_error "コピー失敗: $src -> $dst"
                    [ -n "$gh_bak" ] && rm -rf "$gh_bak"
                    return 1
                fi
                # hooksディレクトリの場合、テストファイルを除外
                if [ "$item" = "hooks" ]; then
                    rm -f "$dst"/test-*.sh 2>/dev/null || true
                    print_info "  → テストファイル(test-*.sh)を除外"
                fi
                # 退避していた gh skill 管理スキルを復元
                if [ -n "$gh_bak" ]; then
                    restore_gh_skills "$dst" "$gh_bak"
                    rmdir "$gh_bak" 2>/dev/null || true
                    print_info "  → gh skill 管理スキルを保護"
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

    # groove同期（リポジトリ groove/ → ~/.groove/）
    local groove_src="${SCRIPT_DIR}/../groove"
    local groove_dst="$HOME/.groove"
    if [ -d "$groove_src" ]; then
        for subdir in workflows agents; do
            if [ -d "$groove_src/$subdir" ]; then
                mkdir -p "$groove_dst/$subdir"
                if ! cp -r "$groove_src/$subdir/"* "$groove_dst/$subdir/" 2>/dev/null; then
                    print_warning "groove/$subdir コピー失敗（空ディレクトリの可能性）"
                fi
            fi
        done
        for f in config.yaml schema.md README.md; do
            if [ -f "${groove_src}/${f}" ]; then
                cp "${groove_src}/${f}" "${groove_dst}/"
            fi
        done
        mkdir -p "$groove_dst/runs"
        print_success "groove → ~/.groove/"
    fi

    # settings.json hooksをテンプレートからマージ
    sync_settings_hooks

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
    local dirs=("commands" "guidelines" "skills" "agents" "scripts" "lib" "output-styles" "hooks" "rules" "config" "references")
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

    # groove逆同期（~/.groove/ → リポジトリ groove/）
    local groove_src="$HOME/.groove"
    local groove_dst="${SCRIPT_DIR}/../groove"
    if [ -d "$groove_src" ]; then
        for subdir in workflows agents; do
            if [ -d "$groove_src/$subdir" ]; then
                mkdir -p "$groove_dst/$subdir"
                rm -f "$groove_dst/$subdir/"* 2>/dev/null || true
                cp "$groove_src/$subdir/"* "$groove_dst/$subdir/" 2>/dev/null || true
            fi
        done
        for f in config.yaml schema.md README.md; do
            if [ -f "${groove_src}/${f}" ]; then
                cp "${groove_src}/${f}" "${groove_dst}/"
            fi
        done
        print_success "~/.groove/ → groove/"
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

    local items=("${SYNC_ITEMS[@]}")
    local has_diff=false

    # groove差分チェック
    local groove_src="${SCRIPT_DIR}/../groove"
    local groove_dst="$HOME/.groove"
    if [ -d "$groove_src" ] && [ -d "$groove_dst" ]; then
        for subdir in workflows agents; do
            if [ -d "$groove_src/$subdir" ] && [ -d "$groove_dst/$subdir" ]; then
                local diff_output
                diff_output=$(diff -rq "$groove_src/$subdir" "$groove_dst/$subdir" 2>/dev/null || true)
                if [ -n "$diff_output" ]; then
                    echo -e "${YELLOW}groove/$subdir/:${NC}"
                    echo "$diff_output" | head -10
                    has_diff=true
                fi
            fi
        done
    fi

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
    echo "Usage: $0 [to-local|from-local|diff] [--yes|-y] [--skip-git-check]"
    echo ""
    echo "  to-local    リポジトリ → ~/.claude/ に反映"
    echo "  from-local  ~/.claude/ → リポジトリ に反映"
    echo "  diff        差分を表示"
    echo ""
    echo "Options:"
    echo "  --yes, -y         確認プロンプトをスキップ"
    echo "  --skip-git-check  to-local 時の origin/main 未取り込みチェックを抑制"
}

main() {
    local mode=""
    local skip_confirm=false

    # 引数パース
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y)
                skip_confirm=true
                ;;
            --skip-git-check)
                export SKIP_GIT_CHECK=true
                ;;
            to-local|from-local|diff)
                mode="$1"
                ;;
            "")
                ;;
            --force|-f|--dry-run|--check)
                print_error "未対応フラグ: $1"
                echo "  → このスクリプトは --yes/-y のみ対応" >&2
                echo "  → 強制実行は不要（show_diff で差分確認後に確認プロンプト）" >&2
                usage
                exit 1
                ;;
            *)
                print_error "不明なコマンド: $1"
                # よくある typo / 類似コマンドへのヒント
                case "$1" in
                    tolocal|to_local|local) echo "  → もしかして: to-local" >&2 ;;
                    fromlocal|from_local) echo "  → もしかして: from-local" >&2 ;;
                    diffs|differ) echo "  → もしかして: diff" >&2 ;;
                esac
                usage
                exit 1
                ;;
        esac
        shift
    done

    # バージョンチェック（diff以外）
    if [ "$mode" != "diff" ] && [ -n "$mode" ]; then
        check_version
    fi

    case "$mode" in
        to-local)
            show_diff
            echo ""
            if [ "$skip_confirm" = true ] || confirm "ローカルに反映しますか？"; then
                sync_to_local
            fi
            ;;
        from-local)
            show_diff
            echo ""
            if [ "$skip_confirm" = true ] || confirm "リポジトリに反映しますか？"; then
                sync_from_local
            fi
            ;;
        diff)
            show_diff
            ;;
        "")
            usage
            ;;
    esac
}

main "$@"
