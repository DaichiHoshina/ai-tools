#!/bin/bash
set -euo pipefail

# Cursor 設定インストーラ
# ai-tools/cursor/User/ を ~/Library/Application Support/Cursor/User/ にリンク

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="${SCRIPT_DIR}/User"
CURSOR_USER_DIR="${HOME}/Library/Application Support/Cursor/User"

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }

link_file() {
  local name="$1"
  local src="${SRC_DIR}/${name}"
  local dst="${CURSOR_USER_DIR}/${name}"

  if [[ ! -f "${src}" ]]; then
    warn "スキップ: ${src} が存在しません"
    return 0
  fi

  mkdir -p "${CURSOR_USER_DIR}"

  if [[ -L "${dst}" ]]; then
    local current
    current="$(readlink "${dst}")"
    if [[ "${current}" == "${src}" ]]; then
      ok "既にリンク済み: ${name}"
      return 0
    fi
    rm -f "${dst}"
  elif [[ -e "${dst}" ]]; then
    local backup="${dst}.backup.$(date +%Y%m%d%H%M%S)"
    warn "${name} をバックアップ: ${backup}"
    mv "${dst}" "${backup}"
  fi

  ln -sf "${src}" "${dst}"
  ok "リンク作成: ${name}"
}

main() {
  info "Cursor 設定をインストールします"
  info "ソース: ${SRC_DIR}"
  info "リンク先: ${CURSOR_USER_DIR}"

  link_file "settings.json"
  link_file "keybindings.json"

  ok "完了。Cursor を再起動するか Reload Window してください。"
}

main "$@"
