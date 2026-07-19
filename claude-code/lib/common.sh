#!/usr/bin/env bash
# =============================================================================
# common.sh - 共有ライブラリ共通エントリポイント
# 全 lib/ ファイルの共通前提条件と順序付き読み込み
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/common.sh
#
# 必要なbashバージョン: 5.0+
#   理由: EPOCHREALTIME / EPOCHSECONDS builtin (bash 5.0+) を session-start.sh で使用
#
# =============================================================================

set -euo pipefail

# --- バージョンチェック ---
_COMMON_MIN_BASH_MAJOR=5
_COMMON_MIN_BASH_MINOR=0

if [[ "${BASH_VERSINFO[0]}" -lt "$_COMMON_MIN_BASH_MAJOR" ]] || \
   [[ "${BASH_VERSINFO[0]}" -eq "$_COMMON_MIN_BASH_MAJOR" && \
      "${BASH_VERSINFO[1]}" -lt "$_COMMON_MIN_BASH_MINOR" ]]; then
    echo "ERROR: bash ${_COMMON_MIN_BASH_MAJOR}.${_COMMON_MIN_BASH_MINOR}+ required (current: ${BASH_VERSION})" >&2
    echo "       On macOS: brew install bash" >&2
    echo "       On Linux: bash is usually 4.2+ by default" >&2
    exit 1
fi

# --- パス解決 ---
_COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 重複読み込み防止 ---
if [[ "${_COMMON_LOADED:-}" = "true" ]]; then
    # shellcheck disable=SC2317  # multi-source guard: 以降の関数定義は実際に呼ばれる
    return 0 2>/dev/null || true
fi
_COMMON_LOADED=true

# --- 依存ツールチェック ---
_COMMON_MISSING_TOOLS=()

if ! command -v jq &>/dev/null; then
    _COMMON_MISSING_TOOLS+=("jq")
fi

if ! command -v git &>/dev/null; then
    _COMMON_MISSING_TOOLS+=("git")
fi

if [ ${#_COMMON_MISSING_TOOLS[@]} -gt 0 ]; then
    echo "WARNING: Missing required tools: ${_COMMON_MISSING_TOOLS[*]}" >&2
    echo "         Some lib functions may not work correctly" >&2
fi

# --- 依存順序付き読み込み ---

# Level 0: 依存なし
if [[ -f "${_COMMON_LIB_DIR}/colors.sh" ]]; then
    source "${_COMMON_LIB_DIR}/colors.sh"
fi

# Level 1: colors.sh に依存
if [[ -f "${_COMMON_LIB_DIR}/print-functions.sh" ]]; then
    source "${_COMMON_LIB_DIR}/print-functions.sh"
fi

# Level 2: 依存なし（常に読み込み）
if [[ -f "${_COMMON_LIB_DIR}/security-functions.sh" ]]; then
    source "${_COMMON_LIB_DIR}/security-functions.sh"
fi

if [[ -f "${_COMMON_LIB_DIR}/hook-utils.sh" ]]; then
    source "${_COMMON_LIB_DIR}/hook-utils.sh"
fi

# --- ヘルパー関数 ---

# lib ファイルを安全に読み込み
# Usage: load_lib "detect-from-keywords.sh"
load_lib() {
    local lib_name="$1"
    local lib_path="${_COMMON_LIB_DIR}/${lib_name}"

    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
    else
        # print_warning が利用可能な場合はそれを使用
        if declare -f print_warning &>/dev/null; then
            print_warning "Library not found: ${lib_name}"
        else
            echo "WARNING: Library not found: ${lib_name}" >&2
        fi
        return 1
    fi
}

# =============================================================================
# プラットフォーム互換性ヘルパー関数
# =============================================================================

# プラットフォーム検出
# Returns: "macos" or "linux"
detect_platform() {
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# sed in-place wrapper (Linux/macOS互換)
# Usage: sed_inplace 'pattern' file
sed_inplace() {
    local pattern="$1"
    local file="$2"
    
    if [[ "$(detect_platform)" == "macos" ]]; then
        sed -i.bak "$pattern" "$file"
        rm -f "${file}.bak"
    else
        sed -i "$pattern" "$file"
    fi
}
