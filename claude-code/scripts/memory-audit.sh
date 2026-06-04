#!/usr/bin/env bash
# memory-audit.sh — ~/.claude/projects/*/memory/ の整合性を検査する read-only script
#
# Usage:
#   ./memory-audit.sh                      # 全 project 走査
#   ./memory-audit.sh --project <substr>   # project dir 名でフィルタ
#   ./memory-audit.sh --verbose            # log 内容を stdout にも出力
#   ./memory-audit.sh --help               # usage 表示
#
# 検出対象 (5 種類):
#   1. duplicate   — 同一 hash の file が複数 dir に存在
#   2. divergence  — 同名 file で異なる hash (内容分岐)
#   3. dangling    — MEMORY.md に listed されているが file 不在
#   4. orphan      — file 存在するが MEMORY.md 未登録
#   5. stale       — mtime 90 日超
#
# 注意: 削除・移動・編集は一切しない。検出と report のみ。
set -euo pipefail

# --- 定数 ---
STALE_DAYS=90
MEMORY_DIR="${HOME}/.claude/projects"
LOG_DIR="${HOME}/.claude/logs"
TODAY=$(date +%Y-%m-%d)
LOG_FILE="${LOG_DIR}/memory-audit-${TODAY}.log"

# --- 引数パース ---
PROJECT_FILTER=""
VERBOSE=0

usage() {
  cat <<'EOF'
Usage: memory-audit.sh [OPTIONS]

Options:
  --project <substr>   filter by project directory name substring
  --verbose            print log content to stdout in addition to log file
  --help               show this usage
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_FILTER="$2"; shift 2 ;;
    --verbose) VERBOSE=1; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- log dir 確保 ---
mkdir -p -- "${LOG_DIR}"

# --- 除外 dir パターン判定 ---
# 戻り値: 0=除外, 1=対象
is_excluded_dir() {
  local dir="$1"
  local base
  base=$(basename -- "${dir}")
  case "${base}" in
    tmp-wt-*|private-tmp-wt-*|_memory_archive_*) return 0 ;;
  esac
  # 数字 suffix worktree (例: <repo>-12345)
  if echo "${base}" | grep -qE '\-[0-9]+$'; then
    return 0
  fi
  return 1
}

# --- hash 取得 (macOS md5 / Linux md5sum 両対応) ---
file_hash() {
  local f="$1"
  if command -v md5sum > /dev/null 2>&1; then
    md5sum -- "${f}" | awk '{print $1}'
  else
    md5 -q -- "${f}"
  fi
}

# --- mtime YYYY-MM-DD 取得 (macOS stat) ---
file_mtime() {
  local f="$1"
  stat -f '%Sm' -t '%Y-%m-%d' -- "${f}" 2>/dev/null || echo "unknown"
}

# --- age (days) 計算 ---
file_age_days() {
  local f="$1"
  local mtime_epoch
  mtime_epoch=$(stat -f '%m' -- "${f}" 2>/dev/null) || echo 0
  local now_epoch
  now_epoch=$(date +%s)
  echo $(( (now_epoch - mtime_epoch) / 86400 ))
}

# --- project dir 列挙 ---
collect_project_dirs() {
  local result=()
  while IFS= read -r -d '' d; do
    local mem_dir="${d}/memory"
    [ -d "${mem_dir}" ] || continue
    if is_excluded_dir "${d}"; then
      continue
    fi
    if [[ -n "${PROJECT_FILTER}" ]]; then
      base=$(basename -- "${d}")
      if [[ "${base}" != *"${PROJECT_FILTER}"* ]]; then
        continue
      fi
    fi
    result+=("${d}")
  done < <(find -- "${MEMORY_DIR}" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)
  printf '%s\n' "${result[@]+"${result[@]}"}"
}

# --- MEMORY.md から listed file 名を抽出 ---
# リンク形式: [Title](file.md) → file.md
extract_listed_files() {
  local memory_md="$1"
  [ -f "${memory_md}" ] || return 0
  grep -oE '\([^)]+\.md\)' -- "${memory_md}" 2>/dev/null \
    | sed 's/[()]//g' \
    | grep -v '^MEMORY\.md$' \
    || true
}

# ==========================================================
# メイン解析
# ==========================================================

# 一時 dir (bash 3.2 対応のため associative array を使わず tmp files で代替)
TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '${TMP_DIR}'" EXIT

