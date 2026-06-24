#!/usr/bin/env bats
# =============================================================================
# cost-warn-hooks: session-split-warn / delegation-suggest の bats tests
# B1: _check_session_split - session age >= 3h or msg >= 1000 で warn 注入
# B2: _check_large_repo_consecutive_edit - large-repo src 5 回連続 Edit で warn 注入
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  # shellcheck source=../helpers/common.bash
  load "../helpers/common"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  export ORIG_HOME="$HOME"
  # テスト用 HOME (本番ファイルを汚染しない)
  export HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude/logs"
  mkdir -p "${HOME}/.claude/projects"
  # hook の副作用を抑制する環境変数
  export JP_QUALITY_INJECT_OFF=1
  export CLAUDE_CTX_FILE="${HOME}/_ctx_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${HOME}/_serena_unset"
  # threshold 定数をロード
  # shellcheck source=../../hooks/lib/thresholds.sh
  source "${BATS_TEST_DIRNAME}/../../hooks/lib/thresholds.sh"
}

teardown() {
  if [[ "${HOME}" != "${ORIG_HOME}" && "${HOME}" == /tmp/* ]]; then
    rm -rf "${HOME}"
  fi
  export HOME="${ORIG_HOME}"
}

# ヘルパー: fake session jsonl を生成する
# 引数: $1=session_id, $2=cwd, $3=elapsed_seconds, $4=msg_count
_make_session_jsonl() {
  local session_id="$1"
  local cwd="$2"
  local elapsed_seconds="$3"
  local msg_count="$4"

  local slug="${cwd//\//-}"
  slug="${slug//\./-}"
  local dir="${HOME}/.claude/projects/${slug}"
  mkdir -p "${dir}"
  local jsonl="${dir}/${session_id}.jsonl"

  local start_epoch=$(( EPOCHSECONDS - elapsed_seconds ))
  local start_ts
  # UTC で生成 (parser 側 _resolve_session_jsonl_epoch が TZ=UTC で解釈するため)
  start_ts=$(date -u -r "${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null \
    || date -u -d "@${start_epoch}" "+%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null)

  printf '{"type":"attachment","timestamp":"%s"}\n' "${start_ts}" > "${jsonl}"
  local i
  for (( i=0; i<msg_count; i++ )); do
    if (( i % 2 == 0 )); then
      printf '{"type":"user","timestamp":"%s"}\n' "${start_ts}"
    else
      printf '{"type":"assistant","timestamp":"%s"}\n' "${start_ts}"
    fi
  done >> "${jsonl}"

  echo "${jsonl}"
}

# =============================================================================
# Case 1 (B1): session age 4h → additionalContext に [session-split-warn] を含む
# =============================================================================
@test "session-split-warn: warn when session age > 3h" {
  local session_id="split-warn-age-$(date +%s%N | tail -c 6)"
  local cwd="${HOME}/testproject"

  # elapsed 4h = 14400s, msg 50 (age のみで threshold 超え)
  _make_session_jsonl "${session_id}" "${cwd}" 14400 50 > /dev/null

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    --arg cwd "${cwd}" \
    '{"session_id":$sid,"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"},"cwd":$cwd}' \
    > "${input_file}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-split-warn" ]]
}

# =============================================================================
# Case 1b (B1): 2 回目呼出しは state file で warn が抑制される
# =============================================================================
@test "session-split-warn: 2nd invocation is suppressed by state file" {
  local session_id="split-warn-dup-$(date +%s%N | tail -c 6)"
  local cwd="${HOME}/testproject"

  _make_session_jsonl "${session_id}" "${cwd}" 14400 50 > /dev/null

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    --arg cwd "${cwd}" \
    '{"session_id":$sid,"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"},"cwd":$cwd}' \
    > "${input_file}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # 1 回目: warn が出て state file が作成される
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-split-warn" ]]

  # state file が存在することを確認
  [ -f "${home_dir}/.claude/logs/.session-split-warned-${session_id}" ]

  # 2 回目: warn が出ない
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "session-split-warn" ]]
}

# =============================================================================
# Case 2 (B2): large-repo src 3 回連続 Edit → additionalContext に [delegation-suggest] を含む
# =============================================================================
@test "delegation-suggest: warn after 3 consecutive large-repo edits" {
  local session_id="deleg-warn-$(date +%s%N | tail -c 6)"
  local _org="snkr"; local _suffix="dunk"
  local target_file="${HOME}/ghq/github.com/${_org}${_suffix}/src/main.go"
  local log_dir="${HOME}/.claude/logs"

  # counter を threshold-1 にセット (次の呼出しで threshold 到達、speed-bias)
  mkdir -p "${log_dir}"
  printf '%s\n' "$(( _TH_DELEGATE_SEQ - 1 ))" > "${log_dir}/.large-repo-edit-count-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    --arg fp "${target_file}" \
    '{"session_id":$sid,"tool_name":"Edit","tool_input":{"file_path":$fp,"old_string":"a","new_string":"b"},"cwd":"/tmp"}' \
    > "${input_file}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "delegation-suggest" ]]
}

# =============================================================================
# Case 3 (B3): OSS path (~/ghq/github.com/some-oss-org/oss-repo/) では warn しない
# =============================================================================
@test "delegation-suggest: no warn for OSS path outside large-repo prefix" {
  local session_id="deleg-oss-$(date +%s%N | tail -c 6)"
  local target_file="${HOME}/ghq/github.com/some-oss-org/oss-repo/main.go"
  local log_dir="${HOME}/.claude/logs"

  # counter を threshold-1 にセット (threshold 直前)
  mkdir -p "${log_dir}"
  printf '%s\n' "$(( _TH_DELEGATE_SEQ - 1 ))" > "${log_dir}/.large-repo-edit-count-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    --arg fp "${target_file}" \
    '{"session_id":$sid,"tool_name":"Edit","tool_input":{"file_path":$fp,"old_string":"a","new_string":"b"},"cwd":"/tmp"}' \
    > "${input_file}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "delegation-suggest" ]]
}

# =============================================================================
# Case S1-A: sequential 2 連続 Task fire で parallel-fire-suggest を注入する (speed-bias threshold)
# 異なる session として 2 回 hook を逐次呼出し (間隔 > 100ms を timestamp 操作で模擬)
# =============================================================================
@test "sequential-agent-fire: warn injected after 2 sequential Task fires" {
  local session_id="seqfire-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=threshold-1、lastts を 1 秒前 (十分 > 100ms) に偽装 → 次の呼出しで threshold 到達
  printf '%s\n' "$(( _TH_PARALLEL_SEQ - 1 ))" > "${log_dir}/.agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 2000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"test task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "parallel-fire-suggest" ]]
}

# =============================================================================
# Case S1-B: fence 存在時は 2 回目以降の sequential fire で warn をスキップする
# =============================================================================
@test "sequential-agent-fire: no duplicate warn when fence exists" {
  local session_id="seqfire-fence-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # fence を先に作成 (warn 済フラグ)
  touch "${log_dir}/.sequential-fire-warned-${session_id}"
  # counter=5、lastts を 1 秒前に偽装 (sequential 条件を満たす)
  printf '5\n' > "${log_dir}/.agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 2000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"test task again"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "parallel-fire-suggest" ]]
}

# =============================================================================
# Case S1-C: developer-agent 限定 bundle 違反 warn (work-context-20260618 F1)
# 2 回目逐次発火 (>500ms 間隔) で bundle-violation-warn を注入する
# =============================================================================
@test "bundle-violation: warn injected on 2nd sequential developer-agent fire" {
  local session_id="bundle-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=1 (1 発目 fire 済)、lastts 1 秒前 → 次の呼出しで counter=2 = threshold 到達
  printf '1\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 2000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"impl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "bundle-violation-warn" ]]
}

# =============================================================================
# Case S1-C2: tool_name="Agent" (2.1.152+ rename) でも同じ bundle warn が発火する
# 旧 hook は "Task" のみ listen して "Agent" を空振りしていた (全 session 検出漏れ)
# =============================================================================
@test "bundle-violation: warn injected for tool_name='Agent' (rename of Task)" {
  local session_id="bundle-agent-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  printf '1\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 2000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Agent","tool_input":{"subagent_type":"developer-agent","prompt":"impl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" =~ "bundle-violation-warn" ]]
}

# =============================================================================
# Case S1-D: 500ms 以内の並列発火は warn を抑止 (counter は維持して累積保持)
# 旧実装は counter=0 リセットだったが「並列を 1 回挟むと sequential 検出永久リセット」
# bug があり、混合パターンを見逃していた。修正後は counter 維持 + warn 抑止のみ。
# =============================================================================
@test "bundle-violation: warn suppressed on 1-message bundle (parallel fire)" {
  local session_id="bundle-parallel-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=5、lastts は 50ms 前 (500ms 以内 → 並列 bundle 判定)
  printf '5\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  local _recent_ns
  _recent_ns=$(( $(date +%s%N) - 50000000 ))
  printf '%s\n' "$_recent_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"impl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "bundle-violation-warn" ]]
  # counter は維持 (リセットされない) — 累積 sequential 検出のため
  local _post_count
  _post_count=$(cat "${log_dir}/.dev-agent-fire-count-${session_id}")
  [ "${_post_count}" = "5" ]
}
