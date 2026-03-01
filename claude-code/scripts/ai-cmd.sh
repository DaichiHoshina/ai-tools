#!/usr/bin/env bash
# =============================================================================
# ai - TAKTスマートラッパー
# リポジトリに応じたピースを自動選択し、最小限の引数でTAKTを実行
# =============================================================================
#
# Usage:
#   ai "タスクの説明"
#   ai "タスク" --pr           # 完了後にPR作成
#   ai "タスク" --branch feat/x  # ブランチ指定
#   ai "タスク" --tdd          # TDDモード
#   ai "タスク" --dry-run      # プロンプトプレビューのみ
#   ai "タスク" --piece NAME   # ピース明示指定
#
# =============================================================================

set -euo pipefail

# --- ヘルプ ---
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
    cat <<'HELP'
Usage: ai "タスクの説明" [options]

Options:
  --pr              完了後にPR自動作成
  --draft           ドラフトPRとして作成（--pr併用）
  --tdd             TDDモード（test-first）
  --branch NAME     ブランチ指定
  --piece NAME      ピース明示指定（自動検出を上書き）
  --dry-run         プロンプトプレビューのみ
  --issue N         GitHub Issue番号で実行
  -h, --help        このヘルプを表示

Examples:
  ai "認証機能を追加して"
  ai "バグを修正して" --pr
  ai "テストを追加" --tdd
  ai "#42"                    # GitHub Issue #42 を実行
HELP
    exit 0
fi

# --- タスク取得 ---
TASK=""
if [[ "${1:-}" =~ ^#([0-9]+)$ ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
    shift
else
    TASK="$1"
    shift
fi

# --- ピース自動検出 ---
_detect_piece() {
    # .takt/pieces/ にプロジェクト固有ピースがあれば優先
    if [[ -d ".takt/pieces" ]]; then
        local custom_piece
        custom_piece=$(find .takt/pieces -name '*.yaml' -exec grep -l '^name:' {} + 2>/dev/null \
            | while IFS= read -r f; do
                local name
                name=$(grep '^name:' "$f" | head -1 | sed 's/name: *//')
                # default-* 以外のカスタムピースを検出
                if [[ "$name" != default-* ]]; then
                    echo "$name"
                    break
                fi
            done)
        if [[ -n "$custom_piece" ]]; then
            echo "$custom_piece"
            return
        fi
    fi
    echo "default-mini"
}

PIECE=$(_detect_piece)
EXTRA_ARGS=()
DRY_RUN=false

# --- オプション解析 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pr)       EXTRA_ARGS+=(--auto-pr) ;;
        --draft)    EXTRA_ARGS+=(--draft) ;;
        --tdd)      PIECE="default-test-first-mini" ;;
        --branch)   EXTRA_ARGS+=(-b "$2"); shift ;;
        --piece)    PIECE="$2"; shift ;;
        --dry-run)  DRY_RUN=true ;;
        --issue)    ISSUE_NUM="$2"; shift ;;
        *)          EXTRA_ARGS+=("$1") ;;
    esac
    shift
done

# --- dry-run ---
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Piece: $PIECE"
    echo "---"
    exec takt prompt "$PIECE"
fi

# --- Claude Code内からの実行対応 ---
unset CLAUDECODE 2>/dev/null || true

# --- 実行 ---
echo "🎵 ai: piece=$PIECE"

if [[ -n "${ISSUE_NUM:-}" ]]; then
    exec takt -i "$ISSUE_NUM" -w "$PIECE" --create-worktree no "${EXTRA_ARGS[@]}"
elif [[ -n "$TASK" ]]; then
    exec takt -t "$TASK" -w "$PIECE" --create-worktree no "${EXTRA_ARGS[@]}"
else
    echo "ERROR: タスクまたはIssue番号を指定してください" >&2
    exit 1
fi
