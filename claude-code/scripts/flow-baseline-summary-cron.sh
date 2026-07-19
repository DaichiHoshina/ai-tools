#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
WARN_LOG="${LOG_DIR}/bundle-violation-warn.log"
OUT_DIR="$LOG_DIR"
TSV_SINCE_DAYS=30
WARN_SINCE_DAYS=7
DIFF_ENABLED=0

usage() {
  cat <<'EOF'
Usage: flow-baseline-summary-cron.sh [OPTIONS]

複数日の flow-baseline-*.tsv を dedup 集計し、bundle-violation-warn.log の
scope_declared_mismatch 件数とあわせて週次サマリを出力する。TSV 自体は生成
しない (生成元は hooks/stop.sh 経由の flow-baseline.sh)。

OPTIONS:
  --tsv-since <Nd>   flow-baseline TSV の集計期間 (ファイル名日付)  default: 30d
  --warn-since <Nd>  bundle-violation-warn.log の集計期間           default: 7d
  --diff             history TSV の直前行と比較表示
  --out-dir <path>   出力先ディレクトリ (default: ~/.claude/logs)
  --help             このヘルプを表示

OUTPUT:
  <out-dir>/flow-baseline-summary-YYYYMMDD.log   人間可読サマリ
  <out-dir>/flow-baseline-summary-history.tsv    機械可読 (--diff 用)

NOTES:
  - 集計元 (~/.claude/logs/flow-baseline-*.tsv, bundle-violation-warn.log) は
    --out-dir の影響を受けない (常に ~/.claude/logs を参照する)
  - 同一 invocation が日をまたいで複数 TSV に重複出力されるため、列1-8
    (date/session_id/topic/n_dev_agents/peak_concurrency/total_wall_sec/
    avg_task_sec/bundle_violations) をキーに dedup する
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tsv-since)
      [[ "${2:-}" =~ ^[0-9]+d$ ]] || { echo "ERROR: --tsv-since requires Nd format (e.g. 30d)" >&2; exit 2; }
      TSV_SINCE_DAYS="${2%d}"
      shift 2
      ;;
    --warn-since)
      [[ "${2:-}" =~ ^[0-9]+d$ ]] || { echo "ERROR: --warn-since requires Nd format (e.g. 7d)" >&2; exit 2; }
      WARN_SINCE_DAYS="${2%d}"
      shift 2
      ;;
    --diff) DIFF_ENABLED=1; shift ;;
    --out-dir)
      [[ -n "${2:-}" ]] || { echo "ERROR: --out-dir requires a path" >&2; exit 2; }
      OUT_DIR="$2"
      shift 2
      ;;
    --help|-h) usage ;;
    *) echo "ERROR: Unknown arg: $1" >&2; exit 2 ;;
  esac
done

_cutoff_date() {
  local days="$1"
  date -v-"${days}"d +%Y%m%d 2>/dev/null || date -d "${days} days ago" +%Y%m%d
}
_cutoff_ts() {
  local days="$1"
  date -v-"${days}"d '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -d "${days} days ago" '+%Y-%m-%dT%H:%M:%S'
}

TSV_CUTOFF="$(_cutoff_date "$TSV_SINCE_DAYS")"
WARN_CUTOFF="$(_cutoff_ts "$WARN_SINCE_DAYS")"

_collect_tsv_files() {
  local f base date_part
  shopt -s nullglob
  for f in "${LOG_DIR}"/flow-baseline-[0-9]*.tsv; do
    base="$(basename "$f")"
    date_part="${base#flow-baseline-}"
    date_part="${date_part%.tsv}"
    [[ "$date_part" =~ ^[0-9]{8}$ ]] || continue
    [[ "$date_part" -ge "$TSV_CUTOFF" ]] && echo "$f"
  done
  shopt -u nullglob
}

# 列1-8 をキーに dedup する。同一 invocation が日をまたいで複数 TSV に重複出力されるのを防ぐ。
_merged_dedup_rows() {
  awk -F'\t' '
    FNR == 1 { next }
    NF < 8 { next }
    {
      key = $1 FS $2 FS $3 FS $4 FS $5 FS $6 FS $7 FS $8
      if (key in seen) next
      seen[key] = 1
      print
    }
  ' "$@"
}

_kpi_stats() {
  local rows_file="$1"
  awk -F'\t' '
    $4 ~ /^[0-9]+$/ && $4 > 0 { ndev_sum += $4; nn++ }
    $5 ~ /^[0-9]+$/ && $5 > 0 { peak_sum += $5; pn++ }
    END {
      ndev_avg = (nn > 0) ? ndev_sum / nn : 0
      peak_avg = (pn > 0) ? peak_sum / pn : 0
      ratio = (nn > 0 && pn > 0 && ndev_avg > 0) ? peak_avg / ndev_avg : -1
      printf "%.4f\t%.4f\t%.4f\t%d\t%d\n", ndev_avg, peak_avg, ratio, nn, pn
    }
  ' "$rows_file"
}

