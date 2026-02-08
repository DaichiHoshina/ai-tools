#!/usr/bin/env bash
# =============================================================================
# common.sh - 共有ライブラリ共通エントリポイント
# 全 lib/ ファイルの共通前提条件と順序付き読み込み
# =============================================================================
#
# 使用方法:
#   source /path/to/lib/common.sh
#
# オプション環境変数:
#   COMMON_LOAD_I18N=true  # i18n.sh を読み込む（デフォルト: false）
#
# 必要なbashバージョン: 4.2+
#   理由: i18n.sh で declare -gA（グローバル連想配列）を使用
#
# =============================================================================

# --- バージョンチェック ---
_COMMON_MIN_BASH_MAJOR=4
_COMMON_MIN_BASH_MINOR=2

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

# Level 2: print-functions に依存（オプション）
if [[ "${COMMON_LOAD_I18N:-false}" = "true" ]]; then
    if [[ -f "${_COMMON_LIB_DIR}/i18n.sh" ]]; then
        source "${_COMMON_LIB_DIR}/i18n.sh"
    else
        echo "WARNING: i18n.sh not found, COMMON_LOAD_I18N=true but file missing" >&2
    fi
fi

# --- ヘルパー関数 ---

# lib ファイルを安全に読み込み
# Usage: load_lib "detect-from-files.sh"
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

# バージョン情報出力
common_version() {
    echo "common.sh v1.0.0"
    echo "  bash: ${BASH_VERSION}"
    echo "  lib_dir: ${_COMMON_LIB_DIR}"
    echo "  loaded_libs: colors, print-functions, security-functions, hook-utils"
    if [[ "${COMMON_LOAD_I18N:-false}" = "true" ]]; then
        echo "  i18n: enabled"
    fi
}

# 読み込み済みライブラリ一覧表示
common_list_loaded() {
    echo "Loaded libraries:"
    declare -F | awk '{print $3}' | grep -E '^(print_|validate_|escape_|msg|load_lib|common_)' | sort | uniq
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
