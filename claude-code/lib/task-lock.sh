#!/usr/bin/env bash
# =============================================================================
# task-lock.sh - TTL付きタスクロック（Warning 4対応）
# 並列セッション実行時のタスク重複防止
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/common.sh
#   load_lib "timeout.sh"
#   load_lib "task-lock.sh"
#   
#   if acquire_lock "task-123" "$AGENT_ID"; then
#     # タスク実行
#     release_lock "task-123" "$AGENT_ID"
#   fi
#
# ロック機構:
#   - ファイルベースのロック（.locks/ ディレクトリ）
#   - TTL付き（デフォルト1時間）
#   - 冪等性保証（同じエージェントが再取得可能）
#   - 期限切れロックは自動解放
#
# 環境変数:
#   LOCK_TTL_SECONDS=3600  # ロックTTL（デフォルト1時間）
#   LOCK_DIR=.locks        # ロックディレクトリ
#
# 依存:
#   - timeout.sh （get_epoch関数）
#
# =============================================================================

set -euo pipefail

# --- 重複読み込み防止 ---
if [[ "${_TASK_LOCK_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_TASK_LOCK_LOADED=true

# --- 依存チェック ---
if ! declare -f get_epoch &>/dev/null; then
    echo "ERROR: task-lock.sh requires timeout.sh (get_epoch function)" >&2
    exit 1
fi

# --- デフォルト値 ---
: "${LOCK_TTL_SECONDS:=3600}"  # 1時間
: "${LOCK_DIR:=.locks}"

# --- error-codes.sh の関数が利用可能な場合に使用 ---
_use_error_codes=false
if declare -f emit_error &>/dev/null; then
    _use_error_codes=true
fi

# =============================================================================
# ロックディレクトリ管理
# =============================================================================

# ロックディレクトリを初期化
_init_lock_dir() {
    if [[ ! -d "$LOCK_DIR" ]]; then
        mkdir -p "$LOCK_DIR" 2>/dev/null || {
            if [[ $_use_error_codes = true ]]; then
                emit_error "E2001" "Failed to create lock directory: $LOCK_DIR"
            else
                echo "ERROR: Failed to create lock directory: $LOCK_DIR" >&2
            fi
            return 1
        }
    fi
    
    # .gitignore を作成
    local gitignore="${LOCK_DIR}/.gitignore"
    if [[ ! -f "$gitignore" ]]; then
        cat > "$gitignore" <<'EOF'
# ロックファイルは一時的なものなので、gitに含めない
*.lock
EOF
    fi
}

# =============================================================================
# タスクID サニタイズ
# =============================================================================

# タスクIDをファイル名として安全にサニタイズ
_sanitize_task_id() {
    local task_id="$1"
    
    # パストラバーサル防止
    task_id="${task_id//\//_}"
    task_id="${task_id//\\/_}"
    task_id="${task_id//../_}"
    
    # 先頭のドットを削除
    task_id="${task_id#.}"
    
    # 特殊文字を削除
    task_id=$(echo "$task_id" | tr -cd '[:alnum:]_-')
    
    # 長さ制限
    if [[ ${#task_id} -gt 64 ]]; then
        task_id="${task_id:0:64}"
    fi
    
    echo "$task_id"
}

# =============================================================================
# ロックファイルパス
# =============================================================================

# ロックファイルのパスを取得
_get_lock_path() {
    local task_id="$1"
    local sanitized
    sanitized=$(_sanitize_task_id "$task_id")
    
    echo "${LOCK_DIR}/task_${sanitized}.lock"
}

# =============================================================================
# ロック状態確認
# =============================================================================

# ロック状態を確認
# 引数:
#   $1: タスクID
# 出力: UNLOCKED | LOCKED | EXPIRED
check_lock() {
    local task_id="$1"
    local lock_file
    lock_file=$(_get_lock_path "$task_id")
    
    # ロックファイルが存在しない
    if [[ ! -f "$lock_file" ]]; then
        echo "UNLOCKED"
        return 0
    fi
    
    # ロックファイルを読み取り
    local lock_time
    local lock_owner
    
    if ! lock_time=$(head -n 1 "$lock_file" 2>/dev/null); then
        echo "UNLOCKED"
        return 0
    fi
    
    lock_owner=$(sed -n '2p' "$lock_file" 2>/dev/null || echo "unknown")
    
    # TTLチェック
    local now
    now=$(get_epoch)
    local elapsed=$((now - lock_time))
    
    if [[ $elapsed -ge $LOCK_TTL_SECONDS ]]; then
        echo "EXPIRED"
        return 0
    fi
    
    echo "LOCKED"
}

# =============================================================================
# ロック取得
# =============================================================================

# ロックを取得
# 引数:
#   $1: タスクID
#   $2: エージェントID
# 戻り値: 0=取得成功, 1=取得失敗
acquire_lock() {
    local task_id="$1"
    local agent_id="$2"
    
    _init_lock_dir || return 1
    
    local lock_file
    lock_file=$(_get_lock_path "$task_id")
    
    # ロック状態確認
    local lock_status
    lock_status=$(check_lock "$task_id")
    
    case "$lock_status" in
        UNLOCKED|EXPIRED)
            # ロック取得
            local now
            now=$(get_epoch)
            
            cat > "$lock_file" <<EOF
$now
$agent_id
EOF
            return 0
            ;;
        
        LOCKED)
            # 既存ロックの所有者を確認
            local current_owner
            current_owner=$(sed -n '2p' "$lock_file" 2>/dev/null || echo "")
            
            # 同じエージェントの場合は冪等（再取得成功）
            if [[ "$current_owner" = "$agent_id" ]]; then
                return 0
            fi
            
            # 別のエージェントがロック中
            if [[ $_use_error_codes = true ]]; then
                emit_error "E2004" "Task locked by another agent: $current_owner"
            else
                echo "ERROR: Task locked by another agent: $current_owner" >&2
            fi
            return 1
            ;;
    esac
}

# =============================================================================
# ロック解放
# =============================================================================

# ロックを解放
# 引数:
#   $1: タスクID
#   $2: エージェントID
# 戻り値: 0=解放成功, 1=解放失敗
release_lock() {
    local task_id="$1"
    local agent_id="$2"
    
    local lock_file
    lock_file=$(_get_lock_path "$task_id")
    
    # ロックファイルが存在しない
    if [[ ! -f "$lock_file" ]]; then
        return 0  # 既に解放済み（冪等）
    fi
    
    # 所有者確認
    local current_owner
    current_owner=$(sed -n '2p' "$lock_file" 2>/dev/null || echo "")
    
    if [[ "$current_owner" != "$agent_id" ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E2005" "Lock owner mismatch: expected $agent_id, got $current_owner"
        else
            echo "ERROR: Lock owner mismatch: expected $agent_id, got $current_owner" >&2
        fi
        return 1
    fi
    
    # ロック解放
    rm -f "$lock_file"
    return 0
}

# =============================================================================
# クリーンアップ
# =============================================================================

# 期限切れロックを一括クリーンアップ
# 戻り値: 削除したロック数
cleanup_expired_locks() {
    _init_lock_dir || return 0
    
    local count=0
    
    for lock_file in "$LOCK_DIR"/task_*.lock; do
        if [[ ! -f "$lock_file" ]]; then
            continue
        fi
        
        # タスクIDを抽出
        local task_id
        task_id=$(basename "$lock_file" .lock | sed 's/^task_//')
        
        # ロック状態確認
        local lock_status
        lock_status=$(check_lock "$task_id")
        
        if [[ "$lock_status" = "EXPIRED" ]]; then
            rm -f "$lock_file"
            count=$((count + 1))
        fi
    done
    
    echo "$count"
}

# =============================================================================
# デバッグ用
# =============================================================================

# ロック情報を表示
list_locks() {
    _init_lock_dir || return 0
    
    echo "Active Locks:"
    echo ""
    
    for lock_file in "$LOCK_DIR"/task_*.lock; do
        if [[ ! -f "$lock_file" ]]; then
            echo "No active locks"
            return 0
        fi
        
        local task_id
        task_id=$(basename "$lock_file" .lock | sed 's/^task_//')
        
        local lock_time
        lock_time=$(head -n 1 "$lock_file" 2>/dev/null || echo "0")
        
        local lock_owner
        lock_owner=$(sed -n '2p' "$lock_file" 2>/dev/null || echo "unknown")
        
        local lock_status
        lock_status=$(check_lock "$task_id")
        
        local now
        now=$(get_epoch)
        local elapsed=$((now - lock_time))
        
        echo "- Task: $task_id"
        echo "  Owner: $lock_owner"
        echo "  Status: $lock_status"
        echo "  Elapsed: ${elapsed}s"
        echo ""
    done
}
