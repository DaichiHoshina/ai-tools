#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-errors.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-errors.sh"
}

# =============================================================================
# 正常系テスト: Docker エラー検出
# =============================================================================

@test "detect-from-errors: detects docker-troubleshoot from docker daemon error" {
  local prompt="Cannot connect to the Docker daemon at unix:///var/run/docker.sock"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[docker-troubleshoot]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects docker-troubleshoot from connection refused" {
  local prompt="docker: connection refused error"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[docker-troubleshoot]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: includes context message for docker error" {
  local prompt="docker not running"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \"\$context\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Docker connection error detected" ]]
}

# =============================================================================
# 正常系テスト: Kubernetes エラー検出
# =============================================================================

@test "detect-from-errors: detects kubernetes from CrashLoopBackOff" {
  local prompt="pod is in CrashLoopBackOff state"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[kubernetes]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects kubernetes from ImagePullBackOff" {
  local prompt="ImagePullBackOff: failed to pull image"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[kubernetes]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Terraform エラー検出
# =============================================================================

@test "detect-from-errors: detects terraform from state lock error" {
  local prompt="Error acquiring the state lock"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[terraform]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects terraform from plan failed" {
  local prompt="terraform plan failed with errors"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[terraform]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: TypeScript エラー検出
# =============================================================================

@test "detect-from-errors: detects typescript-backend from type error" {
  local prompt="Type error TS2304: Cannot find name 'foo'"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[typescript-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects typescript-backend from property error" {
  local prompt="Property 'bar' does not exist on type 'Foo'"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[typescript-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Go エラー検出
# =============================================================================

@test "detect-from-errors: detects go-backend from undefined error" {
  local prompt="undefined: someFunction"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[go-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects go-backend from build failed" {
  local prompt="go build failed: cannot use x as y in assignment"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[go-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: セキュリティエラー検出
# =============================================================================

@test "detect-from-errors: detects security-error-review from CVE" {
  local prompt="CVE-2023-12345: vulnerability detected"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[security-error-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: detects security-error-review from XSS" {
  local prompt="XSS vulnerability found in user input"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[security-error-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-errors: includes security context message" {
  local prompt="SQL injection vulnerability"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \"\$context\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Security issue detected" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-errors: returns nothing when no error patterns match" {
  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    context=''
    detect_from_errors 'normal message without errors' skills context
    echo \${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: detects multiple error types in single prompt" {
  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    context=''
    detect_from_errors 'Docker daemon error and CVE-2023-123 security warning' skills context
    # Check multiple skills detected
    [ \${skills[docker-troubleshoot]:-0} -eq 1 ] && \
    [ \${skills[security-error-review]:-0} -eq 1 ]
  "
  [ "$status" -eq 0 ]
}

@test "boundary: handles case-insensitive error matching" {
  local prompt="CANNOT CONNECT TO THE DOCKER DAEMON"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    local context=''
    detect_from_errors '$prompt' skills context
    echo \${skills[docker-troubleshoot]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}
