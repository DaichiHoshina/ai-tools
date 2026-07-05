#!/usr/bin/env bash
# =============================================================================
# Log rotation helper (size-based, .bak rename)
# _TH_LOG_MAX_BYTES 超えた log file を "<file>.<YYYYMMDDHHMMSS>.bak" に mv する。
# 呼出側は rotation 後に対象 log へ append し直す想定。
# =============================================================================

if [[ "${_LOG_ROTATION_LOADED:-}" == "1" ]]; then
    return 0
fi
_LOG_ROTATION_LOADED=1

# shellcheck source=./thresholds.sh
source "${BASH_SOURCE[0]%/*}/thresholds.sh"
# shellcheck source=./portable-stat.sh
source "${BASH_SOURCE[0]%/*}/portable-stat.sh"

# usage: _rotate_log_if_needed <log_file> [keep_bak_count]
# keep_bak_count: 保持する .bak 世代数 (未指定 or 0 = 世代削除しない)
#                 1 以上を渡すと ls -1t で新しい順に並べ、keep_bak_count 個より
#                 古い .bak を rm する。
_rotate_log_if_needed() {
  local log_file="$1"
  local keep_bak_count="${2:-0}"
  [[ -f "$log_file" ]] || return 0
  local fsize
  fsize=$(portable_stat_size "$log_file")
  [[ "${fsize}" -gt ${_TH_LOG_MAX_BYTES} ]] || return 0
  local _bak_ts; printf -v _bak_ts '%(%Y%m%d%H%M%S)T' -1
  mv "$log_file" "${log_file}.${_bak_ts}.bak" 2>/dev/null || true
  if [[ "${keep_bak_count}" -gt 0 ]]; then
    # shellcheck disable=SC2012
    ls -1t "${log_file}".*.bak 2>/dev/null | tail -n +$((keep_bak_count + 1)) | xargs -I{} rm -f {} 2>/dev/null || true
  fi
}
