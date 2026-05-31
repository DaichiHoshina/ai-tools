#!/usr/bin/env bats
# =============================================================================
# session-bloat check の bats tests
# _check_session_bloat: elapsed > 3h or msg > 1000 で warn、15min throttle
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  export ORIG_HOME="$HOME"
  # テスト用 HOME (本番 .claude dir を汚染しない)
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude/projects"
  mkdir -p "${HOME}/.claude/logs"
  # hook が参照する ctx/serena file を無効化
  export CLAUDE_CTX_FILE="${HOME}/_ctx_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${HOME}/_serena_unset"
  export JP_QUALITY_INJECT_OFF=1
}

teardown() {
  if [[ "${HOME}" != "${ORIG_HOME}" && "${HOME}" == /tmp/* ]]; then
    rm -rf "${HOME}"
  fi
  export HOME="${ORIG_HOME}"
  # throttle flag cleanup
  rm -f /tmp/claude_session_bloat_bats-test-* 2>/dev/null || true
}

# ヘルパー: fake session jsonl を生成する
# 引数: $1=session_id, $2=elapsed_seconds(from now), $3=msg_count
_make_session_jsonl() {
  local session_id="$1"
  local elapsed_seconds="$2"
  local msg_count="$3"

  local cwd="${HOME}/testproject"
  local slug="${cwd//\//-}"
  slug="${slug//\./-}"
  local dir="${HOME}/.claude/projects/${slug}"
  mkdir -p "${dir}"
  local jsonl="${dir}/${session_id}.jsonl"

  # 1行目: timestamp (session start = now - elapsed)
  local start_epoch=$(( EPOCHSECONDS - elapsed_seconds ))
  # macOS: date -r <epoch> で ISO8601 生成 (Linux fallback: date -d @)
  local start_ts
  start_ts=$(date -r "${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -d "@${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null)
  printf '{"type":"attachment","timestamp":"%s"}\n' "${start_ts}" > "${jsonl}"

  # user/assistant 行を msg_count 分追加
  local i
  for (( i=0; i<msg_count; i++ )); do
    if (( i % 2 == 0 )); then
      printf '{"type":"user","timestamp":"%s"}\n' "${start_ts}"
    else
      printf '{"type":"assistant","timestamp":"%s"}\n' "${start_ts}"
    fi
  done >> "${jsonl}"

  echo "${jsonl}"
  echo "${cwd}"
}

# =============================================================================
# Case 1: elapsed < 3h かつ msg < 1000 → session-bloat warn が出ない
# =============================================================================
@test "session-bloat: no warn when elapsed=1h and msg=100" {
  local session_id="bats-test-no-warn-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  # elapsed 1h = 3600s, msg 100
  local jsonl cwd
  jsonl=$(_make_session_jsonl "${session_id}" 3600 100 | head -1)
  cwd=$(_make_session_jsonl "${session_id}" 3600 100 | tail -1)

  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' echo '${input}' | '${HOOKS_DIR}/user-prompt-submit.sh'"
  [ "$status" -eq 0 ]
  # stdout / stderr のどちらにも session-bloat が出ないこと
  [[ ! "$output" =~ "session-bloat" ]]
}

# =============================================================================
# Case 2: elapsed > 3h → session-bloat warn が出る
# =============================================================================
@test "session-bloat: warn when elapsed > 3h" {
  local session_id="bats-test-elapsed-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  # 先に throttle flag が無いことを確認
  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"

  # elapsed 4h = 14400s, msg 50
  _make_session_jsonl "${session_id}" 14400 50 > /dev/null
  # cwd を再取得
  local cwd="${HOME}/testproject"

  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  # CLAUDE_CODE_SESSION_ID で session_id を固定
  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  # additionalContext に session-bloat が含まれること
  [[ "$output" =~ "session-bloat" ]]
}

# =============================================================================
# Case 3: throttle - 同 session 2 回目は 15min 以内なら warn 抑制
# =============================================================================
@test "session-bloat: throttle suppresses 2nd warn within 15min" {
  local session_id="bats-test-throttle-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)
  local bloat_flag="/tmp/claude_session_bloat_${session_id}_${date_today}"

  # elapsed 4h, msg 50
  _make_session_jsonl "${session_id}" 14400 50 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  # 1回目: warn が出て throttle flag が作られる
  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-bloat" ]]
  [ -f "${bloat_flag}" ]

  # 2回目: throttle (15min以内)、warn 抑制
  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "session-bloat" ]]
}
