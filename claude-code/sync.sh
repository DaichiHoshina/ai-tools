#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Claude Code Configuration Sync Script
# ai-tools リポジトリと ~/.claude/ の双方向同期
#
# 実行タイミング:
#   - リポジトリ更新後: ./sync.sh to-local（リポジトリ → ~/.claude/）
#   - ローカル変更後: ./sync.sh from-local（~/.claude/ → リポジトリ）
#   - 差分確認: ./sync.sh diff
#   - 状態確認: ./sync.sh status（version / 最終 sync / backup / 差分の一覧）
#   - 誤同期からの復旧: ./sync.sh rollback（直近 backup を ~/.claude/ に復元）
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
# CLAUDE_DIR は test 隔離用に env override 可 (default: ~/.claude)
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

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

# =============================================================================
# Partial Sync Filter (--only)
# --only=<a,b> で SYNC_ITEMS を部分集合に絞る。単一 hook / command の
# 編集後に全体同期を待たず高速反映するための仕組み。
# =============================================================================

ONLY_ITEMS=""

item_selected() {
    local item="$1"
    [ -z "$ONLY_ITEMS" ] && return 0
    case ",${ONLY_ITEMS}," in
        *",${item},"*) return 0 ;;
        *) return 1 ;;
    esac
}

apply_only_filter() {
    [ -z "$ONLY_ITEMS" ] && return 0
    local requested_item item found
    local requested=() filtered=()
    IFS=',' read -ra requested <<< "$ONLY_ITEMS"
    for requested_item in "${requested[@]}"; do
        found=false
        for item in "${SYNC_ITEMS[@]}"; do
            [ "$item" = "$requested_item" ] && found=true && break
        done
        if [ "$found" = false ]; then
            print_error "--only: 不明な item '$requested_item'"
            echo "  対象一覧: ${SYNC_ITEMS[*]}" >&2
            return 1
        fi
    done
    for item in "${SYNC_ITEMS[@]}"; do
        item_selected "$item" && filtered+=("$item")
    done
    SYNC_ITEMS=("${filtered[@]}")
    print_info "--only: 同期対象を限定 (${SYNC_ITEMS[*]})"
}

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

# repo 側は CLAUDE.md を CLAUDE.global.md として保持する
# (repo 内作業時に directory memory として ~/.claude/CLAUDE.md と二重 load されるのを防ぐ)。
# 与えられた dir に item が無く .global 版があればそちらの path を返す。
resolve_item_path() {
    local dir="$1" item="$2"
    if [ "$item" = "CLAUDE.md" ] && [ ! -e "$dir/$item" ] && [ -e "$dir/CLAUDE.global.md" ]; then
        echo "$dir/CLAUDE.global.md"
    else
        echo "$dir/$item"
    fi
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
# Dependency Preflight (macOS 機体差対応)
# arm (/opt/homebrew) / intel (/usr/local) の Homebrew PATH 差と、
# jq / rsync / git の未導入を実行前に検出する。どの Mac でも同じ挙動にする。
# =============================================================================

ensure_brew_path() {
    local d
    for d in /opt/homebrew/bin /usr/local/bin; do
        [ -d "$d" ] || continue
        case ":$PATH:" in
            *":$d:"*) ;;
            *) PATH="$PATH:$d" ;;
        esac
    done
    export PATH
}

check_dependencies() {
    local mode="$1"
    ensure_brew_path

    if ! command -v git &> /dev/null; then
        print_warning "git が見つかりません。repo 鮮度チェックと pre-push hook 配置をスキップします"
    fi
    if [ "$mode" = "from-local" ] && ! command -v rsync &> /dev/null; then
        print_error "rsync が見つかりません（from-local に必須）→ 'brew install rsync'"
        return 1
    fi
    if { [ "$mode" = "to-local" ] || [ "$mode" = "from-local" ]; } && ! check_jq; then
        print_warning "jq が見つかりません。settings.json の同期をスキップします → 'brew install jq'"
    fi
    return 0
}

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
# Concurrency Lock
# 複数 terminal / hook からの sync 同時実行で wipe と copy が交錯する事故を防ぐ。
# mkdir の atomic 性で排他し、所有 process 死亡後の stale lock は自動回収する。
# =============================================================================

SYNC_LOCK_DIR=""

