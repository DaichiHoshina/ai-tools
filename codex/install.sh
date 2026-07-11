#!/bin/bash

set -e

# =============================================================================
# Codex Configuration Installer (Level 4: Full Sync with Claude Code)
# =============================================================================

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_DIR="$HOME/.codex"

# Load print functions from claude-code lib (with fallback)
# shellcheck source=../claude-code/lib/print-functions.sh
if ! source "${SCRIPT_DIR}/../claude-code/lib/print-functions.sh" 2>/dev/null; then
    # Fallback: define minimal print functions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    
    print_header() {
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}$1${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    }
    
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
    
    confirm() {
        local message="$1"
        local default="${2:-n}"
        if [ "$default" = "y" ]; then
            read -rp "$message [Y/n]: " answer
            answer="${answer:-y}"
        else
            read -rp "$message [y/N]: " answer
            answer="${answer:-n}"
        fi
        [[ "$answer" =~ ^[Yy]$ ]]
    }
fi

# =============================================================================
# Utility Functions
# =============================================================================

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

# Copy template file
copy_template() {
    local template="$1"
    local target="$2"
    local name="$3"

    if [ -e "$target" ]; then
        print_info "$name は既に存在します（スキップ）"
    else
        cp "$template" "$target"
        print_success "作成: $name"
    fi
}

# Managed marker block sync
# template 内の `<!-- BEGIN managed:<name> -->` ~ `<!-- END managed:<name> -->`
# ブロックを実体ファイルへ冪等に反映する。マーカー外の手編集は保護する。
# 実体にマーカーが無ければ末尾に追記、あれば範囲を置換、同一なら何もしない。
sync_managed_block() {
    local template="$1"
    local target="$2"
    local name="$3"
    local label="$4"

    local begin="<!-- BEGIN managed:${name} -->"
    local end="<!-- END managed:${name} -->"

    if [ ! -f "$template" ] || [ ! -f "$target" ]; then
        return 0
    fi

    # template から managed ブロックを抽出（マーカー行を含む）。
    local block
    block="$(awk -v b="$begin" -v e="$end" '
        $0==b {inblk=1}
        inblk {print}
        $0==e {inblk=0}
    ' "$template")"

    if [ -z "$block" ]; then
        print_warning "template に managed:${name} ブロックがありません（スキップ）"
        return 0
    fi

    # 実体の現ブロックを抽出して比較。同一なら何もしない（冪等）。
    local current
    current="$(awk -v b="$begin" -v e="$end" '
        $0==b {inblk=1}
        inblk {print}
        $0==e {inblk=0}
    ' "$target")"

    if [ "$current" = "$block" ]; then
        print_info "${label} は最新です"
        return 0
    fi

    # 単純な行走査で置換/追記する（awk の process-substitution 依存を避け移植性を確保）。
    local tmp
    tmp="$(mktemp)"
    {
        local replaced=0 skipping=0
        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$line" = "$begin" ]; then
                printf '%s\n' "$block"
                skipping=1
                replaced=1
                continue
            fi
            if [ "$line" = "$end" ]; then
                skipping=0
                continue
            fi
            [ "$skipping" -eq 1 ] && continue
            printf '%s\n' "$line"
        done < "$target"
        if [ "$replaced" -eq 0 ]; then
            # マーカーが無い旧実体 → 末尾に追記する。
            printf '\n%s\n' "$block"
        fi
    } > "$tmp"

    mv "$tmp" "$target"
    print_success "更新: ${label}"
}

show_help() {
    cat <<'EOF'
Usage: ./codex/install.sh [--sync|--doctor|--help]

Install Codex configuration into ~/.codex.

This installer:
  - symlinks agents, guidelines, commands, and lib from claude-code/
  - preserves ~/.codex/skills as a Codex native directory
  - copies Codex-native skills from codex/skills/ without overwriting existing skills
  - copies template files only when the target file does not already exist

Existing config.toml, AGENTS.md, hooks.json, and hook scripts are not overwritten.

Options:
  --sync, sync     Non-interactive re-sync. Repairs symlinks/templates without
                   overwriting, and overwrites bridge skills from codex/skills/.
                   Codex-native hand-written skills are left untouched.
                   Called automatically by claude-code/sync.sh to-local.
  --doctor, check  Check the current Codex setup without changing files.
  --help, -h       Show this help.
EOF
}

