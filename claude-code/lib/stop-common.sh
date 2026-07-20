# shellcheck shell=bash
# MEMO: Stop 系 hook (stop.sh / stop-verify.sh / stop-failure.sh) の共通 init を持たせる。
# log redirect の有無だけ差があるため caller 側で扱い、init 関数は hook-utils source と require_jq のみを担う。

stop_hook_init() {
  local script_dir="${1:-${SCRIPT_DIR:-}}"
  if [[ -z "${script_dir}" ]]; then
    echo "stop_hook_init: SCRIPT_DIR が未設定" >&2
    return 1
  fi
  # shellcheck source=hook-utils.sh
  source "${script_dir}/../lib/hook-utils.sh"
  require_jq
}
