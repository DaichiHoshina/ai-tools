#!/bin/bash
# =============================================================================
# Hook共通ユーティリティ (facade)
# =============================================================================
# 多重 source 防止
if [[ "${_HOOK_UTILS_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_LOADED=1

set -euo pipefail

# shellcheck source=../hooks/lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/thresholds.sh"
# shellcheck source=../hooks/lib/portable-stat.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/portable-stat.sh"
# shellcheck source=../hooks/lib/log-rotation.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/log-rotation.sh"

# -----------------------------------------------------------------------------
# 共通アイコン (Nerd Fonts / Unicode)
# 各hookでの重複定義と表記ブレ（ICON_WARN vs ICON_WARNING、✓ vs ✓）を解消。
# hook-utils.sh を source した hook はこの変数をそのまま参照できる。
# -----------------------------------------------------------------------------
: "${ICON_SUCCESS:=$'✓'}"    # check-circle
: "${ICON_WARNING:=$'▲'}"    # exclamation-triangle
: "${ICON_ERROR:=$'✗'}"      # x-mark
: "${ICON_FORBIDDEN:=$'⊗'}"  # ban
: "${ICON_CRITICAL:=$'◉'}"   # filled circle (critical event)
: "${ICON_IDLE:=$'☾'}"       # moon (idle/sleep)
# 後方互換: ICON_WARN は ICON_WARNING のエイリアス
: "${ICON_WARN:=${ICON_WARNING}}"

# -----------------------------------------------------------------------------
# module source (責務別分割)
# -----------------------------------------------------------------------------
# shellcheck source=hook-utils/json-io.sh
source "${BASH_SOURCE[0]%/*}/hook-utils/json-io.sh"
# shellcheck source=hook-utils/notification.sh
source "${BASH_SOURCE[0]%/*}/hook-utils/notification.sh"
# shellcheck source=hook-utils/path-helpers.sh
source "${BASH_SOURCE[0]%/*}/hook-utils/path-helpers.sh"
# shellcheck source=hook-utils/command-classifier.sh
source "${BASH_SOURCE[0]%/*}/hook-utils/command-classifier.sh"
