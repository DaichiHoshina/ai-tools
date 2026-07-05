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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CLAUDE_CODE_DIR="${SCRIPT_DIR}"           # claude-code/ 自身
AI_TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"  # ai-tools/ root
CLAUDE_DIR="$HOME/.claude"

# 同期対象（apply_changes / show_diff の共通定義）
# 二重管理によるドリフト防止のためここで一元管理する。
# 追加するファイル/ディレクトリはここにのみ書き、両関数で参照する。
SYNC_ITEMS=(
    "VERSION"
    "SERENA_VERSION"
    "CLAUDE.md"
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

# settings 検証・sync ヘルパー（sync_settings_hooks ほか 4 関数を提供）
# shellcheck source=scripts/settings-validator.sh
source "${SCRIPT_DIR}/scripts/settings-validator.sh"

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
# Private Items Protection
# private-* / local-* prefix のファイル/ディレクトリを破壊的同期から保護する。
# 個人レポ管理外（~/.claude/ 直置き）の非公開設定を維持するための仕組み。
# =============================================================================

preserve_private() {
    local dst="$1" bak_dir="$2"
    [ -d "$dst" ] || return 0
    local entry name
    shopt -s nullglob
    for entry in "$dst"/private-* "$dst"/local-*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        mv "$entry" "${bak_dir}/${name}"
    done
    shopt -u nullglob
}

restore_private() {
    local dst="$1" bak_dir="$2"
    [ -d "$bak_dir" ] || return 0
    local entry name
    shopt -s nullglob
    for entry in "$bak_dir"/private-* "$bak_dir"/local-*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        if [ -e "${dst}/${name}" ]; then
            # repo 版が cp で復活済み → 退避物は不要 (repo 版を正とする)
            rm -rf "${bak_dir:?}/${name}"
        else
            # repo に存在しない真の private → 復元する
            mv "$entry" "${dst}/${name}"
        fi
    done
    shopt -u nullglob
}

# =============================================================================
# Repo Freshness Check
# sync_to_local 実行前に origin/main の未取り込みコミットを警告。
# race condition（push 直後の sync が古い workspace を反映する事故）を防ぐ。
# =============================================================================

check_repo_freshness() {
    local repo_root="${AI_TOOLS_ROOT}"

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
# Sync: to-local (リポジトリ → ローカル)
# =============================================================================

sync_to_local() {
    print_header "リポジトリ → ローカル 同期"

    # 別 PC 初回セットアップ対応: ~/.claude 不在時の自動作成
    mkdir -p "$CLAUDE_DIR"

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
                # private-*/local-* prefix を全ディレクトリで退避（個人非公開設定保護）
                local private_bak=""
                if [ -d "$dst" ]; then
                    private_bak=$(mktemp -d)
                    preserve_private "$dst" "$private_bak"
                fi
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
                    [ -n "$private_bak" ] && rm -rf "$private_bak"
                    return 1
                fi
                if ! cp -r "$src" "$dst"; then
                    print_error "コピー失敗: $src -> $dst"
                    [ -n "$gh_bak" ] && rm -rf "$gh_bak"
                    [ -n "$private_bak" ] && rm -rf "$private_bak"
                    return 1
                fi
                # hooksディレクトリの場合、テストファイルを除外
                if [ "$item" = "hooks" ]; then
                    rm -f "$dst"/test-*.sh 2>/dev/null || true
                    print_info "  → テストファイル(test-*.sh)を除外"
                fi
                # skills の .system/ 配下 (OpenAI Codex 向け、Claude Code から使わない) を除外
                if [ "$item" = "skills" ] && [ -d "$dst/.system" ]; then
                    rm -rf "$dst/.system" 2>/dev/null || true
                    print_info "  → skills/.system/ を除外"
                fi
                # 退避していた gh skill 管理スキルを復元
                if [ -n "$gh_bak" ]; then
                    restore_gh_skills "$dst" "$gh_bak"
                    rmdir "$gh_bak" 2>/dev/null || true
                    print_info "  → gh skill 管理スキルを保護"
                fi
                # 退避していた private-*/local-* を復元
                if [ -n "$private_bak" ]; then
                    restore_private "$dst" "$private_bak"
                    rmdir "$private_bak" 2>/dev/null || true
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

    # settings.json hooks / skillOverrides / security-critical sections / root keys をテンプレートからマージ
    sync_settings_hooks             || print_warning "settings.json 同期不完全 (hooks)"
    sync_settings_skill_overrides   || print_warning "settings.json 同期不完全 (skillOverrides)"
    sync_settings_permissions       || print_warning "settings.json 同期不完全 (permissions)"
    sync_settings_root_keys         || print_warning "settings.json 同期不完全 (root keys)"

    # post-sync 整合性検証: 同期後に差分が残るのは異常（過去の直編集残骸 / コピー失敗の検出）
    # gh skill 管理スキル除外のため skills ディレクトリは個別判定する。
    verify_to_local_sync

    # pre-push hook のシンボリックリンクを配置
    setup_pre_push_hook

    print_success "ローカルへの同期が完了しました"
}

verify_to_local_sync() {
    local mismatched=()
    local item src dst diff_output
    for item in "${SYNC_ITEMS[@]}"; do
        src="$SCRIPT_DIR/$item"
        dst="$CLAUDE_DIR/$item"
        [ -e "$src" ] && [ -e "$dst" ] || continue
        if [ -d "$src" ]; then
            diff_output=$(diff -rq "$src" "$dst" 2>/dev/null || true)
            # skills は gh skill 管理ぶんを除外
            if [ "$item" = "skills" ] && [ -n "$diff_output" ]; then
                diff_output=$(echo "$diff_output" | while IFS= read -r line; do
                    name=$(echo "$line" | sed -E 's|.*/skills/([^/]+)/.*|\1|')
                    [ -n "$name" ] && [ -f "$CLAUDE_DIR/skills/$name/skill.md" ] && \
                        has_gh_skill_metadata "$CLAUDE_DIR/skills/$name/skill.md" && continue
                    [ -n "$name" ] && [ -f "$CLAUDE_DIR/skills/$name/SKILL.md" ] && \
                        has_gh_skill_metadata "$CLAUDE_DIR/skills/$name/SKILL.md" && continue
                    echo "$line"
                done)
            fi
            [ -n "$diff_output" ] && mismatched+=("$item")
        else
            diff -q "$src" "$dst" > /dev/null 2>&1 || mismatched+=("$item")
        fi
    done
    if [ ${#mismatched[@]} -gt 0 ]; then
        print_warning "post-sync 整合性検証: ${#mismatched[@]} 件に差分残存"
        for item in "${mismatched[@]}"; do
            echo "  - $item" >&2
        done
        echo "  → 直編集や private 保護以外の残差。'./sync.sh diff' で詳細確認、必要なら再実行" >&2
    fi
}

# =============================================================================
# Overwrite Guard (from-local 専用)
# ~/.claude/ → repo 方向で repo 側に未コミット差分が残っている場合に上書きをブロックする。
# 過去 incident: from-local 誤実行で repo の guideline 4 file が古い content に上書きされた。
# to-local 側には適用しない (~/.claude 側の直編集は元々 wipe される明示動作)。
# 除外: private-*/local-* prefix / test-*.sh / gh skill 管理スキル
# =============================================================================

_check_overwrite_guard() {
    # 引数: src_dir dst_dir allow_overwrite
    # src_dir の内容を dst_dir に上書きする前に dst_dir 側の差分を検出する。
    local src_dir="$1" dst_dir="$2" allow_overwrite="$3"

    [ "$allow_overwrite" = "true" ] && return 0

    local diff_files=()
    local item

    for item in "${SYNC_ITEMS[@]}"; do
        local src="${src_dir}/${item}"
        local dst="${dst_dir}/${item}"
        [ -e "$src" ] && [ -e "$dst" ] || continue

        local raw_diff
        if [ -d "$src" ]; then
            raw_diff=$(diff -rq "$src" "$dst" 2>/dev/null | \
                grep -v -E '/(private-|local-)' | \
                grep -v '/test-[^/]+\.sh' || true)
            # skills: gh skill 管理ぶんを除外
            if [ "$item" = "skills" ] && [ -n "$raw_diff" ]; then
                raw_diff=$(echo "$raw_diff" | while IFS= read -r line; do
                    local sname
                    sname=$(echo "$line" | sed -E 's|.*/skills/([^/]+)/.*|\1|')
                    if [ -n "$sname" ]; then
                        local sm="${dst_dir}/skills/${sname}/skill.md"
                        local sM="${dst_dir}/skills/${sname}/SKILL.md"
                        { [ -f "$sm" ] && has_gh_skill_metadata "$sm"; } && continue
                        { [ -f "$sM" ] && has_gh_skill_metadata "$sM"; } && continue
                    fi
                    echo "$line"
                done || true)
            fi
            while IFS= read -r line; do
                [ -n "$line" ] && diff_files+=("$line")
            done <<< "$raw_diff"
        else
            diff -q "$src" "$dst" > /dev/null 2>&1 || diff_files+=("$item")
        fi
    done

    if [ ${#diff_files[@]} -eq 0 ]; then
        return 0
    fi

    print_error "上書き保護: 同期先に未反映の差分が ${#diff_files[@]} 件あります"
    local shown=0
    for f in "${diff_files[@]}"; do
        if [ $shown -lt 10 ]; then
            echo "  $f" >&2
            shown=$((shown + 1))
        fi
    done
    local remaining=$((${#diff_files[@]} - shown))
    [ $remaining -gt 0 ] && echo "  (他 ${remaining} 件)" >&2
    echo "" >&2
    echo "  差分確認: ./sync.sh diff" >&2
    echo "  強制反映: ./sync.sh from-local --allow-overwrite" >&2
    return 1
}

# =============================================================================
# Sync: from-local (ローカル → リポジトリ)
# =============================================================================

sync_from_local() {
    print_header "ローカル → リポジトリ 同期"

    # 上書き保護: SCRIPT_DIR (repo) に未コミット変更が残っている場合にブロック
    _check_overwrite_guard "$CLAUDE_DIR" "$SCRIPT_DIR" "${ALLOW_OVERWRITE:-false}" || return 1

    # 単体ファイル同期
    local files=("VERSION" "SERENA_VERSION" "CLAUDE.md")
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
    # rsync で private-*/local-* を除外 → public repo に個人非公開設定が漏れない
    local dirs=("commands" "guidelines" "skills" "agents" "scripts" "lib" "output-styles" "hooks" "rules" "config" "references")
    for dir in "${dirs[@]}"; do
        if [ -d "$CLAUDE_DIR/$dir" ]; then
            mkdir -p "$SCRIPT_DIR/$dir"
            if ! rsync -a --delete \
                --exclude='private-*' --exclude='local-*' \
                "$CLAUDE_DIR/$dir/" "$SCRIPT_DIR/$dir/"; then
                print_error "同期失敗: $dir"
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

    local items=("${SYNC_ITEMS[@]}")
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
        return 0
    else
        return 1
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
# Pre-push Hook Setup
# .git/hooks/pre-push を claude-code/scripts/git-hooks/pre-push へのシンボリックリンクで配置。
# 既存ファイル（非シンボリックリンク）は .bak にバックアップ。
# =============================================================================

setup_pre_push_hook() {
    local repo_root hooks_dir
    repo_root="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)" || {
        print_warning "git リポジトリが見つかりません。pre-push hook のセットアップをスキップします"
        return 0
    }

    # linked worktree では .git が file のため "${repo_root}/.git/hooks" は存在しない。
    # --git-path hooks は通常 repo / worktree の両方で共有 hooks dir を返す
    # (core.hooksPath 設定時はその値を返す)。相対 path で返る場合があるため絶対化する。
    hooks_dir="$(git -C "${repo_root}" rev-parse --git-path hooks 2>/dev/null)" || {
        print_warning "hooks dir を解決できません。pre-push hook のセットアップをスキップします"
        return 0
    }
    case "${hooks_dir}" in
        /*) ;;
        *) hooks_dir="${repo_root}/${hooks_dir}" ;;
    esac
    mkdir -p "${hooks_dir}"

    # symlink source は main checkout 側に解決する。worktree 側 file を指すと
    # worktree 撤去後に dangling symlink になり push が壊れる。
    # main repo では common-dir = <root>/.git なので dirname = repo_root と一致する。
    local common_dir main_root
    common_dir="$(cd "${repo_root}" && git rev-parse --git-common-dir 2>/dev/null)"
    case "${common_dir}" in
        /*) ;;
        *) common_dir="${repo_root}/${common_dir}" ;;
    esac
    main_root="$(dirname "${common_dir}")"
    [[ -d "${main_root}/claude-code" ]] || main_root="${repo_root}"

    local pre_push_target="${hooks_dir}/pre-push"
    local pre_push_source="${main_root}/claude-code/scripts/git-hooks/pre-push"

    if [[ ! -f "${pre_push_source}" ]]; then
        print_warning "pre-push hook source が見つかりません: ${pre_push_source}"
        return 0
    fi

    # 既存ファイルがシンボリックリンクでない場合はバックアップ
    if [[ -e "${pre_push_target}" && ! -L "${pre_push_target}" ]]; then
        mv "${pre_push_target}" "${pre_push_target}.bak"
        print_info "既存 pre-push hook をバックアップ: ${pre_push_target}.bak"
    fi

    # シンボリックリンク配置（既存リンクは上書き）
    ln -sf "${pre_push_source}" "${pre_push_target}"
    print_success "pre-push hook を配置しました: ${pre_push_target} -> ${pre_push_source}"
}

# =============================================================================
# Main
# =============================================================================

usage() {
    echo "Usage: $0 [to-local|from-local|diff] [--yes|-y] [--skip-git-check] [--allow-overwrite]"
    echo ""
    echo "  to-local    リポジトリ → ~/.claude/ に反映"
    echo "  from-local  ~/.claude/ → リポジトリ に反映"
    echo "  diff        差分を表示"
    echo ""
    echo "Options:"
    echo "  --yes, -y         確認プロンプトをスキップ"
    echo "  --skip-git-check  to-local 時の origin/main 未取り込みチェックを抑制"
    echo "  --allow-overwrite 上書き警告をスキップして強制反映（差分確認は ./sync.sh diff で）"
}

main() {
    local mode=""
    local skip_confirm=false
    ALLOW_OVERWRITE=false

    # 引数パース
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y)
                skip_confirm=true
                ;;
            --skip-git-check)
                export SKIP_GIT_CHECK=true
                ;;
            --allow-overwrite)
                ALLOW_OVERWRITE=true
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
            show_diff || true
            echo ""
            if [ "$skip_confirm" = true ] || confirm "ローカルに反映しますか？"; then
                sync_to_local
            fi
            ;;
        from-local)
            show_diff || true
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
