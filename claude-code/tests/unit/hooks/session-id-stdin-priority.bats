#!/usr/bin/env bats
# =============================================================================
# session_id 解決は stdin JSON 優先が repo 規約。env CLAUDE_CODE_SESSION_ID を
# 第一候補にする代入 (="${CLAUDE_CODE_SESSION_ID:- ...) が再発しないか検証する
# (2026-06-25 incident: env に前 session の値が leak し、session 切替を誤検知した)
# =============================================================================

setup() {
  load "../../helpers/common"
}

# env 優先 pattern 検出。"=${CLAUDE_CODE_SESSION_ID:-" (= の直後に env var が第一候補で
# 来る代入) のみを violation とする。fallback 用途で内側に置く
# "${VAR:-${CLAUDE_CODE_SESSION_ID:-...}}" は = の直後ではないため誤検知しない。
_find_env_first_violations() {
  grep -rnF '="${CLAUDE_CODE_SESSION_ID:-' \
    "${PROJECT_ROOT}"/hooks/*.sh \
    "${PROJECT_ROOT}"/hooks/lib/*.sh \
    "${PROJECT_ROOT}"/lib/**/*.sh 2>/dev/null || true
}

@test "hooks/lib scripts do not prioritize env CLAUDE_CODE_SESSION_ID over stdin JSON" {
  shopt -s globstar 2>/dev/null || true
  local violations
  violations="$(_find_env_first_violations)"
  if [ -n "$violations" ]; then
    echo "env-first session_id pattern found (stdin JSON must win):"
    echo "$violations"
  fi
  [ -z "$violations" ]
}

@test "_find_env_first_violations detects a synthetic env-first assignment" {
  local tmp_file
  tmp_file="$(mktemp /tmp/session-id-violation-XXXX.sh)"
  printf 'SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${SESSION_ID}}"\n' > "$tmp_file"
  run grep -nF '="${CLAUDE_CODE_SESSION_ID:-' "$tmp_file"
  rm -f "$tmp_file"
  [ "$status" -eq 0 ]
  [[ "$output" == *'CLAUDE_CODE_SESSION_ID:-'* ]]
}

@test "_find_env_first_violations does not flag stdin-first fallback pattern" {
  local tmp_file
  tmp_file="$(mktemp /tmp/session-id-ok-XXXX.sh)"
  printf 'SESSION_ID="${SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"\n' > "$tmp_file"
  run grep -nF '="${CLAUDE_CODE_SESSION_ID:-' "$tmp_file"
  rm -f "$tmp_file"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
