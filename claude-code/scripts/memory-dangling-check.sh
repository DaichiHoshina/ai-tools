#!/usr/bin/env bash
# memory-dangling-check.sh — MEMORY.md の dangling entry / orphan file を検出する (warn-only)
#
# Usage:
#   ./memory-dangling-check.sh [--dir <memory-dir>]
#
# 検出対象:
#   dangling — MEMORY.md にリストされているが実 file が存在しない
#   orphan   — file は存在するが MEMORY.md にリストされていない
#
# 注意: 削除・編集は一切しない。検出のみ。exit 0 固定 (warn-only)。
# Finding は stderr に出力する。
set -euo pipefail

# --- デフォルト対象 dir ---
# Claude Code の project dir 命名規則: パス区切り "/" → "-"、"." → "-" に変換する
_user_slug=$(whoami | tr '.' '-')
DEFAULT_MEM_DIR="${HOME}/.claude/projects/-Users-${_user_slug}-ai-tools/memory"

# --- 引数パース ---
MEM_DIR="${DEFAULT_MEM_DIR}"

usage() {
  cat <<'EOF'
Usage: memory-dangling-check.sh [--dir <memory-dir>]

Options:
  --dir <path>   memory dir を指定 (default: ~/.claude/projects/-Users-<user>-ai-tools/memory)
  --help         usage 表示
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) MEM_DIR="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 0 ;;
  esac
done

MEMORY_MD="${MEM_DIR}/MEMORY.md"

# dir / MEMORY.md が存在しない場合はスキップ (warn-only)
if [[ ! -d "${MEM_DIR}" ]]; then
  echo "[memory-dangling-check] SKIP: dir not found: ${MEM_DIR}" >&2
  exit 0
fi
if [[ ! -f "${MEMORY_MD}" ]]; then
  echo "[memory-dangling-check] SKIP: MEMORY.md not found: ${MEMORY_MD}" >&2
  exit 0
fi

# --- MEMORY.md から listed file 名を抽出 ---
# 対応形式: - [Title](file.md) — hook
extract_listed_files() {
  grep -oE '\([^)]+\.md\)' -- "${MEMORY_MD}" 2>/dev/null \
    | sed 's/[()]//g' \
    | grep -v '^MEMORY\.md$' \
    || true
}

# --- listed files を配列に収集 ---
listed_files=()
while IFS= read -r f; do
  [[ -n "${f}" ]] && listed_files+=("${f}")
done < <(extract_listed_files)

# --- dangling 検出 (listed だが file なし) ---
dangling=()
for f in "${listed_files[@]+"${listed_files[@]}"}"; do
  if [[ ! -f "${MEM_DIR}/${f}" ]]; then
    dangling+=("${f}")
  fi
done

# --- orphan 検出 (file あるが listed なし) ---
orphan=()
while IFS= read -r -d '' mf; do
  fname=$(basename -- "${mf}")
  [[ "${fname}" == "MEMORY.md" ]] && continue
  found=0
  for lf in "${listed_files[@]+"${listed_files[@]}"}"; do
    if [[ "${lf}" == "${fname}" ]]; then
      found=1
      break
    fi
  done
  if [[ "${found}" -eq 0 ]]; then
    orphan+=("${fname}")
  fi
done < <(find -- "${MEM_DIR}" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null)

# --- finding がなければ正常終了 ---
if [[ ${#dangling[@]} -eq 0 && ${#orphan[@]} -eq 0 ]]; then
  exit 0
fi

# --- finding を stderr に出力 (warn-only) ---
{
  echo "[memory-dangling-check] WARNING: memory integrity issues detected"
  echo "  dir: ${MEM_DIR}"
  if [[ ${#dangling[@]} -gt 0 ]]; then
    echo "  dangling entries (in MEMORY.md but file missing):"
    for f in "${dangling[@]}"; do
      echo "    - ${f}"
    done
  fi
  if [[ ${#orphan[@]} -gt 0 ]]; then
    echo "  orphan files (file exists but not in MEMORY.md):"
    for f in "${orphan[@]}"; do
      echo "    - ${f}"
    done
  fi
  echo "  -> fix: update MEMORY.md index or move/delete the offending file"
} >&2

exit 0
