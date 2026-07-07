#!/bin/bash
set -euo pipefail

# Cursor 設定インストーラ
# - User/ → ~/Library/Application Support/Cursor/User/
# - rules/ → ~/.cursor/rules/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
AI_TOOLS_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
SRC_USER="${SCRIPT_DIR}/User"
SRC_RULES="${SCRIPT_DIR}/rules"
CURSOR_USER_DIR="${HOME}/Library/Application Support/Cursor/User"
CURSOR_RULES_DIR="${HOME}/.cursor/rules"
SHARED_MEMORY_SRC="${AI_TOOLS_ROOT}/memory"
CURSOR_MEMORY_LINK="${HOME}/.cursor/memory"

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }

link_file() {
  local name="$1"
  local src="$2"
  local dst="$3"

  if [[ ! -f "${src}" ]]; then
    warn "スキップ: ${src} が存在しません"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"

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

install_rules() {
  if [[ ! -d "${SRC_RULES}" ]]; then
    warn "rules/ がありません"
    return 0
  fi

  mkdir -p "${CURSOR_RULES_DIR}"
  local rule
  for rule in "${SRC_RULES}"/*.mdc; do
    [[ -f "${rule}" ]] || continue
    local base
    base="$(basename "${rule}")"
    link_file "rules/${base}" "${rule}" "${CURSOR_RULES_DIR}/${base}"
  done
}

install_shared_memory() {
  # グローバル共有 memory (~/ai-tools/memory) を ~/.cursor/memory へ symlink する。
  # 全プロジェクトで同じ memory を読めるようにするため。
  if [[ ! -d "${SHARED_MEMORY_SRC}" ]]; then
    warn "共有 memory がありません: ${SHARED_MEMORY_SRC}"
    return 0
  fi

  if [[ -L "${CURSOR_MEMORY_LINK}" ]]; then
    local current
    current="$(readlink "${CURSOR_MEMORY_LINK}")"
    if [[ "${current}" == "${SHARED_MEMORY_SRC}" ]]; then
      ok "既にリンク済み: memory"
      return 0
    fi
    rm -f "${CURSOR_MEMORY_LINK}"
  elif [[ -e "${CURSOR_MEMORY_LINK}" ]]; then
    local backup="${CURSOR_MEMORY_LINK}.backup.$(date +%Y%m%d%H%M%S)"
    warn "memory をバックアップ: ${backup}"
    mv "${CURSOR_MEMORY_LINK}" "${backup}"
  fi

  ln -sf "${SHARED_MEMORY_SRC}" "${CURSOR_MEMORY_LINK}"
  ok "リンク作成: memory (~/.cursor/memory -> ${SHARED_MEMORY_SRC})"
}

main() {
  info "Cursor 設定をインストールします"
  info "User ソース: ${SRC_USER}"
  info "User リンク先: ${CURSOR_USER_DIR}"
  info "Rules リンク先: ${CURSOR_RULES_DIR}"

  link_file "settings.json" "${SRC_USER}/settings.json" "${CURSOR_USER_DIR}/settings.json"
  link_file "keybindings.json" "${SRC_USER}/keybindings.json" "${CURSOR_USER_DIR}/keybindings.json"
  install_rules
  install_shared_memory

  ok "完了。Cursor を再起動するか Reload Window してください。"
  info "拡張機能: ./install-extensions.sh（任意）"
}

main "$@"
