#!/usr/bin/env bash
# Claude Code 環境のヘルスチェック wrapper
# usage-stats (commands/skills 0 利用) + hook-bench (発火コスト) + plans staleness を統合実行、
# markdown 形式で結果を出力する。
#
# Usage:
#   ./scripts/health-check.sh                    # stdout に markdown
#   ./scripts/health-check.sh --out FILE         # ファイル出力
#   ./scripts/health-check.sh --bench-skip       # hook-bench を省略 (高速)
#   ./scripts/health-check.sh --bench-repeats N  # hook-bench を N 回反復、median-of-medians を出力 (default 1)
#   ./scripts/health-check.sh --days N           # usage-stats 期間 (default 90)
#   ./scripts/health-check.sh --plans-skip       # plans staleness check を省略
#   ./scripts/health-check.sh --plans-stale-days N  # plans staleness threshold (default 14)
#
# 異常ハイライト基準:
#   - usage: 90日0利用 commands/skills
#   - bench: median 100ms 超 hook (累積影響大の累計コスト想定)
#   - plans: 14日超 mtime plan file
# snapshot 推奨: --bench-repeats 3 で system load variance を抑止
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAYS=90
OUT_FILE=""
BENCH_SKIP=0
BENCH_REPEATS=1
PLANS_SKIP=0
PLANS_STALE_DAYS=14

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_FILE="$2"; shift 2 ;;
    --bench-skip) BENCH_SKIP=1; shift ;;
    --bench-repeats) BENCH_REPEATS="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --plans-skip) PLANS_SKIP=1; shift ;;
    --plans-stale-days) PLANS_STALE_DAYS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! [[ "$BENCH_REPEATS" =~ ^[1-9][0-9]*$ ]]; then
  echo "--bench-repeats must be a positive integer" >&2
  exit 2
fi

if ! [[ "$PLANS_STALE_DAYS" =~ ^(0|[1-9][0-9]*)$ ]]; then
  echo "--plans-stale-days must be a non-negative integer" >&2
  exit 2
fi

TODAY=$(date +%Y-%m-%d)

render_plans_staleness() {
  local threshold_days="$1"
  local plans_dir="${HOME}/.claude/plans"

  if [ ! -d "$plans_dir" ]; then
    echo "✓ clean (plans directory not found)"
    return
  fi

  local current_epoch
  current_epoch=$(date +%s)

  local stale_names=()
  local stale_ages=()
  local stale_sizes=()
  local found_any=0

  while IFS= read -r -d '' plan_file; do
    [ -f "$plan_file" ] || continue
    local mtime_epoch
    mtime_epoch=$(stat -f "%m" "$plan_file" 2>/dev/null) || continue
    local age_seconds=$(( current_epoch - mtime_epoch ))
    local age_days=$(( age_seconds / 86400 ))

    if [ "$age_days" -gt "$threshold_days" ]; then
      found_any=1
      local size_kb
      size_kb=$(( $(stat -f "%z" "$plan_file" 2>/dev/null || echo 0) / 1024 ))
      local filename
      filename=$(basename "$plan_file")
      stale_names+=("$filename")
      stale_ages+=("$age_days")
      stale_sizes+=("$size_kb")
    fi
  done < <(find "$plans_dir" -maxdepth 1 -type f -name "*.md" -print0)

  if [ "$found_any" -eq 0 ]; then
    echo "✓ clean"
  else
    echo "| file | age (days) | size (KB) |"
    echo "|---|---|---|"
    for i in "${!stale_names[@]}"; do
      printf "| \`%s\` | %d | %d |\n" "${stale_names[$i]}" "${stale_ages[$i]}" "${stale_sizes[$i]}"
    done
    echo ""
    printf "Proposed deletion: \`find %s -maxdepth 1 -name '*.md' -mtime +%d -delete\`\n" "$plans_dir" "$threshold_days"
  fi
}

