#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-errors.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-errors.sh"
  export KEYWORDS_FILE="${PROJECT_ROOT}/lib/detect-from-keywords.sh"
}

# =============================================================================
# ヘルパー関数: JSON出力形式でテスト
# =============================================================================

# detect_from_errors を呼び出してJSON形式で結果を返す
run_detect_from_errors() {
  local prompt="$1"
  PROMPT_ARG="$prompt" bash -c '
    # _apply_skill_aliasesが必要なので両方sourceする
    source "$KEYWORDS_FILE"
    source "$LIB_FILE"
    declare -A skills
    context=""
    detect_from_errors "$PROMPT_ARG" skills context

    # JSON形式で出力
    printf "{\"skills\":["
    first=1
    for skill in "${!skills[@]}"; do
      [ $first -eq 0 ] && printf ","
      printf "\"%s\"" "$skill"
      first=0
    done
    printf "],\"context\":\"%s\"}" "$context"
  '
}

# =============================================================================
# 正常系テスト: Docker エラー検出
# =============================================================================

@test "detect-from-errors: detects container-ops from docker daemon error" {
  run run_detect_from_errors "Cannot connect to the Docker daemon at unix:///var/run/docker.sock"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  [ "$has_docker" = "true" ]
}

@test "detect-from-errors: detects container-ops from connection refused" {
  run run_detect_from_errors "docker: connection refused error"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  [ "$has_docker" = "true" ]
}

@test "detect-from-errors: includes context message for docker error" {
  run run_detect_from_errors "docker not running"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local context=$(echo "$output" | jq -r '.context')
  [[ "$context" =~ "Docker connection error detected" ]]
}

# =============================================================================
# 正常系テスト: Kubernetes エラー検出
# =============================================================================

@test "detect-from-errors: detects container-ops from CrashLoopBackOff" {
  run run_detect_from_errors "pod is in CrashLoopBackOff state"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_k8s=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  [ "$has_k8s" = "true" ]
}

@test "detect-from-errors: detects container-ops from ImagePullBackOff" {
  run run_detect_from_errors "ImagePullBackOff: failed to pull image"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_k8s=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  [ "$has_k8s" = "true" ]
}

# =============================================================================
# 正常系テスト: Terraform エラー検出
# =============================================================================

@test "detect-from-errors: detects terraform from state lock error" {
  run run_detect_from_errors "Error acquiring the state lock"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_terraform=$(echo "$output" | jq '.skills | contains(["terraform"])')
  [ "$has_terraform" = "true" ]
}

@test "detect-from-errors: detects terraform from plan failed" {
  run run_detect_from_errors "terraform plan failed with errors"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_terraform=$(echo "$output" | jq '.skills | contains(["terraform"])')
  [ "$has_terraform" = "true" ]
}

# =============================================================================
# 正常系テスト: TypeScript エラー検出
# =============================================================================

@test "detect-from-errors: detects backend-dev from type error" {
  run run_detect_from_errors "Type error TS2304: Cannot find name 'foo'"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_typescript=$(echo "$output" | jq '.skills | map(select(. == "backend-dev")) | length > 0')
  [ "$has_typescript" = "true" ]
}

@test "detect-from-errors: detects backend-dev from property error" {
  run run_detect_from_errors "Property 'bar' does not exist on type 'Foo'"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_typescript=$(echo "$output" | jq '.skills | map(select(. == "backend-dev")) | length > 0')
  [ "$has_typescript" = "true" ]
}

# =============================================================================
# 正常系テスト: Go エラー検出
# =============================================================================

@test "detect-from-errors: detects backend-dev from undefined error" {
  run run_detect_from_errors "undefined: someFunction"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_go=$(echo "$output" | jq '.skills | map(select(. == "backend-dev")) | length > 0')
  [ "$has_go" = "true" ]
}

@test "detect-from-errors: detects backend-dev from build failed" {
  run run_detect_from_errors "go build failed: cannot use x as y in assignment"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_go=$(echo "$output" | jq '.skills | map(select(. == "backend-dev")) | length > 0')
  [ "$has_go" = "true" ]
}

# =============================================================================
# 正常系テスト: セキュリティエラー検出
# =============================================================================

@test "detect-from-errors: detects comprehensive-review from CVE" {
  run run_detect_from_errors "CVE-2023-12345: vulnerability detected"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_security=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review")) | length > 0')
  [ "$has_security" = "true" ]
}

@test "detect-from-errors: detects comprehensive-review from XSS" {
  run run_detect_from_errors "XSS vulnerability found in user input"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_security=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review")) | length > 0')
  [ "$has_security" = "true" ]
}

@test "detect-from-errors: includes security context message" {
  run run_detect_from_errors "SQL injection vulnerability"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local context=$(echo "$output" | jq -r '.context')
  [[ "$context" =~ "Security issue detected" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-errors: returns nothing when no error patterns match" {
  run run_detect_from_errors 'normal message without errors'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local skills_count=$(echo "$output" | jq '.skills | length')
  [ "$skills_count" -eq 0 ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: detects multiple error types in single prompt" {
  run run_detect_from_errors 'Cannot connect to the Docker daemon and CVE-2023-123 security warning'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  # 複数のスキルが検出されることを確認
  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  local has_security=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review")) | length > 0')

  [ "$has_docker" = "true" ]
  [ "$has_security" = "true" ]
}

@test "boundary: handles case-insensitive error matching" {
  run run_detect_from_errors "CANNOT CONNECT TO THE DOCKER DAEMON"
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops")) | length > 0')
  [ "$has_docker" = "true" ]
}