_print_distributions() {
  local rows_file="$1"
  awk -F'\t' '
    $4 ~ /^[0-9]+$/ && $4 > 0 { ndev[++nn] = $4 + 0 }
    $5 ~ /^[0-9]+$/ && $5 > 0 { peak[++pn] = $5 + 0 }
    END {
      if (nn > 0) {
        for (i = 1; i <= nn; i++) for (j = i + 1; j <= nn; j++)
          if (ndev[i] > ndev[j]) { t = ndev[i]; ndev[i] = ndev[j]; ndev[j] = t }
        printf "n_dev_agents      median=%d  n=%d\n", ndev[int(nn / 2) + 1], nn
      } else {
        print "n_dev_agents      no data"
      }
      if (pn > 0) {
        for (i = 1; i <= pn; i++) for (j = i + 1; j <= pn; j++)
          if (peak[i] > peak[j]) { t = peak[i]; peak[i] = peak[j]; peak[j] = t }
        printf "peak_concurrency  median=%d  n=%d\n", peak[int(pn / 2) + 1], pn
      } else {
        print "peak_concurrency  no data"
      }
    }
  ' "$rows_file"
  echo ""
  echo "--- n_dev_agents distribution ---"
  awk -F'\t' '$4 ~ /^[0-9]+$/ && $4 > 0 { print $4 }' "$rows_file" | sort -n | uniq -c | \
    awk '{ printf "  n_dev=%-3s  count=%s\n", $2, $1 }'
  echo ""
  echo "--- peak_concurrency distribution ---"
  awk -F'\t' '$5 ~ /^[0-9]+$/ && $5 > 0 { print $5 }' "$rows_file" | sort -n | uniq -c | \
    awk '{ printf "  peak=%-3s  count=%s\n", $2, $1 }'
}

# macOS 標準 awk に mktime() が無いため、ISO8601 の文字列比較で cutoff 判定する。
_count_scope_mismatch() {
  local warn_log="$1" cutoff="$2"
  [[ -f "$warn_log" ]] || { echo 0; return 0; }
  awk -F' \\| ' -v cutoff="$cutoff" '
    /scope_declared_mismatch/ && $1 >= cutoff { count++ }
    END { print count + 0 }
  ' "$warn_log"
}

mkdir -p "$OUT_DIR"

TSV_FILES=()
while IFS= read -r _tsv_file; do
  TSV_FILES+=("$_tsv_file")
done < <(_collect_tsv_files)

TMP_ROWS="$(mktemp "${TMPDIR:-/tmp}/flow-baseline-summary-rows.XXXXXX")"
trap 'rm -f "$TMP_ROWS"' EXIT

if [[ "${#TSV_FILES[@]}" -gt 0 ]]; then
  _merged_dedup_rows "${TSV_FILES[@]}" > "$TMP_ROWS"
else
  : > "$TMP_ROWS"
fi

TOTAL_ROWS="$(wc -l < "$TMP_ROWS" | tr -d ' ')"

IFS=$'\t' read -r NDEV_AVG PEAK_AVG KPI_RATIO NDEV_N PEAK_N < <(_kpi_stats "$TMP_ROWS")

MISMATCH_COUNT="$(_count_scope_mismatch "$WARN_LOG" "$WARN_CUTOFF")"

SUMMARY_LOG="${OUT_DIR}/flow-baseline-summary-$(date +%Y%m%d).log"
HISTORY_TSV="${OUT_DIR}/flow-baseline-summary-history.tsv"

if [[ ! -f "$HISTORY_TSV" ]]; then
  echo -e "date\ttsv_files\ttsv_rows_dedup\tndev_avg\tpeak_avg\tkpi_ratio\tmismatch_count\twarn_since_days" > "$HISTORY_TSV"
fi

PREV_LINE=""
if [[ "$DIFF_ENABLED" -eq 1 ]]; then
  PREV_LINE="$(tail -n 1 "$HISTORY_TSV" 2>/dev/null || true)"
  [[ "$PREV_LINE" == date$'\t'* ]] && PREV_LINE=""
fi

TODAY="$(date +%Y-%m-%d)"

{
  echo "# flow-baseline-summary log: $SUMMARY_LOG"
  echo "# args: tsv-since=${TSV_SINCE_DAYS}d warn-since=${WARN_SINCE_DAYS}d diff=${DIFF_ENABLED} out-dir=${OUT_DIR}"
  echo "# date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "=== flow-baseline TSV 集計 (since ${TSV_SINCE_DAYS}d, dedup 後) ==="
  echo "files: ${#TSV_FILES[@]}  rows(dedup): ${TOTAL_ROWS}"
  echo ""
  _print_distributions "$TMP_ROWS"
  echo ""
  if [[ "$KPI_RATIO" == "-1.0000" ]]; then
    echo "KPI avg(peak)/avg(n_dev)  no data"
  else
    printf "KPI avg(peak)/avg(n_dev) = %.3f  (ndev_avg=%.2f n=%d, peak_avg=%.2f n=%d; 1.0 に近いほど並列化 gate が機能)\n" \
      "$KPI_RATIO" "$NDEV_AVG" "$NDEV_N" "$PEAK_AVG" "$PEAK_N"
  fi
  echo ""
  echo "=== bundle-violation scope_declared_mismatch (since ${WARN_SINCE_DAYS}d) ==="
  echo "count: ${MISMATCH_COUNT}"
  if [[ "$DIFF_ENABLED" -eq 1 ]]; then
    echo ""
    echo "=== --diff: 前回 history 行との比較 ==="
    if [[ -n "$PREV_LINE" ]]; then
      IFS=$'\t' read -r P_DATE _P_FILES _P_ROWS _P_NDEV _P_PEAK P_KPI P_MISMATCH _P_WARNDAYS <<<"$PREV_LINE"
      echo "prev: date=${P_DATE}  kpi_ratio=${P_KPI}  mismatch=${P_MISMATCH}"
      echo "curr: date=${TODAY}  kpi_ratio=${KPI_RATIO}  mismatch=${MISMATCH_COUNT}"
    else
      echo "prev history 行なし (今回が初回、baseline として記録)"
    fi
  fi
} | tee "$SUMMARY_LOG"

echo -e "${TODAY}\t${#TSV_FILES[@]}\t${TOTAL_ROWS}\t${NDEV_AVG}\t${PEAK_AVG}\t${KPI_RATIO}\t${MISMATCH_COUNT}\t${WARN_SINCE_DAYS}" >> "$HISTORY_TSV"
