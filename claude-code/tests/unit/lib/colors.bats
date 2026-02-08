#!/usr/bin/env bats
# =============================================================================
# BATS Tests for colors.sh
# =============================================================================

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

# =============================================================================
# Color Code Exports
# =============================================================================

@test "colors: RED is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$RED\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0;31m" ]]
}

@test "colors: GREEN is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$GREEN\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0;32m" ]]
}

@test "colors: YELLOW is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$YELLOW\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[1;33m" ]]
}

@test "colors: BLUE is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$BLUE\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0;34m" ]]
}

@test "colors: CYAN is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$CYAN\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0;36m" ]]
}

@test "colors: MAGENTA is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$MAGENTA\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0;35m" ]]
}

@test "colors: BOLD is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$BOLD\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[1m" ]]
}

@test "colors: NC (No Color) is exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo \"\$NC\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\033[0m" ]]
}

# =============================================================================
# Integration: Colors work with echo -e
# =============================================================================

@test "integration: RED colors text correctly" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo -e \"\${RED}Error\${NC}\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Error" ]]
}

@test "integration: GREEN colors text correctly" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo -e \"\${GREEN}Success\${NC}\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Success" ]]
}

@test "integration: YELLOW colors text correctly" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo -e \"\${YELLOW}Warning\${NC}\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Warning" ]]
}

@test "integration: Multiple colors in one line" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo -e \"\${RED}Red\${NC} \${GREEN}Green\${NC} \${BLUE}Blue\${NC}\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Red" ]]
  [[ "$output" =~ "Green" ]]
  [[ "$output" =~ "Blue" ]]
}

@test "integration: BOLD with color" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && echo -e \"\${BOLD}\${RED}Bold Red\${NC}\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Bold Red" ]]
}

# =============================================================================
# No Side Effects
# =============================================================================

@test "colors: sourcing does not produce output" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == "" ]]
}

@test "colors: all variables are readonly or exported" {
  run bash -c "source '$PROJECT_ROOT/lib/colors.sh' && declare -p RED"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "declare -x" ]]
}