HASH_MAP="${TMP_DIR}/hash_map.txt"   # <hash>\t<project_short>\t<filename>
NAME_MAP="${TMP_DIR}/name_map.txt"   # <filename>\t<hash>\t<project_short>\t<mtime>
touch -- "${HASH_MAP}" "${NAME_MAP}"

CNT_PROJ=0
CNT_DUP=0
CNT_DIV=0
CNT_DAN=0
CNT_ORP=0
CNT_STA=0

REPORT_DUP="${TMP_DIR}/dup.txt"
REPORT_DIV="${TMP_DIR}/div.txt"
REPORT_DAN="${TMP_DIR}/dan.txt"
REPORT_ORP="${TMP_DIR}/orp.txt"
REPORT_STA="${TMP_DIR}/sta.txt"
touch -- "${REPORT_DUP}" "${REPORT_DIV}" "${REPORT_DAN}" "${REPORT_ORP}" "${REPORT_STA}"

while IFS= read -r proj_dir; do
  [ -z "${proj_dir}" ] && continue
  CNT_PROJ=$(( CNT_PROJ + 1 ))
  proj_short=$(basename -- "${proj_dir}")
  mem_dir="${proj_dir}/memory"

  # --- memory files 走査 ---
  while IFS= read -r -d '' mf; do
    fname=$(basename -- "${mf}")
    [ "${fname}" = "MEMORY.md" ] && continue
    h=$(file_hash "${mf}")
    mtime=$(file_mtime "${mf}")
    printf '%s\t%s\t%s\n' "${h}" "${proj_short}" "${fname}" >> "${HASH_MAP}"
    printf '%s\t%s\t%s\t%s\n' "${fname}" "${h}" "${proj_short}" "${mtime}" >> "${NAME_MAP}"
  done < <(find -- "${mem_dir}" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null)

  # --- 3. dangling (listed but missing) ---
  memory_md="${mem_dir}/MEMORY.md"
  while IFS= read -r listed; do
    [ -z "${listed}" ] && continue
    if [ ! -f "${mem_dir}/${listed}" ]; then
      printf '  %s:\n    - %s\n' "${proj_short}" "${listed}" >> "${REPORT_DAN}"
      CNT_DAN=$(( CNT_DAN + 1 ))
    fi
  done < <(extract_listed_files "${memory_md}")

  # --- 4. orphan (exists but not listed) ---
  declare -a listed_arr=()
  while IFS= read -r listed; do
    [ -n "${listed}" ] && listed_arr+=("${listed}")
  done < <(extract_listed_files "${memory_md}")

  while IFS= read -r -d '' mf; do
    fname=$(basename -- "${mf}")
    [ "${fname}" = "MEMORY.md" ] && continue
    found=0
    for lf in "${listed_arr[@]+"${listed_arr[@]}"}"; do
      if [ "${lf}" = "${fname}" ]; then
        found=1
        break
      fi
    done
    if [ "${found}" -eq 0 ]; then
      mtime=$(file_mtime "${mf}")
      printf '  %s:\n    - %s (%s)\n' "${proj_short}" "${fname}" "${mtime}" >> "${REPORT_ORP}"
      CNT_ORP=$(( CNT_ORP + 1 ))
    fi
  done < <(find -- "${mem_dir}" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null)
  unset listed_arr

  # --- 5. stale ---
  while IFS= read -r -d '' mf; do
    fname=$(basename -- "${mf}")
    [ "${fname}" = "MEMORY.md" ] && continue
    age=$(file_age_days "${mf}")
    if [ "${age}" -gt "${STALE_DAYS}" ]; then
      mtime=$(file_mtime "${mf}")
      printf '  %s:\n    - %s (%s, %d days)\n' "${proj_short}" "${fname}" "${mtime}" "${age}" >> "${REPORT_STA}"
      CNT_STA=$(( CNT_STA + 1 ))
    fi
  done < <(find -- "${mem_dir}" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null)

done < <(collect_project_dirs)