release_sync_lock() {
    if [ -n "$SYNC_LOCK_DIR" ]; then
        rm -rf "$SYNC_LOCK_DIR" 2>/dev/null || true
        SYNC_LOCK_DIR=""
    fi
}

acquire_sync_lock() {
    # 再入 OK（同一 process 内の複数回呼び出しは既得 lock を維持する）
    [ -n "$SYNC_LOCK_DIR" ] && return 0
    local lock_dir="$CLAUDE_DIR/.sync.lock"
    mkdir -p "$CLAUDE_DIR"
    if ! mkdir "$lock_dir" 2>/dev/null; then
        local owner_pid
        owner_pid=$(cat "$lock_dir/pid" 2>/dev/null || true)
        if [ -n "$owner_pid" ] && kill -0 "$owner_pid" 2>/dev/null; then
            print_error "別の sync が実行中 (pid: $owner_pid)。終了を待って再実行する"
            return 1
        fi
        print_warning "stale lock を回収する: $lock_dir"
        rm -rf "$lock_dir"
        if ! mkdir "$lock_dir" 2>/dev/null; then
            print_error "lock を取得できない: $lock_dir"
            return 1
        fi
    fi
    echo "$$" > "$lock_dir/pid"
    SYNC_LOCK_DIR="$lock_dir"
    trap 'release_sync_lock' EXIT
    return 0
}

# =============================================================================
# Backup / Rollback
# to-local の破壊的上書き前に ~/.claude 側の同期対象を丸ごと退避する。
# 誤 sync（古い workspace の反映等）は ./sync.sh rollback で直近状態へ戻せる。
# 保持は直近 BACKUP_KEEP 世代のみ（古い世代は自動削除、--no-backup で作成抑制）。
# =============================================================================

BACKUP_KEEP=3

create_backup() {
    local ts backup_dir item copied=0 failed=0
    ts=$(date +%Y%m%d-%H%M%S)
    backup_dir="$CLAUDE_DIR/.sync-backups/$ts"
    mkdir -p "$backup_dir"
    for item in "${SYNC_ITEMS[@]}"; do
        [ -e "$CLAUDE_DIR/$item" ] || continue
        if cp -a "$CLAUDE_DIR/$item" "$backup_dir/"; then
            copied=$((copied + 1))
        else
            failed=$((failed + 1))
            print_warning "backup 失敗: $item"
        fi
    done
    if [ "$failed" -gt 0 ]; then
        print_error "backup が不完全なため中断する（成功 ${copied} / 失敗 ${failed}、不完全な backup は残置: $backup_dir）"
        return 1
    fi
    if [ "$copied" -eq 0 ]; then
        rmdir "$backup_dir" 2>/dev/null || true
        return 0
    fi
    print_info "backup 作成: $backup_dir (${copied} item)"
    prune_backups
}

