#!/usr/bin/env bats
# =============================================================================
# BATS Tests for mcp-installer.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../" && pwd)"
  export LIB_DIR="${PROJECT_ROOT}/claude-code/lib"
  export LIB_FILE="${LIB_DIR}/mcp-installer.sh"
}

# =============================================================================
# mcp-installer.sh function tests
# =============================================================================

@test "mcp-installer: file exists" {
  [ -f "${LIB_DIR}/mcp-installer.sh" ]
}

@test "mcp-installer: file is readable" {
  [ -r "${LIB_DIR}/mcp-installer.sh" ]
}

@test "mcp-installer: generate_gitlab_mcp_sh function defined" {
  grep -q "^generate_gitlab_mcp_sh()" "${LIB_DIR}/mcp-installer.sh"
  [ $? -eq 0 ]
}

@test "mcp-installer: generate_mcp_json function defined" {
  grep -q "^generate_mcp_json()" "${LIB_DIR}/mcp-installer.sh"
  [ $? -eq 0 ]
}

@test "mcp-installer: install_mcp_servers function defined" {
  grep -q "^install_mcp_servers()" "${LIB_DIR}/mcp-installer.sh"
  [ $? -eq 0 ]
}

@test "mcp-installer: generate_gitlab_mcp_sh uses print_success" {
  grep -A 12 "^generate_gitlab_mcp_sh()" "${LIB_DIR}/mcp-installer.sh" | grep -q "print_success"
  [ $? -eq 0 ]
}

@test "mcp-installer: generate_mcp_json uses print_info" {
  grep -A 5 "^generate_mcp_json()" "${LIB_DIR}/mcp-installer.sh" | grep -q "print_info"
  [ $? -eq 0 ]
}

@test "mcp-installer: install_mcp_servers uses print_header" {
  grep -A 5 "^install_mcp_servers()" "${LIB_DIR}/mcp-installer.sh" | grep -q "print_header"
  [ $? -eq 0 ]
}

@test "mcp-installer: generate_gitlab_mcp_sh substitutes template variable" {
  grep -q "__GITLAB_API_URL__" "${LIB_DIR}/mcp-installer.sh"
  [ $? -eq 0 ]
}

@test "mcp-installer: generate_mcp_json uses envsubst" {
  grep -q "envsubst" "${LIB_DIR}/mcp-installer.sh"
  [ $? -eq 0 ]
}

@test "mcp-installer: install_mcp_servers uses confirm function" {
  grep "^install_mcp_servers()" -A 10 "${LIB_DIR}/mcp-installer.sh" | grep -q "confirm"
  [ $? -eq 0 ]
}
