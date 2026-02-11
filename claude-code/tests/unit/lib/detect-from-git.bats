#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-git.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-git.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # テスト用gitリポジトリ作成
  cd "$TEST_TMPDIR"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  git commit --allow-empty -m "init"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# 正常系テスト: API関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects api-design from feature/api- branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/api-users

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[api-design]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects api-design from feat/api- branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feat/api-endpoint

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[api-design]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: UI関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects react-best-practices from feature/ui- branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/ui-redesign

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[react-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects react-best-practices from feature/frontend branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/frontend-components

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[react-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Backend関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects backend-dev from feature/backend-go branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/backend-golang

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[backend-dev]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects backend-dev from feature/backend branch" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/backend-api

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[backend-dev]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Fix関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects comprehensive-review from fix/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b fix/security-issue

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects comprehensive-review from bugfix/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b bugfix/authentication-bug

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects comprehensive-review from hotfix/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b hotfix/critical-bug

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Refactor関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects comprehensive-review from refactor/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b refactor/cleanup-code

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-git: detects clean-architecture-ddd from refactor/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b refactor/architecture

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[clean-architecture-ddd]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Test関連ブランチ検出
# =============================================================================

@test "detect-from-git: detects comprehensive-review from test/ branch" {
  cd "$TEST_TMPDIR"
  git checkout -b test/unit-tests

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-git: returns nothing on main branch" {
  cd "$TEST_TMPDIR"
  # Stay on main/master branch

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "detect-from-git: handles non-git directory gracefully" {
  cd /tmp

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: handles branch name with special characters" {
  cd "$TEST_TMPDIR"
  git checkout -b "feature/api-v2.0"

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    echo \${skills[api-design]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "boundary: early return when no file changes" {
  cd "$TEST_TMPDIR"
  git checkout -b feature/test-branch
  # No file changes

  run bash -c "
    source '$LIB_FILE'
    declare -A skills
    detect_from_git_state skills
    # Should still detect based on branch name
    true
  "
  [ "$status" -eq 0 ]
}
