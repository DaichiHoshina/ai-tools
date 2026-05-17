#!/usr/bin/env bash
# Claude Code 環境のヘルスチェック wrapper
# usage-stats (commands/skills 0 利用) + hook-bench (発火コスト) を統合実行、
# markdown 形式で結果を出力する。
#
# Usage:
#   ./scripts/health-check.sh                    # stdout に markdown
#   ./scripts/health-check.sh --out FILE         # ファイル出力
#   ./scripts/health-check.sh --bench-skip       # hook-bench を省略 (高速)
#   ./scripts/health-check.sh --days N           # usage-stats 期間 (default 90)
#
# 異常ハイライト基準:
#   - usage: 90日0利用 commands/skills
#   - bench: median 100ms 超 hook (累積影響大の累計コスト想定)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAYS=90
OUT_FILE=""
BENCH_SKIP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT_FILE="$2"; shift 2 ;;
    --bench-skip) BENCH_SKIP=1; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

TODAY=$(date +%Y-%m-%d)

render() {
  echo "# Claude Code Health Check ($TODAY)"
  echo ""
  echo "## Usage (過去 ${DAYS} 日 0 利用)"
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
  else
    echo "## Hook Bench (median 100ms 超は要点検)"
    echo ""
    echo '```'
    "$SCRIPT_DIR/hook-bench.sh"
    echo '```'
    echo ""
  fi
  echo "## Staleness (guidelines/languages 90日超 mention)"
  echo ""
  echo '```'
  ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  TODAY_EPOCH=$(date +%s)
  for f in "$ROOT/guidelines/languages"/*.md; do
    [ -f "$f" ] || continue
    grep -nE "20[0-9]{2}年[0-9]{1,2}月時点" "$f" 2>/dev/null | while IFS= read -r line; do
      YM=$(echo "$line" | grep -oE "20[0-9]{2}年[0-9]{1,2}月" | head -1)
      [ -z "$YM" ] && continue
      Y="${YM%年*}"
      M="${YM#*年}"
      M="${M%月}"
      MENT_EPOCH=$(date -j -f "%Y-%m-%d" "${Y}-$(printf '%02d' "$M")-01" +%s 2>/dev/null) || continue
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
  echo "- 0 利用 commands/skills: 設計通り出番待ちか確認、不要なら \`_archive/\` 退避"
  echo "- median 100ms 超 hook: \`hook-bench.sh --hook NAME\` で詳細計測、内部処理を点検"
  echo "- 90 日超 mention: 該当言語/FW の release notes 確認 → guidelines 更新 + 「YYYY年MM月時点」差替"
  echo "- 結果を残したい場合: \`--out claude-code/references/health-snapshots/${TODAY}.md\` などへ"
}

if [[ -n "$OUT_FILE" ]]; then
  out_dir=$(dirname "$OUT_FILE")
  [[ -d "$out_dir" ]] || mkdir -p "$out_dir"
  render > "$OUT_FILE"
  echo "Wrote: $OUT_FILE" >&2
else
  render
fi
