#!/usr/bin/env bats
# =============================================================================
# session-bloat check の bats tests
# _check_session_bloat: elapsed > 3h or msg > 1000 or token >= 500K で warn、15min throttle
# =============================================================================

setup() {
  # shellcheck source=../helpers/common.bash
  load "../helpers/common"
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
# 引数: $1=session_id, $2=elapsed_seconds(from now), $3=msg_count, $4=tokens_per_assistant(省略可、default=0)
_make_session_jsonl() {
  local session_id="$1"
  local elapsed_seconds="$2"
  local msg_count="$3"
  local tokens_per_assistant="${4:-0}"

  local cwd="${HOME}/testproject"
  local slug="${cwd//\//-}"
  slug="${slug//\./-}"
  local dir="${HOME}/.claude/projects/${slug}"
  mkdir -p "${dir}"
  local jsonl="${dir}/${session_id}.jsonl"

  # 1行目: timestamp (session start = now - elapsed)
  local start_epoch=$(( EPOCHSECONDS - elapsed_seconds ))
  # macOS: date -r <epoch> で ISO8601 生成 (Linux fallback: date -d @)
  # UTC 表記で生成 (parser 側が TZ=UTC で解釈するため一致させる)
  local start_ts
  start_ts=$(date -u -r "${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "@${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null)
  printf '{"type":"attachment","timestamp":"%s"}\n' "${start_ts}" > "${jsonl}"

  # user/assistant 行を msg_count 分追加
  # assistant entry には tokens_per_assistant > 0 の場合に usage フィールドを付与
  local i
  for (( i=0; i<msg_count; i++ )); do
    if (( i % 2 == 0 )); then
      printf '{"type":"user","timestamp":"%s"}\n' "${start_ts}"
    else
      if (( tokens_per_assistant > 0 )); then
        printf '{"type":"assistant","timestamp":"%s","message":{"usage":{"input_tokens":%d,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}\n' \
          "${start_ts}" "${tokens_per_assistant}"
      else
        printf '{"type":"assistant","timestamp":"%s"}\n' "${start_ts}"
      fi
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

# =============================================================================
# Case 4: token >= 5M → session-bloat warn が出る (token=XM 形式)
# =============================================================================
@test "session-bloat: warn when token >= 5M" {
  local session_id="bats-test-token-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  # throttle flag を削除
  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"

  # elapsed 1h (3h 未満)、msg 100 (1000 未満)、token: assistant 10 entry × 600000 = 6M
  _make_session_jsonl "${session_id}" 3600 20 600000 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-bloat" ]]
  [[ "$output" =~ "token=" ]]
}

# =============================================================================
# Case 5: token < 5M かつ elapsed < 3h かつ msg < 1000 → warn 不要
# =============================================================================
@test "session-bloat: no warn when token=1M elapsed=25min msg=50" {
  local session_id="bats-test-token-nowarn-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"

  # elapsed 25min (idle 30min 閾値未達)、token 1M (< 5M)、msg 20 (< 1000)
  _make_session_jsonl "${session_id}" 1500 20 100000 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "session-bloat" ]]
}

# =============================================================================
# Case 6: python3 失敗時 (PATH 隠蔽) → elapsed/msg 判定は動作する
# =============================================================================
@test "session-bloat: python3 failure falls back to elapsed/msg check" {
  local session_id="bats-test-py3-fallback-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"

  # elapsed 4h (3h 超)、msg 50、token=0 (python3 が無いので集計されない)
  _make_session_jsonl "${session_id}" 14400 50 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  # python3 をスタブ化して失敗させる: fake_bin/python3 が常に exit 1 を返す
  local fake_bin="${HOME}/fake_bin"
  mkdir -p "${fake_bin}"
  printf '#!/usr/bin/env bash\nexit 1\n' > "${fake_bin}/python3"
  chmod +x "${fake_bin}/python3"
  run bash -c "PATH='${fake_bin}:${PATH}' CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  # elapsed > 3h なので session-bloat warn は出るはず (elapsed= を含む)
  [[ "$output" =~ "session-bloat" ]]
  [[ "$output" =~ "elapsed=" ]]
}

# =============================================================================
# Case 7: token >= 50M → URGENT level warn が出る
# =============================================================================
@test "session-bloat: URGENT when token >= 50M" {
  local session_id="bats-test-urgent-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"
  rm -f "/tmp/claude_session_bloat_urgent_${session_id}_${date_today}"

  # tokens_per_assistant=6000000, msg_count=20 → assistant 10 件 → 60M total
  _make_session_jsonl "${session_id}" 3600 20 6000000 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "URGENT" ]]
  [[ "$output" =~ "token=60M" ]]
}

# =============================================================================
# Case 8: idle >= 30min → idle keyword 付きで warn が出る
# =============================================================================
@test "session-bloat: warn when idle >= 30min" {
  local session_id="bats-test-idle-$(date +%s)"
  local date_today
  date_today=$(date +%Y%m%d)

  rm -f "/tmp/claude_session_bloat_${session_id}_${date_today}"

  # session 60min 前開始、最終 user message は jsonl 末尾の最新 user 行
  # _make_session_jsonl は全 entry が同じ start_ts なので、idle は ~ elapsed と等しくなる
  # elapsed 3600s (= 60min idle) で elapsed 閾値 3h は未達、idle 30min は達成
  _make_session_jsonl "${session_id}" 3600 10 > /dev/null
  local cwd="${HOME}/testproject"
  local input
  input=$(printf '{"session_id":"%s","prompt":"hello","cwd":"%s"}' "${session_id}" "${cwd}")

  run bash -c "CLAUDE_CODE_SESSION_ID='${session_id}' JP_QUALITY_INJECT_OFF=1 CLAUDE_CTX_FILE='${HOME}/_ctx_unset' CLAUDE_SERENA_FAIL_COUNT='${HOME}/_serena_unset' bash '${HOOKS_DIR}/user-prompt-submit.sh' <<< '${input}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-bloat" ]]
  [[ "$output" =~ "idle=" ]]
}
