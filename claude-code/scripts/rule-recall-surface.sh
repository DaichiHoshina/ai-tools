#!/usr/bin/env bash
# 週次 rule recall surface (maintenance-cron-run.sh から呼ばれる)
# rule-recall-patterns.tsv の各 pattern の 7 日 hit 数を数え、閾値超のみ pending-improvements.md 末尾へ追記する
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATTERNS_TSV="${RECALL_PATTERNS_TSV:-${REPO_ROOT}/scripts/rule-recall-patterns.tsv}"
TARGET_MD="${RECALL_TARGET_MD:-${HOME}/ai-tools/memory/pending-improvements.md}"
LOG_FILE="${RECALL_LOG:-${HOME}/.claude/logs/jp-quality-block.log}"
CUTOFF="${RECALL_CUTOFF:-$(date -v-7d +%Y-%m-%d)}"

if [[ ! -f "$PATTERNS_TSV" ]]; then
  echo "ERROR: patterns TSV が見つからない: $PATTERNS_TSV" >&2
  exit 2
fi
if [[ ! -f "$TARGET_MD" ]]; then
  echo "ERROR: 追記先 md が見つからない: $TARGET_MD" >&2
  exit 2
fi

block="### 昇格候補 $(date +%Y-%m-%d) (window: ${CUTOFF} 以降、閾値超のみ)"$'\n'

if [[ ! -f "$LOG_FILE" ]]; then
  block+="- N/A (log 不在: ${LOG_FILE})"$'\n'
  printf '\n%s' "$block" >> "$TARGET_MD"
  echo "appended: $TARGET_MD"
  exit 0
fi

hit_count=0
while IFS=$'\t' read -r id pattern rule threshold; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  count="$(awk -F' [|] ' -v c="$CUTOFF" '$1 >= c { print $3 }' "$LOG_FILE" | grep -c -- "$pattern")"
  count="${count:-0}"
  if (( count > threshold )); then
    block+="- ${id}: ${count} 件 (${pattern} → ${rule}、閾値 ${threshold})"$'\n'
    hit_count=$((hit_count + 1))
  fi
done < "$PATTERNS_TSV"

if (( hit_count == 0 )); then
  block+="- 該当なし (全 pattern 閾値未満)"$'\n'
fi

printf '\n%s' "$block" >> "$TARGET_MD"
echo "appended: $TARGET_MD"
