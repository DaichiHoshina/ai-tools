#!/usr/bin/env bash
# claude-cleanup.sh - ~/.claude/ 配下の肥大化を整理する
#
# 対象（保持期間はフラグで上書き可）:
#   projects/*/*.jsonl        : セッション履歴        (default 30日)
#   file-history/             : 編集前スナップショット  (default 14日)
#   logs/                     : hook ログ              (default 30日)
#   shell-snapshots/          : シェルスナップショット  (default 30日)
#   paste-cache/              : 貼付キャッシュ         (default 14日)
#   backups/                  : 自動バックアップ       (default 30日)
#
# デフォルトは dry-run。--execute で実削除。

set -euo pipefail

BASE_DIR="${CLAUDE_HOME:-${HOME}/.claude}"
EXECUTE=0
DAYS_PROJECTS=30
DAYS_FILE_HISTORY=14
DAYS_LOGS=30
DAYS_SHELL_SNAPSHOTS=30
DAYS_PASTE_CACHE=14
DAYS_BACKUPS=30

usage() {
  cat <<EOF
Usage: $(basename "$0") [--execute] [--days-projects N] [--days-file-history N] ...

Options:
  --execute              実削除（デフォルトは dry-run）
  --days-projects N      projects/ 保持日数 (default: 30)
  --days-file-history N  file-history/ 保持日数 (default: 14)
  --days-logs N          logs/ 保持日数 (default: 30)
  --days-shell-snapshots N
  --days-paste-cache N
  --days-backups N
  -h, --help             このヘルプを表示

Environment:
  CLAUDE_HOME            整理対象ディレクトリ (default: \${HOME}/.claude)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) EXECUTE=1 ;;
    --days-projects) DAYS_PROJECTS="$2"; shift ;;
    --days-file-history) DAYS_FILE_HISTORY="$2"; shift ;;
    --days-logs) DAYS_LOGS="$2"; shift ;;
    --days-shell-snapshots) DAYS_SHELL_SNAPSHOTS="$2"; shift ;;
    --days-paste-cache) DAYS_PASTE_CACHE="$2"; shift ;;
    --days-backups) DAYS_BACKUPS="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [[ ! -d "${BASE_DIR}" ]]; then
  echo "Error: ${BASE_DIR} が存在しない" >&2
  exit 1
fi

# bytes (macOS/BSD の du は -b なし。KB単位で集計して後で表示用に変換)
total_freed_kb=0
total_count=0

human_size() {
  local kb="$1"
  if [[ "${kb}" -ge 1048576 ]]; then
    awk -v k="${kb}" 'BEGIN{printf "%.1fG", k/1048576}'
  elif [[ "${kb}" -ge 1024 ]]; then
    awk -v k="${kb}" 'BEGIN{printf "%.1fM", k/1024}'
  else
    echo "${kb}K"
  fi
}

cleanup_target() {
  local label="$1"
  local dir="$2"
  local days="$3"
  local find_args=("${@:4}")

  if [[ ! -d "${dir}" ]]; then
    printf "  %-20s : (skip, not found)\n" "${label}"
    return
  fi

  # 対象ファイル列挙
  local tmp
  tmp=$(mktemp)
  find "${dir}" "${find_args[@]}" -mtime +"${days}" -print0 2>/dev/null > "${tmp}" || true

  local count size_kb
  count=$(tr -cd '\0' < "${tmp}" | wc -c | tr -d ' ')

  if [[ "${count}" -eq 0 ]]; then
    printf "  %-20s : 0 件\n" "${label}"
    rm -f "${tmp}"
    return
  fi

  # size 集計（xargs で du 一括）
  size_kb=$(xargs -0 -I{} du -sk "{}" < "${tmp}" 2>/dev/null | awk '{sum+=$1} END{print sum+0}')

  total_freed_kb=$((total_freed_kb + size_kb))
  total_count=$((total_count + count))

  printf "  %-20s : %5d 件 / %s\n" "${label}" "${count}" "$(human_size "${size_kb}")"

  if [[ "${EXECUTE}" -eq 1 ]]; then
    xargs -0 rm -rf < "${tmp}"
  fi

  rm -f "${tmp}"
}

mode_label="DRY-RUN"
[[ "${EXECUTE}" -eq 1 ]] && mode_label="EXECUTE"

echo "=== claude-cleanup [${mode_label}] base=${BASE_DIR} ==="
echo

cleanup_target "projects jsonl"  "${BASE_DIR}/projects"         "${DAYS_PROJECTS}"        -type f -name "*.jsonl"
cleanup_target "file-history"    "${BASE_DIR}/file-history"     "${DAYS_FILE_HISTORY}"    -type f
cleanup_target "logs"            "${BASE_DIR}/logs"             "${DAYS_LOGS}"            -type f
cleanup_target "shell-snapshots" "${BASE_DIR}/shell-snapshots"  "${DAYS_SHELL_SNAPSHOTS}" -type f
cleanup_target "paste-cache"     "${BASE_DIR}/paste-cache"      "${DAYS_PASTE_CACHE}"     -type f
cleanup_target "backups"         "${BASE_DIR}/backups"          "${DAYS_BACKUPS}"         -type f

echo
printf "合計: %d 件 / %s\n" "${total_count}" "$(human_size "${total_freed_kb}")"

if [[ "${EXECUTE}" -ne 1 ]]; then
  echo
  echo "※ dry-run。実削除は --execute を付けて再実行。"
fi
