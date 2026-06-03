#!/usr/bin/env bash
# hook-bench-ci.sh - pre-push 用 hook パフォーマンス回帰検出スクリプト
#
# Usage:
#   ./scripts/hook-bench-ci.sh --check              # baseline と比較して 3 軸判定
#   ./scripts/hook-bench-ci.sh --update-baseline    # 現 HEAD で 6 run 計測し baseline 更新
#   ./scripts/hook-bench-ci.sh --hook NAME          # 単一 hook のみ対象
#
# Exit codes:
#   0 = pass または improvement のみ
#   1 = regression 検出
#   2 = 計測失敗 / baseline 不在
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${REPO_ROOT}/lib"

# lib/common.sh 経由で bash version check
# shellcheck source=../lib/common.sh
source "${LIB_DIR}/common.sh" 2>/dev/null || {
    # fallback: 最低限の version チェックのみ
    if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
        echo "ERROR: bash 5.0+ required (current: ${BASH_VERSION})" >&2
        exit 2
    fi
}

BASELINE_JSON="${REPO_ROOT}/.bench-baseline.json"
BENCH_SCRIPT="${SCRIPT_DIR}/hook-bench.sh"
RUNS=3
BENCH_WARMUP=2
BENCH_RUNS=7

# 主要 4 hook
DEFAULT_HOOKS=(
    "session-start.sh"
    "user-prompt-submit.sh"
    "pre-tool-use.sh"
    "post-tool-use.sh"
)

MODE=""
ONLY_HOOK=""

# 引数パース
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)          MODE="check"; shift ;;
        --update-baseline) MODE="update"; shift ;;
        --hook)           ONLY_HOOK="$2"; shift 2 ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 --check | --update-baseline [--hook NAME]" >&2
            exit 2
            ;;
    esac
done

if [[ -z "${MODE}" ]]; then
    echo "ERROR: --check or --update-baseline required" >&2
    exit 2
fi

# hook-bench.sh の存在確認
if [[ ! -x "${BENCH_SCRIPT}" ]]; then
    echo "ERROR: ${BENCH_SCRIPT} not found or not executable" >&2
    exit 2
fi

# 対象 hook リストを決定
if [[ -n "${ONLY_HOOK}" ]]; then
    # .sh を省略された場合も受け付ける
    [[ "${ONLY_HOOK}" != *.sh ]] && ONLY_HOOK="${ONLY_HOOK}.sh"
    TARGET_HOOKS=("${ONLY_HOOK}")
else
    TARGET_HOOKS=("${DEFAULT_HOOKS[@]}")
fi

# ms 単位 wallclock (bash 5.0+ EPOCHREALTIME builtin 利用、fork ゼロ)
now_ms() {
    # EPOCHREALTIME は秒の小数点付き (例: 1716472800.123456)
    local epoch_realtime="${EPOCHREALTIME}"
    # 整数部 * 1000 + 小数部の上 3 桁
    local sec="${epoch_realtime%.*}"
    local frac="${epoch_realtime#*.}"
    # frac は 6 桁保証されていないため 0 padding して先頭 3 桁を取る
    frac="${frac}000"
    frac="${frac:0:3}"
    echo "$((sec * 1000 + 10#${frac}))"
}

# hook-bench.sh を RUNS 回呼び出して median 値の配列を返す
# hook-bench.sh 自体が warmup 5 + 計測 10 を実行するため、その median を各 run の代表値とする
# 出力: 改行区切りの median ms 値 (RUNS 行)
bench_hook() {
    local hook_name="$1"
    local medians=()
    local i output median_val

    for ((i = 1; i <= RUNS; i++)); do
        # hook-bench.sh の stdout から median 値を parse
        # 出力例: "session-start.sh                    median=  76ms  p95=  78ms  last=ok"
        output=$("${BENCH_SCRIPT}" --hook "${hook_name}" --warmup "${BENCH_WARMUP}" --runs "${BENCH_RUNS}" 2>/dev/null || true)
        median_val=$(echo "${output}" | grep -oE 'median=[[:space:]]*[0-9]+ms' | grep -oE '[0-9]+' | head -1)
        if [[ -n "${median_val}" ]]; then
            medians+=("${median_val}")
        else
            # parse 失敗時は wallclock 計測にフォールバック
            local t0 t1
            t0=$(now_ms)
            "${BENCH_SCRIPT}" --hook "${hook_name}" --warmup "${BENCH_WARMUP}" --runs "${BENCH_RUNS}" >/dev/null 2>&1 || true
            t1=$(now_ms)
            medians+=($((t1 - t0)))
        fi
    done

    printf '%s\n' "${medians[@]}"
}

# 配列から median を算出 (整数 ms、切り捨て)
calc_median() {
    local sorted
    sorted=$(printf '%s\n' "$@" | sort -n)
    local n=$#
    local mid=$(( (n + 1) / 2 ))
    echo "${sorted}" | awk -v m="${mid}" 'NR==m'
}

# 配列から range (max - min) を算出
calc_range() {
    local sorted
    sorted=$(printf '%s\n' "$@" | sort -n)
    local min max
    min=$(echo "${sorted}" | head -1)
    max=$(echo "${sorted}" | tail -1)
    echo $((max - min))
}

