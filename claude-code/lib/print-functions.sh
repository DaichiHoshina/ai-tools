#!/usr/bin/env bash
# =============================================================================
# Print Functions Library
# 共通の出力関数（DRY化）
# =============================================================================

# カラーコードを読み込み
_PRINT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=colors.sh
source "${_PRINT_LIB_DIR}/colors.sh"

# 出力関数
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# 確認プロンプト
confirm() {
    local message="$1"
    local default="${2:-n}"
    local answer

    if [ "$default" = "y" ]; then
        read -rp "$message [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -rp "$message [y/N]: " answer
        answer="${answer:-n}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}