# --- 1. duplicate (同一 hash, 複数 dir) ---
# hash_map: <hash>\t<proj>\t<fname> をソートして同一 hash の出現数を確認
sort -- "${HASH_MAP}" > "${TMP_DIR}/hash_sorted.txt"
while IFS= read -r hash; do
  [ -z "${hash}" ] && continue
  count=$(grep -c "^${hash}	" -- "${TMP_DIR}/hash_sorted.txt" || true)
  if [ "${count}" -ge 2 ]; then
    # 同一 hash が異なる proj に存在するか確認
    proj_count=$(grep "^${hash}	" -- "${TMP_DIR}/hash_sorted.txt" | awk -F'\t' '{print $2}' | sort -u | wc -l | tr -d ' ')
    if [ "${proj_count}" -ge 2 ]; then
      fname=$(grep "^${hash}	" -- "${TMP_DIR}/hash_sorted.txt" | head -1 | awk -F'\t' '{print $3}')
      printf '  hash=%s  %s\n' "${hash:0:8}" "${fname}" >> "${REPORT_DUP}"
      grep "^${hash}	" -- "${TMP_DIR}/hash_sorted.txt" | awk -F'\t' '{print $2}' | sort -u | while IFS= read -r p; do
        printf '    - %s\n' "${p}" >> "${REPORT_DUP}"
      done
      CNT_DUP=$(( CNT_DUP + 1 ))
    fi
  fi
done < <(awk -F'\t' '{print $1}' "${TMP_DIR}/hash_sorted.txt" | sort -u)

# --- 2. divergence (同名, 異なる hash) ---
sort -- "${NAME_MAP}" > "${TMP_DIR}/name_sorted.txt"
while IFS= read -r fname; do
  [ -z "${fname}" ] && continue
  hash_count=$(grep "^${fname}	" -- "${TMP_DIR}/name_sorted.txt" | awk -F'\t' '{print $2}' | sort -u | wc -l | tr -d ' ')
  if [ "${hash_count}" -ge 2 ]; then
    version_count=$(grep -c "^${fname}	" -- "${TMP_DIR}/name_sorted.txt" || true)
    printf '  %s (%s versions)\n' "${fname}" "${version_count}" >> "${REPORT_DIV}"
    grep "^${fname}	" -- "${TMP_DIR}/name_sorted.txt" | while IFS=$'\t' read -r _fn h p mt; do
      printf '    - %s (hash=%s, %s)\n' "${p}" "${h:0:8}" "${mt}" >> "${REPORT_DIV}"
    done
    CNT_DIV=$(( CNT_DIV + 1 ))
  fi
done < <(awk -F'\t' '{print $1}' "${TMP_DIR}/name_sorted.txt" | sort -u)

# ==========================================================
# Report 生成
# ==========================================================
generate_report() {
  echo "Memory Audit Report — ${TODAY}"
  echo "================================="
  echo ""
  echo "[1] Duplicate files (same hash, multiple dirs):"
  if [ -s "${REPORT_DUP}" ]; then
    cat -- "${REPORT_DUP}"
  else
    echo "  (none)"
  fi
  echo ""
  echo "[2] Divergence (same name, different content):"
  if [ -s "${REPORT_DIV}" ]; then
    cat -- "${REPORT_DIV}"
  else
    echo "  (none)"
  fi
  echo ""
  echo "[3] Dangling entries (listed but file missing):"
  if [ -s "${REPORT_DAN}" ]; then
    cat -- "${REPORT_DAN}"
  else
    echo "  (none)"
  fi
  echo ""
  echo "[4] Orphan files (exists but not listed):"
  if [ -s "${REPORT_ORP}" ]; then
    cat -- "${REPORT_ORP}"
  else
    echo "  (none)"
  fi
  echo ""
  echo "[5] Stale files (>${STALE_DAYS} days):"
  if [ -s "${REPORT_STA}" ]; then
    cat -- "${REPORT_STA}"
  else
    echo "  (none)"
  fi
  echo ""
  echo "=== Summary ==="
  printf 'projects scanned:       %d\n' "${CNT_PROJ}"
  printf 'duplicates:             %d\n' "${CNT_DUP}"
  printf 'divergences:            %d\n' "${CNT_DIV}"
  printf 'dangling entries:       %d\n' "${CNT_DAN}"
  printf 'orphan files:           %d\n' "${CNT_ORP}"
  printf 'stale files:            %d\n' "${CNT_STA}"
  echo ""
  echo "Action required: manual review at ~/.claude/projects/<dir>/memory/"
  printf 'Detailed log:    %s\n' "${LOG_FILE}"
}

FULL_REPORT=$(generate_report)

# stdout に summary (常時)
echo "${FULL_REPORT}"

# log file に詳細書き込み
echo "${FULL_REPORT}" > "${LOG_FILE}"

if [[ "${VERBOSE}" -eq 1 ]]; then
  echo ""
  echo "--- verbose: log written to ${LOG_FILE} ---"
fi

exit 0
