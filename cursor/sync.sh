#!/bin/bash
set -euo pipefail

# Cursor 設定同期
#   ./sync.sh to-local    リポジトリ → Cursor User ディレクトリ
#   ./sync.sh from-local  Cursor User ディレクトリ → リポジトリ
#   ./sync.sh diff        差分表示

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="${SCRIPT_DIR}/User"
CURSOR_USER_DIR="${HOME}/Library/Application Support/Cursor/User"
SYNC_FILES=(settings.json keybindings.json)

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <to-local|from-local|diff>

  to-local     ai-tools/cursor/User/ → ~/Library/Application Support/Cursor/User/
  from-local   ~/Library/Application Support/Cursor/User/ → ai-tools/cursor/User/
  diff         両者の差分を表示
EOF
}

resolve_local_path() {
  local name="$1"
  local dst="${CURSOR_USER_DIR}/${name}"

  if [[ -L "${dst}" ]]; then
    readlink "${dst}"
    return 0
  fi

  if [[ -f "${dst}" ]]; then
    printf '%s\n' "${dst}"
    return 0
  fi

  return 1
}

to_local() {
  mkdir -p "${CURSOR_USER_DIR}"
  for name in "${SYNC_FILES[@]}"; do
    local src="${SRC_DIR}/${name}"
    local dst="${CURSOR_USER_DIR}/${name}"
    if [[ ! -f "${src}" ]]; then
      warn "スキップ: ${src} がありません"
      continue
    fi
    cp "${src}" "${dst}"
    ok "反映: ${name}"
  done
}

from_local() {
  mkdir -p "${SRC_DIR}"
  for name in "${SYNC_FILES[@]}"; do
    local dst="${CURSOR_USER_DIR}/${name}"
    local src="${SRC_DIR}/${name}"
    if [[ ! -f "${dst}" ]]; then
      warn "スキップ: ${dst} がありません"
      continue
    fi
    cp "${dst}" "${src}"
    ok "保存: ${name}"
  done
}

show_diff() {
  for name in "${SYNC_FILES[@]}"; do
    local repo_file="${SRC_DIR}/${name}"
    local local_file
    if ! local_file="$(resolve_local_path "${name}")"; then
      warn "${name}: ローカルファイルなし"
      continue
    fi
    info "=== ${name} ==="
    diff -u "${repo_file}" "${local_file}" || true
  done
}

main() {
  case "${1:-}" in
    to-local) to_local ;;
    from-local) from_local ;;
    diff) show_diff ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
