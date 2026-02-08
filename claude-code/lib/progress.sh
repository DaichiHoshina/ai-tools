#!/usr/bin/env bash
# =============================================================================
# progress.sh - セッション別進捗追跡（Critical 2対応）
# 複数セッション並列実行時のコンフリクト対策
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/progress.sh
#   
#   init_progress_dir
#   update_session_progress "$SESSION_ID" "implementation" 60 "Implementing timeout.sh"
#   read_session_progress "$SESSION_ID"
#
# ディレクトリ構造:
#   progress/
#   ├── sessions/
#   │   ├── session_abc123.md
#   │   └── session_def456.md
#   └── aggregated.md
#
# 環境変数:
#   PROGRESS_MAX_OUTPUT_BYTES=102400  # 最大出力サイズ（100KB）
#   PROGRESS_DIR=progress             # 進捗ディレクトリ
#
# =============================================================================

set -euo pipefail

# --- 重複読み込み防止 ---
if [[ "${_PROGRESS_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_PROGRESS_LOADED=true

# --- デフォルト値 ---
: "${PROGRESS_MAX_OUTPUT_BYTES:=102400}"  # 100KB
: "${PROGRESS_DIR:=progress}"

# --- error-codes.sh の関数が利用可能な場合に使用 ---
_use_error_codes=false
if declare -f emit_error &>/dev/null; then
    _use_error_codes=true
fi

# =============================================================================
# ディレクトリ管理
# =============================================================================

# 進捗ディレクトリを初期化
# 戻り値: 0=成功, 1=失敗
init_progress_dir() {
    local sessions_dir="${PROGRESS_DIR}/sessions"
    
    if ! mkdir -p "$sessions_dir" 2>/dev/null; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E3003" "Failed to create directory: $sessions_dir"
        else
            echo "ERROR: Failed to create directory: $sessions_dir" >&2
        fi
        return 1
    fi
    
    # .gitignore を作成（gitに含めない）
    local gitignore="${PROGRESS_DIR}/.gitignore"
    if [[ ! -f "$gitignore" ]]; then
        cat > "$gitignore" <<'EOF'
# 進捗ファイルは一時的なものなので、gitに含めない
*.md
sessions/
EOF
    fi
    
    return 0
}

# =============================================================================
# セッションID サニタイズ
# =============================================================================

# セッションIDをファイル名として安全にサニタイズ
# 引数:
#   $1: セッションID
# 出力: サニタイズされたセッションID
sanitize_session_id() {
    local session_id="$1"
    
    # パストラバーサル防止
    session_id="${session_id//\//_}"
    session_id="${session_id//\\/_}"
    session_id="${session_id//../_}"
    
    # 先頭のドットを削除（隠しファイル防止）
    session_id="${session_id#.}"
    
    # 特殊文字を削除（英数字、ハイフン、アンダースコアのみ許可）
    session_id=$(echo "$session_id" | tr -cd '[:alnum:]_-')
    
    # 長さ制限（最大64文字）
    if [[ ${#session_id} -gt 64 ]]; then
        session_id="${session_id:0:64}"
    fi
    
    echo "$session_id"
}

# =============================================================================
# 進捗ファイルパス
# =============================================================================

# セッション進捗ファイルのパスを取得
# 引数:
#   $1: セッションID
# 出力: ファイルパス
get_session_progress_path() {
    local session_id="$1"
    local sanitized
    sanitized=$(sanitize_session_id "$session_id")
    
    echo "${PROGRESS_DIR}/sessions/session_${sanitized}.md"
}

# =============================================================================
# 進捗更新
# =============================================================================

# セッション進捗を更新
# 引数:
#   $1: セッションID
#   $2: フェーズ（例: "planning", "implementation", "testing"）
#   $3: 進捗率（0-100）
#   $4: 説明テキスト
# 戻り値: 0=成功, 1=失敗
update_session_progress() {
    local session_id="$1"
    local phase="$2"
    local percentage="$3"
    local text="$4"
    
    # ディレクトリ初期化
    init_progress_dir || return 1
    
    local progress_file
    progress_file=$(get_session_progress_path "$session_id")
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 進捗率の境界値チェック
    if [[ $percentage -lt 0 ]]; then
        percentage=0
    elif [[ $percentage -gt 100 ]]; then
        percentage=100
    fi
    
    # 出力サイズチェック
    local text_size=${#text}
    if [[ $text_size -gt $PROGRESS_MAX_OUTPUT_BYTES ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E3004" "Output too large: ${text_size} bytes (max: ${PROGRESS_MAX_OUTPUT_BYTES})"
        else
            echo "WARNING: Output too large: ${text_size} bytes, truncating" >&2
        fi
        text="${text:0:$PROGRESS_MAX_OUTPUT_BYTES}"
        text="${text}... [truncated]"
    fi
    
    # 進捗ファイルを更新
    cat > "$progress_file" <<EOF
# Session Progress: ${session_id}

**Last Updated**: ${timestamp}

## Current Status

- **Phase**: ${phase}
- **Progress**: ${percentage}%
- **Description**: ${text}

## History

EOF
    
    # 履歴を追記（既存ファイルがある場合）
    if [[ -f "${progress_file}.history" ]]; then
        cat "${progress_file}.history" >> "$progress_file"
    fi
    
    # 履歴に今回の更新を追記
    echo "- [${timestamp}] ${phase} (${percentage}%): ${text}" >> "${progress_file}.history"
    
    return 0
}

# =============================================================================
# 進捗読み取り
# =============================================================================

# セッション進捗を読み取り
# 引数:
#   $1: セッションID
# 出力: 進捗内容（存在しない場合は空）
# 戻り値: 0=成功, 1=失敗
read_session_progress() {
    local session_id="$1"
    local progress_file
    progress_file=$(get_session_progress_path "$session_id")
    
    if [[ ! -f "$progress_file" ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E3005" "Progress file not found: $session_id"
        fi
        return 1
    fi
    
    cat "$progress_file"
}

# =============================================================================
# 集約
# =============================================================================

# 全セッションの進捗を集約
# 出力: 集約されたサマリー
aggregate_progress() {
    local sessions_dir="${PROGRESS_DIR}/sessions"
    local aggregated_file="${PROGRESS_DIR}/aggregated.md"
    
    if [[ ! -d "$sessions_dir" ]]; then
        echo "No progress data found"
        return 0
    fi
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$aggregated_file" <<EOF
# Aggregated Progress Report

**Generated**: ${timestamp}

## Active Sessions

EOF
    
    local session_count=0
    
    # 各セッションファイルを処理
    for progress_file in "$sessions_dir"/session_*.md; do
        if [[ ! -f "$progress_file" ]]; then
            continue
        fi
        
        session_count=$((session_count + 1))
        
        local session_id
        session_id=$(basename "$progress_file" .md | sed 's/^session_//')
        
        echo "### Session: $session_id" >> "$aggregated_file"
        echo "" >> "$aggregated_file"
        
        # 最新の状態行を抽出
        grep -A 5 "^## Current Status" "$progress_file" >> "$aggregated_file" 2>/dev/null || true
        
        echo "" >> "$aggregated_file"
    done
    
    if [[ $session_count -eq 0 ]]; then
        echo "No active sessions" >> "$aggregated_file"
    fi
    
    cat "$aggregated_file"
}

# =============================================================================
# クリーンアップ
# =============================================================================

# セッション進捗を削除
# 引数:
#   $1: セッションID
# 戻り値: 0=成功, 1=失敗
cleanup_session_progress() {
    local session_id="$1"
    local progress_file
    progress_file=$(get_session_progress_path "$session_id")
    
    if [[ -f "$progress_file" ]]; then
        rm -f "$progress_file"
        rm -f "${progress_file}.history"
    fi
}

# 古い進捗ファイルをクリーンアップ
# 引数:
#   $1: 日数（デフォルト: 7）
# 戻り値: 0=成功, 1=失敗
cleanup_old_progress() {
    local days="${1:-7}"
    local sessions_dir="${PROGRESS_DIR}/sessions"
    
    if [[ ! -d "$sessions_dir" ]]; then
        return 0
    fi
    
    # 7日以上古いファイルを削除
    find "$sessions_dir" -type f -name "session_*.md" -mtime "+${days}" -delete 2>/dev/null || true
    find "$sessions_dir" -type f -name "*.history" -mtime "+${days}" -delete 2>/dev/null || true
}
