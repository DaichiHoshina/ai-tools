#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/context-injectors.sh — _stable_session_key
# SESSION_ID 空時の fallback key が session を跨いで衝突しないこと
# (cwd hash 単独だと同 repo の別 session が dedup flag を共有し、
#  2 本目に guard 注入が入らない under-injection が起きる)
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/hooks/lib/context-injectors.sh"
}

@test "_stable_session_key: SESSION_ID があればそのまま返す" {
  run bash -c "source '$LIB_FILE' && SESSION_ID='sess-abc' _stable_session_key"
  [ "$status" -eq 0 ]
  [ "$output" = "sess-abc" ]
}

@test "_stable_session_key: fallback key は cwd hash + 親 PID の形式" {
  run bash -c "source '$LIB_FILE' && SESSION_ID='' _stable_session_key"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^cwd[0-9]+-p[0-9]+$ ]]
}

@test "_stable_session_key: fallback key に呼び出し元の親 PID が入る" {
  run bash -c "source '$LIB_FILE' && printf '%s %s' \"\$(SESSION_ID='' _stable_session_key)\" \"\$PPID\""
  [ "$status" -eq 0 ]
  local key="${output% *}"
  local ppid="${output#* }"
  [[ "$key" == *"-p${ppid}" ]]
}

@test "_stable_session_key: cwd が違えば fallback key も変わる" {
  run bash -c "source '$LIB_FILE' && k1=\$(SESSION_ID='' CLAUDE_PROJECT_DIR=/tmp/a _stable_session_key) && k2=\$(SESSION_ID='' CLAUDE_PROJECT_DIR=/tmp/b _stable_session_key) && [ \"\$k1\" != \"\$k2\" ]"
  [ "$status" -eq 0 ]
}
