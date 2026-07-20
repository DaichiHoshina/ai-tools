#!/usr/bin/env bash
# 週次 Verification 自動計測 (maintenance-cron-run.sh から呼ばれる)
# verification-metrics.tsv の各 metric を実行し、pending-improvements.md 末尾へ数値 block を追記する
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METRICS_TSV="${VERIFICATION_METRICS_TSV:-${REPO_ROOT}/scripts/verification-metrics.tsv}"
TARGET_MD="${VERIFICATION_TARGET_MD:-${HOME}/ai-tools/memory/pending-improvements.md}"
export CUTOFF="${VERIFICATION_CUTOFF:-$(date -v-7d +%Y-%m-%d)}"

if [[ ! -f "$METRICS_TSV" ]]; then
  echo "ERROR: metrics TSV が見つからない: $METRICS_TSV" >&2
  exit 2
fi
if [[ ! -f "$TARGET_MD" ]]; then
  echo "ERROR: 追記先 md が見つからない: $TARGET_MD" >&2
  exit 2
fi

block="### 自動計測 $(date +%Y-%m-%d) (window: ${CUTOFF} 以降)"$'\n'
while IFS=$'\t' read -r id desc cmd; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  value="$(bash -c "$cmd" 2>/dev/null)"
  [[ -z "$value" ]] && value="ERR"
  block+="- ${id}: ${value} (${desc})"$'\n'
done < "$METRICS_TSV"

printf '\n%s' "$block" >> "$TARGET_MD"
echo "appended: $TARGET_MD"
