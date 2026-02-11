#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-files.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-files.sh"
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
# 正常系テスト: Goファイル検出
# =============================================================================

@test "detect-from-files: detects golang from .go file" {
  cd "$TEST_TMPDIR"
  touch main.go
  git add main.go

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[golang]:-0}:\${skills[backend-dev]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: TypeScript検出
# =============================================================================

@test "detect-from-files: detects typescript from .ts file" {
  cd "$TEST_TMPDIR"
  touch index.ts
  git add index.ts

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[typescript]:-0}:\${skills[backend-dev]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

@test "detect-from-files: detects typescript from .tsx file" {
  cd "$TEST_TMPDIR"
  touch component.tsx
  git add component.tsx

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[typescript]:-0}:\${skills[backend-dev]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: React検出
# =============================================================================

@test "detect-from-files: detects react from .jsx file" {
  cd "$TEST_TMPDIR"
  touch App.jsx
  git add App.jsx

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[react]:-0}:\${skills[react-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

@test "detect-from-files: detects react from components/ directory" {
  cd "$TEST_TMPDIR"
  mkdir -p components
  touch components/Header.tsx
  git add components/Header.tsx

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[react]:-0}:\${skills[react-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: Docker検出
# =============================================================================

@test "detect-from-files: detects docker from Dockerfile" {
  cd "$TEST_TMPDIR"
  touch Dockerfile
  git add Dockerfile

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${skills[container-ops]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-files: detects docker from docker-compose.yml" {
  cd "$TEST_TMPDIR"
  touch docker-compose.yml
  git add docker-compose.yml

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${skills[container-ops]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Kubernetes検出
# =============================================================================

@test "detect-from-files: detects container-ops from deployment.yaml" {
  cd "$TEST_TMPDIR"
  mkdir -p k8s
  touch k8s/deployment.yaml
  git add k8s/deployment.yaml

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${skills[container-ops]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Terraform検出
# =============================================================================

@test "detect-from-files: detects terraform from .tf file" {
  cd "$TEST_TMPDIR"
  touch main.tf
  git add main.tf

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${skills[terraform]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: テストファイル検出
# =============================================================================

@test "detect-from-files: detects test review from _test.go" {
  cd "$TEST_TMPDIR"
  touch handler_test.go
  git add handler_test.go

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${skills[comprehensive-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-files: returns nothing when no files changed" {
  cd "$TEST_TMPDIR"
  # No changes

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${#langs[@]}:\${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0:0" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: detects multiple patterns from multiple files" {
  cd "$TEST_TMPDIR"
  touch main.go Dockerfile index.ts
  git add main.go Dockerfile index.ts

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    # Check that multiple languages/skills are detected
    [ \${langs[golang]:-0} -eq 1 ] && \
    [ \${langs[typescript]:-0} -eq 1 ] && \
    [ \${skills[container-ops]:-0} -eq 1 ]
  "
  [ "$status" -eq 0 ]
}

@test "boundary: handles special characters in file names" {
  cd "$TEST_TMPDIR"
  touch "test-file.go"
  git add "test-file.go"

  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    detect_from_files langs skills
    echo \${langs[golang]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}
