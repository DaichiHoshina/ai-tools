#!/bin/bash

set -euo pipefail

# =============================================================================
# Guidelines Summaries Auto-Generator
# guidelines/ 配下の詳細ガイドラインから summaries/ を自動生成
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GUIDELINES_DIR="$PROJECT_ROOT/claude-code/guidelines"
SUMMARIES_DIR="$GUIDELINES_DIR/summaries"

# Load print functions
LIB_DIR="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/print-functions.sh
source "$LIB_DIR/print-functions.sh" 2>/dev/null || {
    echo "⚠️  print-functions.sh not found, using basic echo"
    print_info() { echo "[INFO] $*"; }
    print_success() { echo "[✓] $*"; }
    print_error() { echo "[✗] $*" >&2; }
    print_warning() { echo "[!] $*"; }
}

# =============================================================================
# Functions
# =============================================================================

# サマリー自動生成（プレースホルダー）
generate_summary() {
    local category="$1"
    local output_file="$2"
    local source_dir="$3"

    print_info "Generating summary for ${category}..."

    # 実際の実装では、Claudeを使ってサマリー生成
    # ここではテンプレートを生成
    cat > "$output_file" <<EOF
# ${category} ガイドライン（サマリー版）

> **自動生成**: このファイルは generate-summaries.sh により自動生成されました

## 📚 詳細仕様一覧（${category}/）

$(find "$source_dir" -name "*.md" -type f | sort | while read -r file; do
    basename "$file" | sed 's/\.md$//' | xargs -I {} echo "- \`{}.md\`"
done)

## 主要原則

### 1. 基本原則

（詳細は ${category}/ 配下の個別ファイルを参照）

### 2. ベストプラクティス

（自動要約が必要な場合は、Claudeを利用）

---

**詳細**: [\`${category}/\`](../${category}/) ディレクトリを参照

EOF

    print_success "Generated: ${output_file}"
}

# 差分チェック
check_diff() {
    local file="$1"
    local backup="${file}.backup"

    if [ -f "$backup" ]; then
        if diff -q "$file" "$backup" > /dev/null 2>&1; then
            print_info "No changes: $(basename "$file")"
            rm "$backup"
        else
            print_warning "Changed: $(basename "$file")"
            print_info "Diff:"
            diff -u "$backup" "$file" || true
            print_info "Backup saved: ${backup}"
        fi
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_info "=== Guidelines Summaries Generator ==="
    print_info "Summaries Dir: ${SUMMARIES_DIR}"

    # サマリーディレクトリ作成
    mkdir -p "$SUMMARIES_DIR"

    # カテゴリ別にサマリー生成
    declare -A categories=(
        ["common"]="common"
        ["golang"]="languages"
        ["typescript"]="languages"
        ["nextjs-react"]="languages"
        ["infrastructure"]="infrastructure"
        ["design"]="design"
        ["security"]="common"
        ["technique"]="common"
    )

    for category in "${!categories[@]}"; do
        source_dir="$GUIDELINES_DIR/${categories[$category]}"
        output_file="$SUMMARIES_DIR/${category}-summary.md"

        if [ -d "$source_dir" ]; then
            # バックアップ作成
            if [ -f "$output_file" ]; then
                cp "$output_file" "${output_file}.backup"
            fi

            # サマリー生成
            generate_summary "$category" "$output_file" "$source_dir"

            # 差分チェック
            check_diff "$output_file"
        else
            print_warning "Source directory not found: ${source_dir}"
        fi
    done

    print_success "=== Generation Complete ==="
    print_info ""
    print_info "Next steps:"
    print_info "  1. Review generated summaries in: ${SUMMARIES_DIR}"
    print_info "  2. For AI-powered summarization, use:"
    print_info "     claude 'Summarize guidelines in ${GUIDELINES_DIR}/common/*.md'"
    print_info "  3. Sync to ~/.claude/: ./claude-code/sync.sh to-local"
}

# =============================================================================
# Execution
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
