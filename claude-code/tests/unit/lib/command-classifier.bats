#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/hook-utils/command-classifier.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils/command-classifier.sh"
}

@test "command-classifier: sourcing does not produce output" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# classify_bash_command: Forbidden
# =============================================================================

@test "classify_bash_command: rm -rf / は Forbidden" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'rm -rf /' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Forbidden" ]
}

@test "classify_bash_command: git push --force は Forbidden" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'git push --force origin main' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Forbidden" ]
}

# =============================================================================
# classify_bash_command: Boundary
# =============================================================================

@test "classify_bash_command: git commit は Boundary" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'git commit -m \"test\"' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Boundary" ]
}

@test "classify_bash_command: eslint --fix は Boundary (自動整形)" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'eslint --fix .' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Boundary" ]
}

# =============================================================================
# classify_bash_command: Safe
# =============================================================================

@test "classify_bash_command: git status は Safe" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'git status' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Safe" ]
}

@test "classify_bash_command: pwd は Safe" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'pwd' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Safe" ]
}

@test "classify_bash_command: パイプを含む git status は Safe から除外され Boundary になる" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'git status | grep foo' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Boundary" ]
}

@test "classify_bash_command: commit message 内の危険語リテラルは誤検出しない" {
  run bash -c "source '$LIB_FILE' && classify_bash_command 'git commit -m \"add rm -rf handling\"' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Boundary" ]
}

# =============================================================================
# detect_dangerous_patterns
# =============================================================================

@test "detect_dangerous_patterns: AWS Access Key literal は Forbidden に昇格" {
  local key="AKI""A0123456789ABCDEF"
  run bash -c "source '$LIB_FILE' && detect_dangerous_patterns 'key=${key}' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Forbidden" ]
}

@test "detect_dangerous_patterns: 危険パターンなしの content は GUARD_CLASS を変更しない" {
  run bash -c "source '$LIB_FILE' && GUARD_CLASS=Safe; detect_dangerous_patterns 'echo hello' && echo \"\$GUARD_CLASS\""
  [ "$status" -eq 0 ]
  [ "$output" = "Safe" ]
}

@test "detect_dangerous_patterns: SSRF cloud metadata access を検出する" {
  run bash -c "source '$LIB_FILE' && detect_dangerous_patterns 'curl http://169.254.169.254/latest/meta-data/' && echo \"\$MESSAGE\""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SSRF" ]]
}

# =============================================================================
# _is_go_full_build_or_test
# =============================================================================

@test "_is_go_full_build_or_test: go build ./... は block" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'go build ./...'"
  [ "$status" -eq 0 ]
}

@test "_is_go_full_build_or_test: go test -v ./... (flag 挟み) は block" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'go test -v -tags integration ./...'"
  [ "$status" -eq 0 ]
}

@test "_is_go_full_build_or_test: cd 連結の go test ./... は block" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'cd backend && go test ./...'"
  [ "$status" -eq 0 ]
}

@test "_is_go_full_build_or_test: path 絞り込み (./pkg/foo/...) は通す" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'go test ./pkg/foo/...'"
  [ "$status" -eq 1 ]
}

@test "_is_go_full_build_or_test: go vet ./... は通す" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'go vet ./...'"
  [ "$status" -eq 1 ]
}

@test "_is_go_full_build_or_test: -p 4 明示は通す" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test 'go build -p 4 ./...'"
  [ "$status" -eq 1 ]
}

@test "_is_go_full_build_or_test: commit message 内の literal は誤 block しない" {
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test \"git commit -m 'stop running go test ./... on CI'\""
  [ "$status" -eq 1 ]
}

@test "_is_go_full_build_or_test: heredoc 本文内の literal は誤 block しない" {
  cmd='cat <<EOS
go test ./...
EOS'
  run bash -c "source '$LIB_FILE' && _is_go_full_build_or_test \"\$1\"" _ "$cmd"
  [ "$status" -eq 1 ]
}

@test "_strip_message_args: commit message を除去し他は保持する" {
  run bash -c "source '$LIB_FILE' && _strip_message_args \"git commit -m 'go test ./...' && go vet ./pkg\""
  [ "$status" -eq 0 ]
  [[ "$output" != *"go test ./..."* ]]
  [[ "$output" == *"go vet ./pkg"* ]]
}