doctor_success() {
    print_success "$1"
}

doctor_warning() {
    print_warning "$1"
    DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1))
}

doctor_error() {
    print_error "$1"
    DOCTOR_ERRORS=$((DOCTOR_ERRORS + 1))
}

doctor_check_shared_links() {
    print_header "共有リソースの確認"

    local resource
    for resource in agents guidelines commands lib; do
        local source="$AI_TOOLS_DIR/claude-code/$resource"
        local target="$CODEX_DIR/$resource"

        if [ ! -d "$source" ]; then
            doctor_error "$resource の共有元が見つかりません: $source"
            continue
        fi

        if [ ! -L "$target" ]; then
            if [ -e "$target" ]; then
                doctor_error "$resource は存在しますがシンボリックリンクではありません: $target"
            else
                doctor_error "$resource のシンボリックリンクが見つかりません: $target"
            fi
            continue
        fi

        local actual
        actual="$(readlink "$target")"
        if [ "$actual" = "$source" ]; then
            doctor_success "$resource は Claude Code と共有されています"
        else
            doctor_error "$resource のリンク先が想定と異なります: $actual"
        fi
    done
}

doctor_check_native_skills() {
    print_header "Codex native skills の確認"

    local target="$CODEX_DIR/skills"
    if [ -L "$target" ]; then
        doctor_error "skills/ はシンボリックリンクです。./codex/install.sh --sync で backup 退避のうえ自動修復されます"
    elif [ -d "$target" ]; then
        doctor_success "skills/ は Codex native directory として存在します"
    else
        doctor_warning "skills/ が見つかりません（Codex 側で自動生成される場合があります）"
        return
    fi

    if [ ! -d "$SCRIPT_DIR/skills" ]; then
        return
    fi

    local expected=0 installed=0 missing=""
    local skill_dir skill_name
    for skill_dir in "$SCRIPT_DIR/skills"/*; do
        [ -d "$skill_dir" ] || continue
        skill_name="$(basename "$skill_dir")"
        expected=$((expected + 1))
        if [ -f "$target/$skill_name/SKILL.md" ]; then
            installed=$((installed + 1))
        else
            missing="$missing $skill_name"
        fi
    done

    if [ "$installed" -eq "$expected" ]; then
        doctor_success "bridge skills が全て存在します ($installed/$expected)"
    else
        doctor_warning "未インストールの bridge skill:$missing（./codex/install.sh でコピーできます）"
    fi
}

doctor_check_shared_memory() {
    print_header "共有 memory の確認"

    local source="$AI_TOOLS_DIR/memory"
    local target="$CODEX_DIR/memories/shared"

    if [ ! -d "$source" ]; then
        doctor_error "共有 memory の元が見つかりません: $source"
        return
    fi
    source="$(cd "$source" && pwd -P)"

    if [ ! -L "$target" ]; then
        if [ -e "$target" ]; then
            doctor_error "memories/shared は symlink ではありません: $target"
        else
            doctor_warning "memories/shared の symlink が見つかりません（./codex/install.sh --sync で作成）"
        fi
        return
    fi

    local actual
    actual="$(readlink "$target")"
    if [ "$actual" = "$source" ]; then
        doctor_success "共有 memory がリンクされています ($target -> $source)"
    else
        doctor_error "memories/shared のリンク先が想定と異なります: $actual"
    fi

    if [ -f "$target/MEMORY.md" ]; then
        doctor_success "共有 memory の MEMORY.md が読めます"
    else
        doctor_warning "共有 memory の MEMORY.md が見つかりません: $target/MEMORY.md"
    fi
}

doctor_check_config() {
    print_header "Codex config の確認"

    local config="$CODEX_DIR/config.toml"
    if [ ! -f "$config" ]; then
        doctor_error "config.toml が見つかりません: $config"
        return
    fi

    doctor_success "config.toml が存在します"

    if grep -Eq '^[[:space:]]*codex_hooks[[:space:]]*=' "$config"; then
        doctor_error "config.toml に古い feature 名 codex_hooks が残っています"
    fi

    if grep -Eq '^[[:space:]]*hooks[[:space:]]*=[[:space:]]*true' "$config"; then
        doctor_success "features.hooks が有効です"
    else
        doctor_warning "features.hooks = true が見つかりません"
    fi

    if grep -Eq '^[[:space:]]*memories[[:space:]]*=[[:space:]]*true' "$config"; then
        doctor_success "features.memories が有効です"
    else
        doctor_warning "features.memories = true が見つかりません"
    fi
}

doctor_check_codex_features() {
    print_header "Codex feature flag の確認"

    if ! command -v codex >/dev/null 2>&1; then
        doctor_error "codex コマンドが見つかりません"
        return
    fi

    local features
    if ! features="$(codex features list 2>/dev/null)"; then
        doctor_warning "codex features list を実行できませんでした"
        return
    fi

    if echo "$features" | grep -Eq '^hooks[[:space:]]+.*[[:space:]]true$'; then
        doctor_success "Codex 上で hooks feature が有効です"
    else
        doctor_error "Codex 上で hooks feature が有効ではありません"
    fi

    if echo "$features" | grep -Eq '^memories[[:space:]]+.*[[:space:]]true$'; then
        doctor_success "Codex 上で memories feature が有効です"
    else
        doctor_warning "Codex 上で memories feature が有効ではありません"
    fi
}

doctor_check_hooks() {
    print_header "Codex hooks の確認"

    local hooks_json="$CODEX_DIR/hooks.json"
    local serena_hook="$CODEX_DIR/hooks/serena-hook.sh"

    if [ -f "$hooks_json" ]; then
        doctor_success "hooks.json が存在します"
    else
        doctor_error "hooks.json が見つかりません: $hooks_json"
    fi

    if [ -x "$serena_hook" ]; then
        doctor_success "serena-hook.sh は実行可能です"
    else
        doctor_error "serena-hook.sh が見つからないか実行可能ではありません: $serena_hook"
        return
    fi

    if printf '{"session_id":"codex-doctor","cwd":"%s"}' "$AI_TOOLS_DIR" | "$serena_hook" activate >/dev/null 2>&1; then
        doctor_success "Serena activate hook smoke test に成功しました"
    else
        doctor_error "Serena activate hook smoke test に失敗しました"
    fi
}

doctor_check_serena_mcp() {
    print_header "Serena MCP の確認"

    if ! command -v codex >/dev/null 2>&1; then
        doctor_error "codex コマンドが見つかりません"
        return
    fi

    local mcp
    if ! mcp="$(codex mcp get serena 2>/dev/null)"; then
        doctor_error "Codex に serena MCP が登録されていません"
        return
    fi

    doctor_success "serena MCP が登録されています"

    if echo "$mcp" | grep -q -- '--project-from-cwd'; then
        doctor_success "serena MCP は --project-from-cwd を使用します"
    else
        doctor_error "serena MCP に --project-from-cwd がありません"
    fi

    if echo "$mcp" | grep -q -- '--context=codex'; then
        doctor_success "serena MCP は --context=codex を使用します"
    else
        doctor_error "serena MCP に --context=codex がありません"
    fi

    if echo "$mcp" | grep -q 'UV_CACHE_DIR'; then
        doctor_success "serena MCP に UV_CACHE_DIR が設定されています"
    else
        doctor_warning "serena MCP に UV_CACHE_DIR が見つかりません"
    fi
}

run_doctor() {
    DOCTOR_ERRORS=0
    DOCTOR_WARNINGS=0

    print_header "Codex Setup Doctor"

    doctor_check_shared_links
    doctor_check_native_skills
    doctor_check_shared_memory
    doctor_check_config
    doctor_check_codex_features
    doctor_check_hooks
    doctor_check_serena_mcp

    echo ""
    if [ "$DOCTOR_ERRORS" -eq 0 ]; then
        print_success "Doctor completed: ${DOCTOR_WARNINGS} warning(s), 0 error(s)"
        exit 0
    fi

    print_error "Doctor completed: ${DOCTOR_WARNINGS} warning(s), ${DOCTOR_ERRORS} error(s)"
    exit 1
}

# =============================================================================
# Check Prerequisites
# =============================================================================

check_prerequisites() {
    print_header "前提条件のチェック"

    if ! command -v codex &> /dev/null; then
        print_error "Codex がインストールされていません"
        print_info "インストール方法:"
        echo "  npm install -g codex-cli"
        exit 1
    fi

    print_success "前提条件のチェック完了"
}

# =============================================================================
# Setup Directories
# =============================================================================

setup_directories() {
    print_header "ディレクトリ構造のセットアップ"

    mkdir -p "$CODEX_DIR"
    mkdir -p "$CODEX_DIR/hooks"

    print_success "ディレクトリ構造を作成しました"
}

# =============================================================================
# Create Symlinks
# =============================================================================

create_symlinks() {
    print_header "シンボリックリンクの作成"

    local SHARED_RESOURCES=("agents" "guidelines" "commands" "lib")

    for resource in "${SHARED_RESOURCES[@]}"; do
        local source="$AI_TOOLS_DIR/claude-code/$resource"
        local target="$CODEX_DIR/$resource"

        if [ -d "$source" ]; then
            create_symlink "$source" "$target" "$resource"
        else
            print_warning "$resource が見つかりません: $source"
        fi
    done

    link_shared_memory

    print_success "シンボリックリンクの作成完了"
}

link_shared_memory() {
    # グローバル共有 memory (~/ai-tools/memory) を Codex から読めるようにする。
    # Codex 自前の ~/.codex/memories/ (MEMORY.md 自動生成) と衝突しないよう
    # 別ディレクトリ ~/.codex/memories/shared に symlink する。非対話で冪等。
    # ~/ai-tools 自体が symlink の環境があるため、実 path (pwd -P) に正規化して
    # 比較・作成する。正規化しないと毎回リンク先が揺れて再作成が発生する。
    local source="$AI_TOOLS_DIR/memory"
    local target="$CODEX_DIR/memories/shared"

    if [ ! -d "$source" ]; then
        print_warning "共有 memory がありません: $source"
        return 0
    fi
    source="$(cd "$source" && pwd -P)"

    mkdir -p "$CODEX_DIR/memories"

    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            print_info "memory は既にリンク済みです"
            return 0
        fi
        rm -f "$target"
    elif [ -e "$target" ]; then
        local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        print_info "memory をバックアップ: $backup"
    fi

    ln -sf "$source" "$target"
    print_success "作成: memories/shared (-> $source)"
}

# =============================================================================
# Copy Template Files
# =============================================================================

copy_templates() {
    print_header "テンプレートファイルのコピー"

    # config.toml
    if [ -f "$SCRIPT_DIR/config.toml.example" ]; then
        copy_template "$SCRIPT_DIR/config.toml.example" "$CODEX_DIR/config.toml" "config.toml"
    fi

    # AGENTS.md
    # 実体不在なら丸ごとコピー、既存なら managed マーカーブロックだけ template と同期する。
    # マーカー外の手編集は保護する。
    if [ -f "$SCRIPT_DIR/AGENTS.md.example" ]; then
        copy_template "$SCRIPT_DIR/AGENTS.md.example" "$CODEX_DIR/AGENTS.md" "AGENTS.md"
        sync_managed_block \
            "$SCRIPT_DIR/AGENTS.md.example" \
            "$CODEX_DIR/AGENTS.md" \
            "codex-memory" \
            "AGENTS.md (memory 節)"
    fi

    # COMMANDS.md
    if [ -f "$SCRIPT_DIR/COMMANDS.md" ]; then
        cp "$SCRIPT_DIR/COMMANDS.md" "$CODEX_DIR/COMMANDS.md"
        print_success "更新: COMMANDS.md"
    fi

    # Codex lifecycle hooks
    if [ -f "$SCRIPT_DIR/hooks.json.example" ]; then
        copy_template "$SCRIPT_DIR/hooks.json.example" "$CODEX_DIR/hooks.json" "hooks.json"
    fi

    # Hooks
    for hook in session-start session-end user-prompt-submit pre-tool-use stop pre-compact serena-hook; do
        local template="$SCRIPT_DIR/hooks/${hook}.sh.example"
        local target="$CODEX_DIR/hooks/${hook}.sh"

        if [ -f "$template" ]; then
            copy_template "$template" "$target" "hooks/${hook}.sh"
            chmod +x "$target" 2>/dev/null || true
        fi
    done

    print_success "テンプレートファイルのコピー完了"
}

copy_codex_skills() {
    # $1=overwrite: "1" のとき既存 bridge skill を上書き再コピー（--sync 用）。
    local overwrite="${1:-0}"
    print_header "Codex native skills のコピー"

    local skills_source="$SCRIPT_DIR/skills"
    local skills_target="$CODEX_DIR/skills"

    if [ ! -d "$skills_source" ]; then
        print_info "Codex native skills テンプレートはありません（スキップ）"
        return
    fi

    # 旧 install 方式の symlink (dangling 含む) が残っていると mkdir -p が失敗するため、
    # backup へ退避して実 directory を作り直す
    if [ -L "$skills_target" ]; then
        local skills_backup="${skills_target}.backup.$(date +%Y%m%d%H%M%S)"
        mv "$skills_target" "$skills_backup"
        print_warning "skills/ が symlink だったため退避しました: $skills_backup"
    fi

    mkdir -p "$skills_target"

    local skill_dir
    for skill_dir in "$skills_source"/*; do
        if [ ! -d "$skill_dir" ]; then
            continue
        fi

        local skill_name
        skill_name="$(basename "$skill_dir")"
        local target="$skills_target/$skill_name"

        if [ -e "$target" ]; then
            if [ "$overwrite" = "1" ]; then
                rm -rf "$target"
                cp -R "$skill_dir" "$target"
                print_success "更新: skills/$skill_name"
            else
                print_info "skills/$skill_name は既に存在します（スキップ）"
            fi
            continue
        fi

        cp -R "$skill_dir" "$target"
        print_success "作成: skills/$skill_name"
    done

    print_success "Codex native skills のコピー完了"
}

run_sync() {
    # 非対話の再同期。sync.sh to-local から呼ばれる想定。
    # symlink / テンプレは既存を壊さず、bridge skill のみ上書き再コピーする。
    print_header "Codex Configuration Sync"
    setup_directories
    create_symlinks
    copy_templates
    copy_codex_skills 1
    print_success "Codex sync 完了"
}

# =============================================================================
# Verify Installation
# =============================================================================

verify_installation() {
    print_header "インストールの確認"

    local errors=0

    # Check symlinks
    for resource in agents guidelines commands lib; do
        if [ -L "$CODEX_DIR/$resource" ]; then
            print_success "$resource/ のシンボリックリンクが存在します"
        else
            print_error "$resource/ のシンボリックリンクが見つかりません"
            ((errors++))
        fi
    done

    if [ -d "$CODEX_DIR/skills" ]; then
        print_success "skills/ は Codex native directory として存在します"
    else
        print_warning "skills/ が見つかりません（Codex 側で自動生成される場合があります）"
    fi

    # Check config files
    if [ -f "$CODEX_DIR/config.toml" ]; then
        print_success "config.toml が存在します"
    else
        print_warning "config.toml が見つかりません（オプション）"
    fi

    if [ -f "$CODEX_DIR/AGENTS.md" ]; then
        print_success "AGENTS.md が存在します"
    else
        print_warning "AGENTS.md が見つかりません（オプション）"
    fi

    if [ $errors -eq 0 ]; then
        echo ""
        print_success "インストールが正常に完了しました！"
    else
        echo ""
        print_error "インストールに問題があります。エラーを確認してください。"
        exit 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    case "${1:-}" in
        --doctor|doctor|check)
            run_doctor
            ;;
        --sync|sync)
            run_sync
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
    esac

    print_header "Codex Configuration Installer (Level 4)"

    echo "このスクリプトは Claude Code の共有リソースを Codex に同期します。"
    echo "シンボリックリンクにより agents, guidelines, commands, lib を共有します。skills は Codex native directory を維持します。"
    echo ""

    if ! confirm "インストールを開始しますか？" "y"; then
        echo "インストールをキャンセルしました。"
        exit 0
    fi

    check_prerequisites
    setup_directories
    create_symlinks
    copy_templates
    copy_codex_skills
    verify_installation

    echo ""
    print_info "次のステップ:"
    echo "  1. ~/.codex/config.toml を確認・編集してください"
    echo "  2. ~/.codex/hooks.json と ~/.codex/hooks/*.sh を必要に応じて確認"
    echo "  3. Codex を起動して Serena hooks / MCP を動作確認: codex"
    echo ""
    print_info "利用可能な機能:"
    echo "  - agents: Claude Code と共有"
    echo "  - skills: Codex native directory を維持（一部 bridge skill はテンプレートからコピー）"
    echo "  - guidelines: Claude Code と共有"
    echo "  - commands: Claude Code と共有"
    echo ""
}

# Run main function
main "$@"