# --update-baseline: 6 run 計測して baseline JSON を生成
do_update_baseline() {
    local commit
    commit=$(git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo "unknown")
    local updated_at
    updated_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    echo "Measuring ${#TARGET_HOOKS[@]} hook(s), ${RUNS} runs each..." >&2

    # JSON を組み立て
    local hooks_json="{}"
    local hook
    for hook in "${TARGET_HOOKS[@]}"; do
        echo "  Benchmarking ${hook}..." >&2

        local raw_times=()
        while IFS= read -r line; do
            raw_times+=("${line}")
        done < <(bench_hook "${hook}")

        local median
        median=$(calc_median "${raw_times[@]}")
        local range
        range=$(calc_range "${raw_times[@]}")

        # runs 配列を JSON 配列に変換
        local runs_json
        runs_json=$(printf '%s\n' "${raw_times[@]}" | jq -R 'tonumber' | jq -s '.')

        # hooks_json に追加
        hooks_json=$(echo "${hooks_json}" | jq \
            --arg name "${hook}" \
            --argjson median "${median}" \
            --argjson range "${range}" \
            --argjson runs "${runs_json}" \
            '.[$name] = {median_ms: $median, range_ms: $range, runs: $runs}')

        echo "    median=${median}ms  range=${range}ms  runs=[$(printf '%s,' "${raw_times[@]}" | sed 's/,$//')]" >&2
    done

    # baseline JSON 出力
    jq -n \
        --arg commit "${commit}" \
        --arg updated_at "${updated_at}" \
        --argjson hooks "${hooks_json}" \
        '{commit: $commit, updated_at: $updated_at, hooks: $hooks}' \
        > "${BASELINE_JSON}"

    echo "" >&2
    echo "Baseline updated: ${BASELINE_JSON}" >&2
    echo "  commit: ${commit}" >&2
    echo "  updated_at: ${updated_at}" >&2
}

# --check: baseline と現 HEAD を比較して 3 軸判定
do_check() {
    if [[ ! -f "${BASELINE_JSON}" ]]; then
        echo "ERROR: baseline not found: ${BASELINE_JSON}" >&2
        echo "  Run: ${SCRIPT_DIR}/hook-bench-ci.sh --update-baseline" >&2
        exit 2
    fi

    local baseline_commit
    baseline_commit=$(jq -r '.commit' "${BASELINE_JSON}" 2>/dev/null || echo "unknown")

    echo "Comparing against baseline (commit: ${baseline_commit})..." >&2
    echo "" >&2

    # ヘッダー行 (stderr に出力)
    printf "%-30s  %-10s  %-10s  %-8s  %-7s  %s\n" \
        "hook" "baseline" "current" "delta" "range" "verdict" >&2
    printf "%-30s  %-10s  %-10s  %-8s  %-7s  %s\n" \
        "----" "--------" "-------" "-----" "-----" "-------" >&2

    local has_regression=0
    local has_improvement=0

    local hook
    for hook in "${TARGET_HOOKS[@]}"; do
        # baseline から値を取得
        local baseline_median baseline_range baseline_runs_json
        baseline_median=$(jq -r --arg h "${hook}" '.hooks[$h].median_ms // empty' "${BASELINE_JSON}" 2>/dev/null)
        baseline_range=$(jq -r --arg h "${hook}" '.hooks[$h].range_ms // empty' "${BASELINE_JSON}" 2>/dev/null)
        baseline_runs_json=$(jq -c --arg h "${hook}" '.hooks[$h].runs // []' "${BASELINE_JSON}" 2>/dev/null)

        if [[ -z "${baseline_median}" ]]; then
            printf "%-30s  %-10s  %-10s  %-8s  %-7s  %s\n" \
                "${hook}" "N/A" "-" "-" "-" "no-baseline" >&2
            continue
        fi

        # 現在の計測
        echo "  Measuring ${hook}..." >&2
        local raw_times=()
        while IFS= read -r line; do
            raw_times+=("${line}")
        done < <(bench_hook "${hook}")

        local current_median
        current_median=$(calc_median "${raw_times[@]}")
        local current_range
        current_range=$(calc_range "${raw_times[@]}")

        # delta 計算 (整数 ms)
        local delta=$(( current_median - baseline_median ))
        local delta_str
        if [[ ${delta} -ge 0 ]]; then
            delta_str="+${delta}.0"
        else
            delta_str="${delta}.0"
        fi

        # range 表示 (baseline→current)
        local range_str="${baseline_range}→${current_range}"

        # 3 軸判定
        local verdict="pass"

        # regression: delta > 10ms
        if [[ ${delta} -gt 10 ]]; then
            verdict="REGRESSION"
            has_regression=1
        else
            # improvement 判定:
            #   delta < -5 AND current.range < baseline.range
            #   AND all current.runs[i] < baseline.median
            if [[ ${delta} -lt -5 ]] && [[ ${current_range} -lt ${baseline_range} ]]; then
                # 全 run が baseline.median 未満かチェック
                local all_below=1
                local r
                for r in "${raw_times[@]}"; do
                    if [[ ${r} -ge ${baseline_median} ]]; then
                        all_below=0
                        break
                    fi
                done
                if [[ ${all_below} -eq 1 ]]; then
                    verdict="improvement"
                    has_improvement=1
                fi
            fi
        fi

        printf "%-30s  %-10s  %-10s  %-8s  %-7s  %s\n" \
            "${hook}" \
            "${baseline_median}.0ms" \
            "${current_median}.0ms" \
            "${delta_str}" \
            "${range_str}" \
            "${verdict}" >&2
    done

    echo "" >&2

    if [[ ${has_regression} -eq 1 ]]; then
        echo "RESULT: REGRESSION detected. Push blocked." >&2
        echo "  Fix the regression or update baseline with: ${SCRIPT_DIR}/hook-bench-ci.sh --update-baseline" >&2
        exit 1
    fi

    if [[ ${has_improvement} -eq 1 ]]; then
        echo "RESULT: improvement detected (no regression)." >&2
        echo "  → run --update-baseline to commit new baseline" >&2
    else
        echo "RESULT: all pass." >&2
    fi

    exit 0
}

# エントリポイント
case "${MODE}" in
    update) do_update_baseline ;;
    check)  do_check ;;
esac
