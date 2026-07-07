#!/usr/bin/env bash
# Phase 2: hook 発火コスト計測
# 各 hook に典型 input JSON を渡し N 回実行、median/p95 を出す。
# 副作用ある hook (pre-compact / stop / worktree-remove) は skip。
#
# Usage:
#   ./scripts/hook-bench.sh                  # 全 hook 計測 (skip 対象除外)
#   ./scripts/hook-bench.sh --include-risky  # skip 対象も含む (要注意)
#   ./scripts/hook-bench.sh --hook NAME      # 単一 hook のみ
#   ./scripts/hook-bench.sh --runs 20        # 計測回数 (default 15, warmup 5 + 計測 10)
#   ./scripts/hook-bench.sh --log            # ~/.claude/logs/hook-bench-<ts>.log に tee 保存
#   ./scripts/hook-bench.sh --diff           # 直前 log と median 比較 (±20% 超で WARN 表示)
#   ./scripts/hook-bench.sh --diff-threshold 30  # WARN 閾値 (%、default 20)
set -euo pipefail

# 連想配列 (declare -A) を使うため bash 4+ が必須。cron の login shell 経由で
# 3.2 が呼ばれると `declare: -A: invalid option` になるため早期に検知する。
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "ERROR: hook-bench.sh requires bash 4+, running on ${BASH_VERSION}." >&2
  echo "       plist/cron の interpreter を bash 4+ (例: /opt/homebrew/bin/bash) に固定してください。" >&2
  exit 3
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$REPO_ROOT/hooks"
LOG_DIR="${HOME}/.claude/logs"
RUNS=15
WARMUP=5
INCLUDE_RISKY=0
ONLY_HOOK=""
LOG_ENABLED=0
DIFF_ENABLED=0
DIFF_THRESHOLD=20

# timeout は macOS 標準に無く homebrew coreutils のみ (/opt/homebrew/bin/timeout)。
# launchd/cron の最小 PATH では見つからず、hook が実行されず全 err になるため
# 絶対 path で解決し、無ければ timeout なしで実行する。
TIMEOUT_BIN=""
for cand in "$(command -v timeout 2>/dev/null)" /opt/homebrew/bin/timeout /usr/local/bin/timeout; do
  if [[ -x "$cand" ]]; then TIMEOUT_BIN="$cand"; break; fi
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-risky) INCLUDE_RISKY=1; shift ;;
    --hook) ONLY_HOOK="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --warmup) WARMUP="$2"; shift 2 ;;
    --log) LOG_ENABLED=1; shift ;;
    --diff) DIFF_ENABLED=1; shift ;;
    --diff-threshold) DIFF_THRESHOLD="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# --diff: 今 run の log 生成より前に prev log の median を読み込む
declare -A PREV_MEDIAN=()
PREV_LOG=""
if [[ "$DIFF_ENABLED" -eq 1 ]]; then
  if [[ -d "$LOG_DIR" ]]; then
    # mtime 降順で 1 件、ls -t は read-time も含むため stat ベース
    # 日付形式 (hook-bench-YYYYMMDD-*.log) のみ対象。cron の stderr/stdout log
    # (hook-bench-cron.*.log) を prev として誤選択しないよう数字始まりに限定する。
    PREV_LOG=$(find "$LOG_DIR" -maxdepth 1 -name 'hook-bench-[0-9]*.log' -type f -print0 2>/dev/null \
      | xargs -0 ls -t 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$PREV_LOG" && -f "$PREV_LOG" ]]; then
    # "hook-name  median= NNms  p95= ..." 行から median 抽出
    while IFS= read -r line; do
      name=$(awk '{print $1}' <<<"$line")
      med=$(sed -E 's/.*median=[[:space:]]*([0-9]+)ms.*/\1/' <<<"$line")
      [[ -n "$name" && "$med" =~ ^[0-9]+$ ]] && PREV_MEDIAN["$name"]="$med"
    done < <(grep -E 'median=[[:space:]]*[0-9]+ms' "$PREV_LOG" || true)
  else
    echo "[hook-bench] --diff: prev log 不在 (${LOG_DIR}/hook-bench-*.log なし)、--log で baseline 作成してから再実行" >&2
  fi
fi

if [[ "$LOG_ENABLED" -eq 1 ]]; then
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_DIR}/hook-bench-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "# hook-bench log: $LOG_FILE"
  echo "# args: runs=$RUNS warmup=$WARMUP include_risky=$INCLUDE_RISKY only=${ONLY_HOOK:-all} diff=$DIFF_ENABLED"
  echo "# date: $(date '+%Y-%m-%d %H:%M:%S')"
  [[ -n "$PREV_LOG" ]] && echo "# diff prev: $PREV_LOG"
  echo ""
fi

# skip 対象: 外部プロセス spawn / 通知発火 / worktree 操作
SKIP_HOOKS=(pre-compact.sh stop.sh stop-failure.sh worktree-remove.sh serena-hook.sh)