prune_backups() {
    local root="$CLAUDE_DIR/.sync-backups"
    [ -d "$root" ] || return 0
    local all=() d i
    # shellcheck disable=SC2012  # backup dir 名は自前の timestamp 形式のみ
    while IFS= read -r d; do
        [ -n "$d" ] && all+=("$d")
    done < <(ls -1 "$root" 2>/dev/null | sort)
    local excess=$(( ${#all[@]} - BACKUP_KEEP ))
    for (( i = 0; i < excess; i++ )); do
        rm -rf "${root:?}/${all[$i]}"
    done
    return 0
}

rollback_backup() {
    local root="$CLAUDE_DIR/.sync-backups"
    local latest
    # shellcheck disable=SC2012
    latest=$(ls -1 "$root" 2>/dev/null | sort | tail -1 || true)
    if [ -z "$latest" ]; then
        print_error "backup が存在しない: $root"
        echo "  → backup は to-local 実行時に自動作成される" >&2
        return 1
    fi

    acquire_sync_lock || return 1

    print_header "rollback: ${latest} を ~/.claude/ に復元"
    local entry name
    for entry in "$root/$latest"/*; do
        [ -e "$entry" ] || continue
        name=$(basename "$entry")
        rm -rf "${CLAUDE_DIR:?}/${name}"
        if ! cp -a "$entry" "$CLAUDE_DIR/$name"; then
            print_error "復元失敗: $name"
            return 1
        fi
        print_success "$name"
    done
    print_success "rollback 完了（backup は保持: ${root}/${latest}）"
}

record_last_sync() {
    # status 表示用に最終 sync の時刻と方向を残す
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" > "$CLAUDE_DIR/.last-sync" 2>/dev/null || true
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

    # 同時実行 guard + 誤 sync 復旧用 backup（./sync.sh rollback で戻せる）
    acquire_sync_lock || return 1
    if [ "${NO_BACKUP:-false}" != "true" ]; then
        create_backup || { print_error "backup 失敗のため上書きを中断する"; return 1; }
    fi

    local items=("${SYNC_ITEMS[@]}")

    for item in "${items[@]}"; do
        local src
        src=$(resolve_item_path "$SCRIPT_DIR" "$item")
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
                # rsync 差分適用を優先（wipe → copy 間の中途失敗で dst が空になる窓を塞ぐ）
                if command -v rsync &> /dev/null; then
                    if ! rsync -a --delete "$src/" "$dst/"; then
                        print_error "同期失敗: $src -> $dst"
                        [ -n "$gh_bak" ] && rm -rf "$gh_bak"
                        [ -n "$private_bak" ] && rm -rf "$private_bak"
                        return 1
                    fi
                else
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
                # mino suite の upstream 保守用 payload (runtime 未使用、~430K) を除外
                # evaluations/ (fixtures/oracles 含む) / scripts/ (validator) / agents/ (Codex metadata)
                if [ "$item" = "skills" ]; then
                    local _mino_dir
                    for _mino_dir in "$dst"/mino-*/; do
                        [ -d "$_mino_dir" ] || continue
                        rm -rf "${_mino_dir}evaluations" "${_mino_dir}scripts" "${_mino_dir}agents" 2>/dev/null || true
                    done
                    if compgen -G "$dst/mino-*" > /dev/null 2>&1; then
                        print_info "  → skills/mino-*/{evaluations,scripts,agents}/ を除外"
                    fi
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

    if [ -z "$ONLY_ITEMS" ]; then
        # settings.json hooks / skillOverrides / security-critical sections / root keys をテンプレートからマージ
        sync_settings_hooks             || print_warning "settings.json 同期不完全 (hooks)"
        sync_settings_skill_overrides   || print_warning "settings.json 同期不完全 (skillOverrides)"
        sync_settings_permissions       || print_warning "settings.json 同期不完全 (permissions)"
        sync_settings_root_keys         || print_warning "settings.json 同期不完全 (root keys)"
    fi

    # post-sync 整合性検証: 同期後に差分が残るのは異常（過去の直編集残骸 / コピー失敗の検出）
    # gh skill 管理スキル除外のため skills ディレクトリは個別判定する。
    verify_to_local_sync

    if [ -z "$ONLY_ITEMS" ]; then
        # pre-push hook のシンボリックリンクを配置
        setup_pre_push_hook

        # repo root を記録（clone 先が機体ごとに違っても hooks が path 解決できるようにする）
        record_repo_root

        # Codex / Cursor 側も同期する。各ツール未使用 PC では dir 不在のためスキップ。
        sync_codex
        sync_cursor
    else
        print_info "--only 指定のため settings / pre-push hook / Codex / Cursor 同期を skip"
    fi

    record_last_sync "to-local"
    print_success "ローカルへの同期が完了しました"
}

# Codex 設定 (~/.codex) を同期する。
# ~/.codex が存在する環境でのみ codex/install.sh --sync を呼ぶ。
# bridge skill は上書き再コピーされ、手書き Codex native skill は保護される。
sync_codex() {
    if [ ! -d "$HOME/.codex" ]; then
        return 0
    fi

    local codex_installer="$AI_TOOLS_ROOT/codex/install.sh"
    if [ ! -x "$codex_installer" ]; then
        print_warning "Codex installer が見つかりません（スキップ）: $codex_installer"
        return 0
    fi

    print_header "Codex (~/.codex) 同期"
    if "$codex_installer" --sync; then
        print_success "Codex 同期が完了しました"
    else
        print_warning "Codex 同期に失敗しました（Claude 側同期は完了済み）"
    fi
}

# Cursor 設定 (~/.cursor) を同期する。
# ~/.cursor が存在する環境でのみ cursor/install.sh を呼ぶ。
# rules と共有 memory symlink を配置する。install.sh は非対話・冪等。
sync_cursor() {
    if [ ! -d "$HOME/.cursor" ]; then
        return 0
    fi

    local cursor_installer="$AI_TOOLS_ROOT/cursor/install.sh"
    if [ ! -x "$cursor_installer" ]; then
        print_warning "Cursor installer が見つかりません（スキップ）: $cursor_installer"
        return 0
    fi

    print_header "Cursor (~/.cursor) 同期"
    if "$cursor_installer"; then
        print_success "Cursor 同期が完了しました"
    else
        print_warning "Cursor 同期に失敗しました（Claude 側同期は完了済み）"
    fi
}

# =============================================================================
# Repo Root Record
# ai-tools repo の実 path を ~/.claude/.ai-tools-root に記録する。
# hooks (lib/hook-utils.sh の _aitools_dir / _aitools_prefixes) がこれを最優先で
# 読むため、ghq 以外の場所に clone した Mac でも path 解決が壊れない。
# =============================================================================

record_repo_root() {
    local root_file="$CLAUDE_DIR/.ai-tools-root"
    if printf '%s\n' "$AI_TOOLS_ROOT" > "$root_file"; then
        print_success "repo root を記録: $root_file"
    else
        print_warning "repo root の記録に失敗: $root_file"
    fi
}

verify_to_local_sync() {
    local mismatched=()
    local item src dst diff_output
    for item in "${SYNC_ITEMS[@]}"; do
        src=$(resolve_item_path "$SCRIPT_DIR" "$item")
        dst="$CLAUDE_DIR/$item"
        [ -e "$src" ] && [ -e "$dst" ] || continue
        if [ -d "$src" ]; then
            diff_output=$(diff -rq "$src" "$dst" 2>/dev/null || true)
            # skills は gh skill 管理ぶんと .system/ (OpenAI Codex 向け、sync 除外対象) を除外
            if [ "$item" = "skills" ] && [ -n "$diff_output" ]; then
                # grep -v は全行 filter 時に exit 1 を返すため || true で pipefail 落ちを防ぐ
                diff_output=$(echo "$diff_output" | { grep -v -E '/skills/\.system(/|$)|skills: \.system$|/skills/mino-[^/]+/(evaluations|scripts|agents)(/|$)|/skills/mino-[^/]+: (evaluations|scripts|agents)$' || true; } | while IFS= read -r line; do
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
        local src dst
        src=$(resolve_item_path "$src_dir" "$item")
        dst=$(resolve_item_path "$dst_dir" "$item")
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

    acquire_sync_lock || return 1

    # 単体ファイル同期
    local files=("VERSION" "SERENA_VERSION" "CLAUDE.md")
    for file in "${files[@]}"; do
        item_selected "$file" || continue
        if [ -f "$CLAUDE_DIR/$file" ]; then
            if ! cp "$CLAUDE_DIR/$file" "$(resolve_item_path "$SCRIPT_DIR" "$file")"; then
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
        item_selected "$dir" || continue
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
    if item_selected "statusline.js" && [ -f "$CLAUDE_DIR/statusline.js" ]; then
        cp "$CLAUDE_DIR/statusline.js" "$SCRIPT_DIR/statusline.js"
        print_success "statusline.js"
    fi

    if [ -z "$ONLY_ITEMS" ]; then
        # Templates (センシティブ情報をマスク)
        sync_settings_template
        sync_gitlab_mcp_template
    fi

    record_last_sync "from-local"
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
    # detail に "full" を渡すと dir 差分を省略せず全件表示する（--dry-run 用）
    local detail="${1:-}"
    print_header "差分確認"

    local items=("${SYNC_ITEMS[@]}")
    local has_diff=false
    local diff_count=0

    for item in "${items[@]}"; do
        local src
        src=$(resolve_item_path "$SCRIPT_DIR" "$item")
        local dst="$CLAUDE_DIR/$item"

        if [ -e "$src" ] && [ -e "$dst" ]; then
            if [ -d "$src" ]; then
                local diff_output
                diff_output=$(diff -rq "$src" "$dst" 2>/dev/null || true)
                # skills/.system/ と mino 保守用 payload は to-local で除外するため差分扱いしない
                if [ "$item" = "skills" ] && [ -n "$diff_output" ]; then
                    diff_output=$(echo "$diff_output" | { grep -v -E '/skills/\.system(/|$)|skills: \.system$|/skills/mino-[^/]+/(evaluations|scripts|agents)(/|$)|/skills/mino-[^/]+: (evaluations|scripts|agents)$' || true; })
                fi
                if [ -n "$diff_output" ]; then
                    echo -e "${YELLOW}$item/:${NC}"
                    if [ "$detail" = "full" ]; then
                        echo "$diff_output"
                    else
                        echo "$diff_output" | head -10
                        local total
                        total=$(echo "$diff_output" | wc -l | tr -d ' ')
                        [ "$total" -gt 10 ] && echo "  ... (他 $((total - 10)) 行、全件表示は --dry-run)"
                    fi
                    has_diff=true
                    diff_count=$((diff_count + 1))
                fi
            else
                if ! diff -q "$src" "$dst" > /dev/null 2>&1; then
                    echo -e "${YELLOW}$item:${NC} 差分あり"
                    has_diff=true
                    diff_count=$((diff_count + 1))
                fi
            fi
        elif [ -e "$src" ] && [ ! -e "$dst" ]; then
            echo -e "${BLUE}$item:${NC} ローカルに存在しない"
            has_diff=true
            diff_count=$((diff_count + 1))
        elif [ ! -e "$src" ] && [ -e "$dst" ]; then
            echo -e "${GREEN}$item:${NC} リポジトリに存在しない"
            has_diff=true
            diff_count=$((diff_count + 1))
        fi
    done

    if [ "$has_diff" = false ]; then
        print_success "差分なし（同期済み）"
        return 0
    fi
    print_warning "差分あり: ${diff_count} item"
    return 1
}

# --dry-run 専用: settings.json の hooks/skillOverrides/permissions/root keys
# merge 結果を実 file を書き換えずに diff 表示する（実反映は sync_settings_* と同じ関数を再利用）。
show_settings_diff() {
    check_jq || return 0
    local template="$SCRIPT_DIR/templates/settings.json.template"
    local live="$CLAUDE_DIR/settings.json"
    [ -f "$template" ] && [ -f "$live" ] || return 0

    local tmp_claude_dir
    tmp_claude_dir=$(mktemp -d)
    cp "$live" "$tmp_claude_dir/settings.json"

    (
        CLAUDE_DIR="$tmp_claude_dir" sync_settings_hooks
        CLAUDE_DIR="$tmp_claude_dir" sync_settings_skill_overrides
        CLAUDE_DIR="$tmp_claude_dir" sync_settings_permissions
        CLAUDE_DIR="$tmp_claude_dir" sync_settings_root_keys
    ) > /dev/null 2>&1

    if ! diff -q "$live" "$tmp_claude_dir/settings.json" > /dev/null 2>&1; then
        echo -e "${YELLOW}settings.json (merge 予定):${NC}"
        diff -u "$live" "$tmp_claude_dir/settings.json" | tail -n +3 || true
    fi
    rm -rf "$tmp_claude_dir"
}

# =============================================================================
# Status
# version / 最終 sync / backup 世代 / repo 鮮度 / 差分を 1 画面にまとめる。
# =============================================================================

show_status() {
    print_header "sync status"

    local repo_version local_version
    repo_version=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")
    local_version=$(cat "$CLAUDE_DIR/VERSION" 2>/dev/null || echo "unknown")
    echo "  repo VERSION : ${repo_version}"
    echo "  local VERSION: ${local_version}"

    if [ -f "$CLAUDE_DIR/.last-sync" ]; then
        echo "  last sync    : $(cat "$CLAUDE_DIR/.last-sync")"
    else
        echo "  last sync    : 記録なし"
    fi

    local root="$CLAUDE_DIR/.sync-backups"
    if [ -d "$root" ] && [ -n "$(ls -1 "$root" 2>/dev/null)" ]; then
        local n latest
        # shellcheck disable=SC2012
        n=$(ls -1 "$root" | wc -l | tr -d ' ')
        # shellcheck disable=SC2012
        latest=$(ls -1 "$root" | sort | tail -1)
        echo "  backups      : ${n} 世代 (最新: ${latest})"
    else
        echo "  backups      : なし"
    fi
    echo ""

    if [ "${SKIP_GIT_CHECK:-false}" != "true" ]; then
        check_repo_freshness || true
    fi

    show_diff
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

    # 既に正しいリンクなら何もしない (並列 sync 時の再配置競合も避ける)
    if [[ -L "${pre_push_target}" && "$(readlink "${pre_push_target}")" == "${pre_push_source}" ]]; then
        return 0
    fi

    # 既存ファイルがシンボリックリンクでない場合はバックアップ
    if [[ -e "${pre_push_target}" && ! -L "${pre_push_target}" ]]; then
        mv "${pre_push_target}" "${pre_push_target}.bak"
        print_info "既存 pre-push hook をバックアップ: ${pre_push_target}.bak"
    fi

    # シンボリックリンク配置。ln -sf は unlink→symlink の 2 step で並列実行時に
    # EEXIST 競合するため、temp link を rename (atomic) で置き換える
    local tmp_link="${pre_push_target}.tmp.$$"
    ln -s "${pre_push_source}" "${tmp_link}"
    mv -f "${tmp_link}" "${pre_push_target}"
    print_success "pre-push hook を配置しました: ${pre_push_target} -> ${pre_push_source}"
}

# =============================================================================
# Main
# =============================================================================

usage() {
    echo "Usage: $0 [to-local|from-local|diff|status|rollback] [options]"
    echo ""
    echo "  to-local    リポジトリ → ~/.claude/ に反映（~/.codex があれば Codex も同期）"
    echo "  from-local  ~/.claude/ → リポジトリ に反映"
    echo "  diff        差分を表示"
    echo "  status      version / 最終 sync / backup / 差分をまとめて表示"
    echo "  rollback    直近の backup を ~/.claude/ に復元（誤 sync からの復旧）"
    echo ""
    echo "Options:"
    echo "  --yes, -y         確認プロンプトをスキップ"
    echo "  --dry-run         反映せず変更予定を全件表示（to-local / from-local）"
    echo "  --only=<a,b>      同期対象を item 名で限定（例: --only=hooks,commands）"
    echo "  --no-backup       to-local 前の自動 backup を作らない"
    echo "  --skip-git-check  to-local 時の origin/main 未取り込みチェックを抑制"
    echo "  --allow-overwrite 上書き警告をスキップして強制反映（差分確認は ./sync.sh diff で）"
}

main() {
    local mode=""
    local skip_confirm=false
    local dry_run=false
    ALLOW_OVERWRITE=false

    # 引数パース
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y)
                skip_confirm=true
                ;;
            --dry-run)
                dry_run=true
                ;;
            --no-backup)
                export NO_BACKUP=true
                ;;
            --only=*)
                ONLY_ITEMS="${1#--only=}"
                ;;
            --skip-git-check)
                export SKIP_GIT_CHECK=true
                ;;
            --allow-overwrite)
                ALLOW_OVERWRITE=true
                ;;
            to-local|from-local|diff|status|rollback)
                mode="$1"
                ;;
            "")
                ;;
            --force|-f|--check)
                print_error "未対応フラグ: $1"
                echo "  → 事前確認は --dry-run、強制反映は --allow-overwrite を使う" >&2
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

    # --only の検証と適用（不正 item 名は fail-fast）
    apply_only_filter || exit 1

    # 依存 preflight（mode 指定時のみ、from-local は rsync 必須で fail-fast）
    if [ -n "$mode" ]; then
        check_dependencies "$mode" || exit 1
    fi

    # バージョンチェック（diff / status 以外）
    if [ -n "$mode" ] && [ "$mode" != "diff" ] && [ "$mode" != "status" ]; then
        check_version
    fi

    case "$mode" in
        to-local)
            if [ "$dry_run" = true ]; then
                show_diff full || true
                if [ -z "$ONLY_ITEMS" ]; then
                    show_settings_diff || true
                fi
                print_info "dry-run のため反映しない"
                exit 0
            fi
            show_diff || true
            echo ""
            if [ "$skip_confirm" = true ] || confirm "ローカルに反映しますか？"; then
                sync_to_local
            fi
            ;;
        from-local)
            if [ "$dry_run" = true ]; then
                show_diff full || true
                print_info "dry-run のため反映しない"
                exit 0
            fi
            show_diff || true
            echo ""
            if [ "$skip_confirm" = true ] || confirm "リポジトリに反映しますか？"; then
                sync_from_local
            fi
            ;;
        diff)
            show_diff
            ;;
        status)
            show_status
            ;;
        rollback)
            if [ "$skip_confirm" = true ] || confirm "直近の backup を ~/.claude/ に復元しますか？"; then
                rollback_backup
            fi
            ;;
        "")
            usage
            ;;
    esac
}

main "$@"
