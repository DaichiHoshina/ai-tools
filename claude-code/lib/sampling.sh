#!/usr/bin/env bash
# =============================================================================
# sampling.sh - 決定的サンプリング（Warning 5+6対応）
# Fisher-Yates shuffleによる決定的テストサンプリング
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/sampling.sh
#   
#   # ファイルリストをサンプリング
#   find . -name "*.test.js" | sample_items 0.1 "$seed"
#   
#   # シード生成
#   seed=$(generate_seed "$AGENT_ID")
#
# アルゴリズム:
#   Fisher-Yates shuffle with seeded PRNG → 先頭N件選択
#   同じシードで同じ順序を保証（決定的サンプリング）
#
# 境界値:
#   - サンプリング率: 0.01〜1.0
#   - 最小サンプルサイズ: 1
#   - 空リスト: 空出力（エラーなし）
#
# =============================================================================

set -euo pipefail

# --- 重複読み込み防止 ---
if [[ "${_SAMPLING_LOADED:-}" = "true" ]]; then
    return 0 2>/dev/null || true
fi
_SAMPLING_LOADED=true

# --- error-codes.sh の関数が利用可能な場合に使用 ---
_use_error_codes=false
if declare -f emit_error &>/dev/null; then
    _use_error_codes=true
fi

# =============================================================================
# サンプルサイズ計算
# =============================================================================

# サンプルサイズを計算
# 引数:
#   $1: 総数
#   $2: サンプリング率（0.01〜1.0）
# 出力: サンプルサイズ（最小1）
# 戻り値: 0=成功, 1=失敗
calculate_sample_size() {
    local total="$1"
    local rate="$2"
    
    # 境界値チェック
    if [[ $total -lt 0 ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E4003" "Total must be non-negative: $total"
        else
            echo "ERROR: Total must be non-negative: $total" >&2
        fi
        return 1
    fi
    
    # レート範囲チェック（bc で浮動小数点比較）
    if ! echo "$rate >= 0.01 && $rate <= 1.0" | bc -l | grep -q '^1$'; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E5001" "Sample rate must be 0.01-1.0: $rate"
        else
            echo "ERROR: Sample rate must be 0.01-1.0: $rate" >&2
        fi
        return 1
    fi
    
    # 空リスト対応
    if [[ $total -eq 0 ]]; then
        echo "0"
        return 0
    fi
    
    # サンプルサイズ計算
    local sample_size
    sample_size=$(echo "scale=0; ($total * $rate + 0.5) / 1" | bc)
    
    # 最小値1を保証
    if [[ $sample_size -lt 1 ]]; then
        sample_size=1
    fi
    
    # 総数を超えないように制限
    if [[ $sample_size -gt $total ]]; then
        sample_size=$total
    fi
    
    echo "$sample_size"
}

# =============================================================================
# シード生成
# =============================================================================

# エージェントIDからシード生成
# 引数:
#   $1: エージェントID（文字列）
# 出力: 数値シード（0-2^31-1）
# 戻り値: 0=成功, 1=失敗
generate_seed() {
    local agent_id="$1"
    
    if [[ -z "$agent_id" ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E4002" "Agent ID is required"
        else
            echo "ERROR: Agent ID is required" >&2
        fi
        return 1
    fi
    
    # MD5ハッシュから数値シードを生成
    local hash
    hash=$(echo -n "$agent_id" | md5sum | cut -d' ' -f1)
    
    if [[ -z "$hash" ]]; then
        if [[ $_use_error_codes = true ]]; then
            emit_error "E5002" "MD5 hash generation failed"
        else
            echo "ERROR: MD5 hash generation failed" >&2
        fi
        return 1
    fi
    
    # 先頭8文字を16進数→10進数変換（0-2^31-1に収める）
    local seed
    seed=$((16#${hash:0:8} % 2147483647))
    
    echo "$seed"
}

# =============================================================================
# Fisher-Yates Shuffle（決定的）
# =============================================================================

# シード付きランダム数生成（線形合同法）
# グローバル変数 _RANDOM_STATE を使用
_random_seeded() {
    # LCG パラメータ（glibc互換）
    local a=1103515245
    local c=12345
    local m=2147483648  # 2^31
    
    _RANDOM_STATE=$(( (a * _RANDOM_STATE + c) % m ))
    echo "$_RANDOM_STATE"
}

# Fisher-Yates shuffleでリストをシャッフル
# 引数:
#   $1: シード
#   stdin: 行区切りのアイテムリスト
# 出力: シャッフルされたリスト
_shuffle_items() {
    local seed="$1"
    _RANDOM_STATE=$seed
    
    # 配列に読み込み
    local items=()
    while IFS= read -r line; do
        items+=("$line")
    done
    
    local n=${#items[@]}
    
    # Fisher-Yates shuffle
    for ((i = n - 1; i > 0; i--)); do
        local j=$(( $(_random_seeded) % (i + 1) ))
        
        # swap items[i] and items[j]
        local temp="${items[$i]}"
        items[$i]="${items[$j]}"
        items[$j]="$temp"
    done
    
    # 出力
    for item in "${items[@]}"; do
        echo "$item"
    done
}

# =============================================================================
# サンプリング実行
# =============================================================================

# アイテムをサンプリング
# 引数:
#   $1: サンプリング率（0.01〜1.0）
#   $2: シード（数値）
#   stdin: 行区切りのアイテムリスト
# 出力: サンプリングされたアイテム
# 戻り値: 0=成功, 1=失敗
sample_items() {
    local rate="$1"
    local seed="$2"
    
    # 入力を配列に読み込み
    local items=()
    while IFS= read -r line; do
        items+=("$line")
    done
    
    local total=${#items[@]}
    
    # 空リスト対応
    if [[ $total -eq 0 ]]; then
        return 0
    fi
    
    # サンプルサイズ計算
    local sample_size
    sample_size=$(calculate_sample_size "$total" "$rate") || return 1
    
    # レート1.0の場合は全アイテムを返す（シャッフル不要）
    if [[ $(echo "$rate == 1.0" | bc -l) -eq 1 ]]; then
        for item in "${items[@]}"; do
            echo "$item"
        done
        return 0
    fi
    
    # Fisher-Yates shuffleでシャッフル
    local shuffled=()
    while IFS= read -r line; do
        shuffled+=("$line")
    done < <(for item in "${items[@]}"; do echo "$item"; done | _shuffle_items "$seed")
    
    # 先頭N件を出力
    for ((i = 0; i < sample_size; i++)); do
        echo "${shuffled[$i]}"
    done
}

# =============================================================================
# 便利関数
# =============================================================================

# ファイルリストをサンプリング（wrapper）
# 引数:
#   $1: パターン（例: "*.test.js"）
#   $2: サンプリング率
#   $3: エージェントID
# 出力: サンプリングされたファイルリスト
sample_files() {
    local pattern="$1"
    local rate="$2"
    local agent_id="$3"
    
    local seed
    seed=$(generate_seed "$agent_id") || return 1
    
    find . -name "$pattern" -type f | sample_items "$rate" "$seed"
}
