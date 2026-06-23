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
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$REPO_ROOT/hooks"
RUNS=15
WARMUP=5
INCLUDE_RISKY=0
ONLY_HOOK=""
LOG_ENABLED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-risky) INCLUDE_RISKY=1; shift ;;
    --hook) ONLY_HOOK="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --warmup) WARMUP="$2"; shift 2 ;;
    --log) LOG_ENABLED=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$LOG_ENABLED" -eq 1 ]]; then
  LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_DIR}/hook-bench-$(date +%Y%m%d-%H%M%S).log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "# hook-bench log: $LOG_FILE"
  echo "# args: runs=$RUNS warmup=$WARMUP include_risky=$INCLUDE_RISKY only=${ONLY_HOOK:-all}"
  echo "# date: $(date '+%Y-%m-%d %H:%M:%S')"
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
    t0=$(now_ms)
    if echo "$input" | timeout 10 "$hook_path" >/dev/null 2>&1; then
      status="ok"
    else
      status="err"
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
  printf "%-30s  median=%4sms  p95=%4sms  last=%s\n" "$hook_name" "$median" "$p95" "$status"
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
