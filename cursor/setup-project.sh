#!/bin/bash
set -euo pipefail

# 新規 / 既存プロジェクトに Cursor 用テンプレートを配置
# Usage: ./setup-project.sh /path/to/project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates/project"

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <project-dir>

  templates/project/ の内容をプロジェクトへコピーする:
    .vscode/extensions.json
EOF
}

copy_tree() {
  local src="$1"
  local dst_root="$2"
  local rel="${src#"${TEMPLATE_DIR}/"}"
  local dst="${dst_root}/${rel}"

  if [[ -f "${src}" ]]; then
    if [[ -f "${dst}" ]]; then
      warn "スキップ (既存): ${rel}"
      return 0
    fi
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
    ok "追加: ${rel}"
    return 0
  fi

  if [[ -d "${src}" ]]; then
    mkdir -p "${dst}"
    local child
    for child in "${src}"/*; do
      [[ -e "${child}" ]] || continue
      copy_tree "${child}" "${dst_root}"
    done
  fi
}

main() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    usage
    exit 1
  fi

  if [[ ! -d "${target}" ]]; then
    warn "ディレクトリがありません: ${target}"
    exit 1
  fi

  target="$(cd "${target}" && pwd -P)"
  info "プロジェクト: ${target}"

  if [[ ! -d "${TEMPLATE_DIR}" ]]; then
    warn "テンプレートがありません: ${TEMPLATE_DIR}"
    exit 1
  fi

  copy_tree "${TEMPLATE_DIR}" "${target}"
  ok "完了"
}

main "$@"
