#!/bin/bash
set -euo pipefail

# recommendations/extensions.json から拡張機能を一括インストール

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
EXT_JSON="${SCRIPT_DIR}/recommendations/extensions.json"

info() { printf '\033[36m[INFO]\033[0m %s\n' "$*"; }
ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }

pick_cli() {
  if command -v cursor >/dev/null 2>&1; then
    printf '%s\n' cursor
    return 0
  fi
  if command -v code >/dev/null 2>&1; then
    printf '%s\n' code
    return 0
  fi
  return 1
}

main() {
  if [[ ! -f "${EXT_JSON}" ]]; then
    warn "見つかりません: ${EXT_JSON}"
    exit 1
  fi

  local cli
  if ! cli="$(pick_cli)"; then
    warn "cursor / code CLI が見つかりません"
    exit 1
  fi

  info "CLI: ${cli}"
  info "拡張機能をインストールします"

  while IFS= read -r ext; do
    [[ -n "${ext}" ]] || continue
    info "install: ${ext}"
    if "${cli}" --install-extension "${ext}" --force; then
      ok "${ext}"
    else
      warn "失敗: ${ext}"
    fi
  done < <(python3 -c "
import json
with open('${EXT_JSON}') as f:
    for ext in json.load(f).get('recommendations', []):
        print(ext)
")

  ok "完了"
}

main "$@"