render() {
  echo "# Claude Code Health Check ($TODAY)"
  echo ""
  echo "## Usage (過去 ${DAYS} 日 0 利用)"
  echo ""
  echo "> 注: この metric は **user 直接 invocation のみ** カウント。\`/flow\` Skill() auto-launch / \`detect-from-keywords.sh\` keyword 検知 / \`settings.json skillOverrides\` active / agents / hooks / bats test からの間接参照は乗らない。prune 判断には必ず \`grep -rn '<name>' ~/ai-tools/claude-code/\` で cross-ref 確認すること (2026-05-24 知見)。"
  echo ""
  echo '```'
  "$SCRIPT_DIR/usage-stats.sh" --days "$DAYS" --zero
  echo '```'
  echo ""
  if [[ "$BENCH_SKIP" -eq 1 ]]; then
    echo "## Hook Bench"
    echo ""
    echo "(--bench-skip 指定により省略)"
    echo ""
  elif [[ "$BENCH_REPEATS" -eq 1 ]]; then
    echo "## Hook Bench (median 100ms 超は要点検)"
    echo ""
    echo '```'
    "$SCRIPT_DIR/hook-bench.sh"
    echo '```'
    echo ""
  else
    echo "## Hook Bench (median 100ms 超は要点検、bench-repeats=${BENCH_REPEATS} の median-of-medians)"
    echo ""
    echo '```'
    local tmpdir; tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' RETURN
    local i
    for ((i=1; i<=BENCH_REPEATS; i++)); do
      "$SCRIPT_DIR/hook-bench.sh" > "$tmpdir/run-$i.txt" 2>&1
    done
    python3 - "$BENCH_REPEATS" "$tmpdir"/run-*.txt <<'PY'
import re, sys
from collections import defaultdict
repeats = int(sys.argv[1])
files = sys.argv[2:]
medians = defaultdict(list)
baselines = []
skips = {}
hook_re = re.compile(r'^([a-z][\w\-]*\.sh)\s+median=\s*(\d+)ms')
skip_re = re.compile(r'^([a-z][\w\-]*\.sh)\s+\[skip:.*\]\s*$')
base_re = re.compile(r'bash spawn median\s*=\s*(\d+)ms')
for path in files:
    with open(path) as f:
        for line in f:
            m = base_re.search(line)
            if m:
                baselines.append(int(m.group(1)))
                continue
            m = skip_re.match(line)
            if m:
                skips[m.group(1)] = line.rstrip()
                continue
            m = hook_re.match(line)
            if m:
                medians[m.group(1)].append(int(m.group(2)))
def med(xs):
    s = sorted(xs)
    return s[(len(s)-1)//2]
if baselines:
    print(f"  bash spawn median (median-of-{len(baselines)} runs) = {med(baselines)}ms")
print("")
print(f"=== Hook 計測 (warmup=5, runs=15, repeats={repeats}) ===")
for name in sorted(set(list(medians) + list(skips))):
    if name in skips:
        print(skips[name])
        continue
    vs = medians[name]
    print(f"{name:<30}  median={med(vs):>4d}ms  min={min(vs):>4d}ms  max={max(vs):>4d}ms  (n={len(vs)})")
PY
    echo '```'
    echo ""
  fi
  echo "## Plans Staleness (${PLANS_STALE_DAYS}日超 mtime)"
  echo ""
  echo '```'
  if [[ "$PLANS_SKIP" -eq 1 ]]; then
    echo "(--plans-skip 指定により省略)"
  else
    render_plans_staleness "$PLANS_STALE_DAYS"
  fi
  echo '```'
  echo ""
  echo "## Death Reference (_archive/ のファイル名で active 参照が残存)"
  echo ""
  echo '```'
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [ -d "$ROOT/_archive" ]; then
    # active 側の同名衝突を除外するため事前に名前一覧を作成
    active_names=""
    [ -d "$ROOT/commands" ] && active_names+=$(find "$ROOT/commands" -maxdepth 1 -type f -name "*.md" -exec basename {} .md \; 2>/dev/null)
    active_names+=$'\n'
    [ -d "$ROOT/skills" ] && active_names+=$(find "$ROOT/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null)
    active_names+=$'\n'
    [ -d "$ROOT/agents" ] && active_names+=$(find "$ROOT/agents" -maxdepth 1 -type f -name "*.md" -exec basename {} .md \; 2>/dev/null)
    while IFS= read -r archived; do
      [ -f "$archived" ] || continue
      name=$(basename "$archived" .md)
      [ -z "$name" ] || [ "$name" = "README" ] && continue
      echo "$active_names" | grep -qFx "$name" && continue
      hits=$(grep -rlE "(\`|\")/$name\b" \
        --include="*.md" \
        --exclude-dir="_archive" \
        --exclude-dir="health-snapshots" \
        --exclude="CHANGELOG.md" \
        "$ROOT" 2>/dev/null || true)
      if [ -n "$hits" ]; then
        count=$(echo "$hits" | wc -l | tr -d ' ')
        printf "[%s] %s 件 active 参照\n" "$name" "$count"
        while IFS= read -r hit_line; do
          echo "  - $hit_line"
        done <<< "$hits"
      fi
    done < <(find "$ROOT/_archive" -type f -name "*.md")
  fi
  echo '```'
  echo ""
  echo "## Staleness (guidelines/languages 90日超 mention)"
  echo ""
  echo '```'
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  TODAY_EPOCH=$(date +%s)
  for f in "$ROOT/guidelines/languages"/*.md; do
    [ -f "$f" ] || continue
    { grep -nE "20[0-9]{2}年[0-9]{1,2}月時点" "$f" 2>/dev/null || true; } | while IFS= read -r line; do
      YM=$(echo "$line" | grep -oE "20[0-9]{2}年[0-9]{1,2}月" | head -1)
      [ -z "$YM" ] && continue
      Y="${YM%年*}"
      M="${YM#*年}"
      M="${M%月}"
      MM=$(printf '%02d' "$M")
      # BSD (date -j) → GNU (date -d) の順で epoch 変換しクロスプラットフォーム対応
      MENT_EPOCH=$(date -j -f "%Y-%m-%d" "${Y}-${MM}-01" +%s 2>/dev/null \
        || date -d "${Y}-${MM}-01" +%s 2>/dev/null) || continue
      DAYS_OLD=$(( (TODAY_EPOCH - MENT_EPOCH) / 86400 ))
      if [ "$DAYS_OLD" -gt 90 ]; then
        printf "%s :: %s [%d 日経過]\n" "$(basename "$f")" "$line" "$DAYS_OLD"
      fi
    done
  done
  echo '```'
  echo ""
  echo "## 次アクション候補"
  echo ""
  echo "- 0 利用 commands/skills: **cross-ref grep 必須** (workflow / keyword 検知 / agents / hooks / bats 参照確認)。参照 0 のみ \`_archive/\` 退避、参照あれば設計通り出番待ち"
  echo "- median 100ms 超 hook: \`hook-bench.sh --hook NAME\` で詳細計測、内部処理を点検"
  echo "- death ref 検出: 参照を実態 (agent 直起動表記 / 廃止注記) に揃える、または archive 復活"
  echo "- 90 日超 mention: 該当言語/FW の release notes 確認 → guidelines 更新 + 「YYYY年MM月時点」差替"
  echo "- 結果を残したい場合: \`--out claude-code/references/health-snapshots/${TODAY}.md\` などへ"

  # === Memory audit (monthly equivalent) ===
  echo ""
  echo "## Memory Audit"
  echo ""
  echo '```'
  if [[ -x "${SCRIPT_DIR}/memory-audit.sh" ]]; then
    "${SCRIPT_DIR}/memory-audit.sh" 2>&1 | tail -10
  else
    echo "  memory-audit.sh not found, skipped"
  fi
  echo '```'
  echo ""
}

if [[ -n "$OUT_FILE" ]]; then
  out_dir=$(dirname "$OUT_FILE")
  [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
  render > "$OUT_FILE"
  echo "Wrote: $OUT_FILE" >&2
else
  render
fi