# 各 hook の入力 JSON (Claude Code 公式 spec 準拠の最小モック)
make_input() {
  local hook="$1"
  case "$hook" in
    session-start.sh)
      echo '{"session_id":"bench","transcript_path":"/tmp/bench.jsonl","cwd":"/tmp","source":"startup"}'
      ;;
    session-end.sh)
      echo '{"session_id":"bench","transcript_path":"/tmp/bench.jsonl","cwd":"/tmp","reason":"clear"}'
      ;;
    pre-tool-use.sh)
      echo '{"session_id":"bench","tool_name":"Bash","tool_input":{"command":"ls","description":"list"}}'
      ;;
    post-tool-use.sh)
      echo '{"session_id":"bench","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{"stdout":"","stderr":"","exit_code":0}}'
      ;;
    post-tool-use-failure.sh)
      echo '{"session_id":"bench","tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"stderr":"err","exit_code":1}}'
      ;;
    user-prompt-submit.sh)
      echo '{"session_id":"bench","prompt":"hello"}'
      ;;
    subagent-start.sh)
      echo '{"session_id":"bench","agent_type":"Explore","prompt":"test","agent_id":"a1"}'
      ;;
    subagent-stop.sh)
      echo '{"session_id":"bench","agent_id":"a1","agent_type":"Explore"}'
      ;;
    task-completed.sh)
      echo '{"session_id":"bench","task_id":"t1","status":"completed"}'
      ;;
    teammate-idle.sh)
      echo '{"session_id":"bench","teammate":"dev1","idle_seconds":60}'
      ;;
    permission-denied.sh)
      echo '{"session_id":"bench","tool_name":"Bash","reason":"denied"}'
      ;;
    setup.sh)
      echo '{"session_id":"bench","init_mode":"init-only"}'
      ;;
    post-compact-reload.sh)
      echo '{"session_id":"bench","transcript_path":"/tmp/bench.jsonl","cwd":"/tmp","trigger":"auto"}'
      ;;
    *)
      echo '{"session_id":"bench"}'
      ;;
  esac
}

# 配列要素含有チェック
contains() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

# ms 単位 wallclock (date +%s%N が macOS で非対応のため python3 fallback)
now_ms() {
  python3 -c 'import time; print(int(time.time()*1000))'
}

bench_one() {
  local hook_path="$1"
  local hook_name; hook_name="$(basename "$hook_path")"
  local input; input=$(make_input "$hook_name")
  local times=()
  local i t0 t1 status

  for ((i=1; i<=RUNS; i++)); do
    # hook を bash 4+ ($BASH = 実行中の interpreter、冒頭ガードで 4+ 保証) で明示起動する。
    # shebang (#!/usr/bin/env bash) 任せだと最小 PATH で 3.2 を拾い、hook 内の
    # source 先 (lib/jp-quality-check.sh の declare -A 等) が壊れて全 err になる。
    t0=$(now_ms)
    if [[ -n "$TIMEOUT_BIN" ]]; then
      echo "$input" | "$TIMEOUT_BIN" 10 "$BASH" "$hook_path" >/dev/null 2>&1 && status="ok" || status="err"
    else
      echo "$input" | "$BASH" "$hook_path" >/dev/null 2>&1 && status="ok" || status="err"
    fi
    t1=$(now_ms)
    if (( i > WARMUP )); then
      times+=($((t1 - t0)))
    fi
  done

  # ソート → median, p95
  local sorted; sorted=$(printf '%s\n' "${times[@]}" | sort -n)
  local n; n=$(echo "$sorted" | wc -l | tr -d ' ')
  local median p95
  median=$(echo "$sorted" | awk -v n="$n" 'NR==int((n+1)/2)')
  p95=$(echo "$sorted" | awk -v n="$n" 'NR==int(n*0.95+0.5)')

  local diff_suffix=""
  if [[ "$DIFF_ENABLED" -eq 1 && -n "${PREV_MEDIAN[$hook_name]:-}" ]]; then
    local prev="${PREV_MEDIAN[$hook_name]}"
    if [[ "$prev" -gt 0 ]]; then
      local delta_pct
      delta_pct=$(awk -v c="$median" -v p="$prev" 'BEGIN{printf "%+d", (c-p)*100/p}')
      local abs_pct=${delta_pct#+}; abs_pct=${abs_pct#-}
      if [[ "$abs_pct" -ge "$DIFF_THRESHOLD" ]]; then
        diff_suffix=" [WARN ${delta_pct}% vs prev=${prev}ms]"
      else
        diff_suffix=" [diff ${delta_pct}% vs prev=${prev}ms]"
      fi
    fi
  fi

  printf "%-30s  median=%4sms  p95=%4sms  last=%s%s\n" "$hook_name" "$median" "$p95" "$status" "$diff_suffix"
}

# ベースライン: 空プロセス起動コスト
echo "=== ベースライン (bash -c 'exit 0' x10 median) ==="
base_times=()
for i in {1..15}; do
  t0=$(now_ms); bash -c 'exit 0'; t1=$(now_ms)
  (( i > 5 )) && base_times+=($((t1 - t0)))
done
base_sorted=$(printf '%s\n' "${base_times[@]}" | sort -n)
base_n=$(echo "$base_sorted" | wc -l | tr -d ' ')
base_median=$(echo "$base_sorted" | awk -v n="$base_n" 'NR==int((n+1)/2)')
echo "  bash spawn median = ${base_median}ms"
echo ""

echo "=== Hook 計測 (warmup=${WARMUP}, runs=${RUNS}) ==="
for hook in "$HOOK_DIR"/*.sh; do
  name=$(basename "$hook")
  if [[ -n "$ONLY_HOOK" ]]; then
    [[ "$name" == "$ONLY_HOOK" || "$name" == "${ONLY_HOOK}.sh" ]] || continue
  fi
  if [[ "$INCLUDE_RISKY" -eq 0 ]] && contains "$name" "${SKIP_HOOKS[@]}"; then
    printf "%-30s  [skip: 副作用あり、--include-risky で含む]\n" "$name"
    continue
  fi
  bench_one "$hook"
done
