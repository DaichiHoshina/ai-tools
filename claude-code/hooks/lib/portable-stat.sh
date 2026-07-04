#!/usr/bin/env bash
# =============================================================================
# Portable stat wrappers (GNU / BSD 両対応)
# GNU (stat -c) を先に試す: GNU の stat -f は filesystem mode 表示で garbage を返すため順序重要。
# 呼出側で 0 fallback を持つよう、失敗時は "0" を stdout に出す。
# =============================================================================

if [[ "${_PORTABLE_STAT_LOADED:-}" == "1" ]]; then
    return 0
fi
_PORTABLE_STAT_LOADED=1

# usage: mtime=$(portable_stat_mtime "$path")
portable_stat_mtime() {
  stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null || echo 0
}

# usage: size=$(portable_stat_size "$path")
portable_stat_size() {
  stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1" 2>/dev/null || echo 0
}

# usage: sig=$(portable_stat_mtime_size "$path")   # "mtime-size"
portable_stat_mtime_size() {
  stat -c '%Y-%s' "$1" 2>/dev/null || stat -f '%m-%z' "$1" 2>/dev/null || echo "0-0"
}
