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
  # 2026-07-17 retrospective C: warn を「reply the next turn FIRST」の強い指示に格上げ
  [[ "$output" =~ "next turn with a /compact suggestion FIRST" ]]
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
# Case 1c (B1): msg >= 400 → [session-split-force] を注入 (warn 済でも独立発火)
# =============================================================================
@test "session-split-force: strong nudge at 400 msgs even after warn fired" {
  local session_id="split-force-$(date +%s%N | tail -c 6)"
  local cwd="${HOME}/testproject"

  # elapsed 10 分 / msg 410 (force threshold 超え)
  _make_session_jsonl "${session_id}" "${cwd}" 600 410 > /dev/null

  # warn は既に通知済の状態を作る (force が独立に出ることを検証)
  touch "${HOME}/.claude/logs/.session-split-warned-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    --arg cwd "${cwd}" \
    '{"session_id":$sid,"tool_name":"Read","tool_input":{"file_path":"/tmp/test.txt"},"cwd":$cwd}' \
    > "${input_file}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # 1 回目: force が出て state file が作成される
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-split-force" ]]
  # 2026-07-17 retrospective C: force を「即座に user へ提案 + この turn で新規 subtask 禁止」の明示に強化
  [[ "$output" =~ "この turn で新規 subtask に着手せず" ]]
  [ -f "${home_dir}/.claude/logs/.session-split-forced-${session_id}" ]

  # 2 回目: force が出ない (warn / force 両 state file 済 → skip)
  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "session-split-force" ]]
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
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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
# 2 回目逐次発火 (>30s 間隔 = window 外) で bundle-violation-warn を注入する
# =============================================================================
@test "bundle-violation: warn injected on 2nd sequential developer-agent fire" {
  local session_id="bundle-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=1 (1 発目 fire 済)、lastts 35 秒前 (>30s window) → 次の呼出しで counter=2 = threshold 到達
  printf '1\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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
# Case S1-D: 30 sec 以内の並列発火は warn を抑止 (counter は維持して累積保持)
# 旧実装は counter=0 リセットだったが「並列を 1 回挟むと sequential 検出永久リセット」
# bug があり、混合パターンを見逃していた。修正後は counter 維持 + warn 抑止のみ。
# window は 500ms から 30 sec に拡大 (2026-06-25 incident: Claude Code subagent spawn
# の overhead で 1 message 並列でも各 Agent 発火が 5-25 sec 間隔になる実測)。
# =============================================================================
@test "bundle-violation: warn suppressed on 1-message bundle (parallel fire)" {
  local session_id="bundle-parallel-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=5、lastts は 50ms 前 (30 sec 以内 → 並列 bundle 判定)
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

# =============================================================================
# Case S1-E: 3 回目逐次発火で hard block (exit 2) する
# 旧実装は warn fence (bundle-violation-warned-<id>) を先に check していたため
# 2 回目 warn 後の 3 回目が early return し threshold に到達しない bug があった。
# fix: counter++ / block check を fence check より前に移動。
# =============================================================================
@test "bundle-violation: hard block on 3rd sequential developer-agent fire (exit 2)" {
  local session_id="bundle-block-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=2 (warn 発火済)、warn fence 存在、lastts 2 秒前 → 次呼出しで counter=3 = hard block
  printf '2\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  touch "${log_dir}/.bundle-violation-warned-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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

  # hard block = exit 2
  [ "$status" -eq 2 ]
  # block log が生成されている (log 内容は "<timestamp> | <session_id> | dev_count=N | elapsed_ms=N" 形式)
  [ -f "${log_dir}/bundle-violation-block.log" ]
  grep -q "dev_count=3" "${log_dir}/bundle-violation-block.log"

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}" \
        "${log_dir}/.bundle-violation-warned-${session_id}" \
        "${log_dir}/.bundle-violation-blocked-${session_id}"
}

# =============================================================================
# Case S1-F: CLAUDE_BUNDLE_HARD_BLOCK=0 で hard block を opt-out できる
# =============================================================================
@test "bundle-violation: hard block opt-out via CLAUDE_BUNDLE_HARD_BLOCK=0" {
  local session_id="bundle-optout-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=2 (warn 発火済)、warn fence 存在
  printf '2\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  touch "${log_dir}/.bundle-violation-warned-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"impl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_BUNDLE_HARD_BLOCK=0 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  # opt-out → exit 0 (block しない)
  [ "$status" -eq 0 ]

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}" \
        "${log_dir}/.bundle-violation-warned-${session_id}" \
        "${log_dir}/.bundle-violation-blocked-${session_id}"
}

# =============================================================================
# Case S1-G: prompt に serial_reason: 宣言がある逐次発火は counter 対象外 (warn 抑止)
# 依存 chain (実装 → 修正) の正当な逐次発火を bundle 違反と誤検出しないため。
# =============================================================================
@test "bundle-violation: serial_reason declared prompt skips counter and warn" {
  local session_id="bundle-serial-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=1、lastts 35 秒前 (>30s window) → serial_reason なしなら counter=2 = warn
  printf '1\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"serial_reason: dev1 の patch 適用結果に依存する修正\nimpl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "bundle-violation-warn" ]]
  # counter は増えない (serial_reason fire は sequential 累積の対象外)
  local _post_count
  _post_count=$(cat "${log_dir}/.dev-agent-fire-count-${session_id}")
  [ "${_post_count}" = "1" ]
  # audit log に marker が残る
  grep -q "serial_reason_declared" "${log_dir}/bundle-violation-warn.log"

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}"
}

# =============================================================================
# Case S1-H: serial_reason 宣言は hard block 直前 (counter=2 / warn 済) でも block を回避する
# =============================================================================
@test "bundle-violation: serial_reason declared prompt bypasses hard block" {
  local session_id="bundle-serialblk-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter=2 (warn 発火済)、serial_reason なしなら次呼出しで counter=3 = hard block
  printf '2\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  touch "${log_dir}/.bundle-violation-warned-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
  printf '%s\n' "$_past_ns" > "${log_dir}/.dev-agent-fire-lastts-${session_id}"

  local input_file
  input_file=$(mktemp)
  jq -n \
    --arg sid "${session_id}" \
    '{"session_id":$sid,"tool_name":"Task","tool_input":{"subagent_type":"developer-agent","prompt":"serial_reason: reviewer の reject feedback を反映する再実装\nimpl task"},"cwd":"/tmp"}' \
    > "${input_file}"

  run bash -c "HOME='${home_dir}' CLAUDE_CODE_SESSION_ID='${session_id}' \
    JP_QUALITY_INJECT_OFF=1 \
    CLAUDE_CTX_FILE='${home_dir}/_ctx_unset' \
    '${hook}' < '${input_file}'"
  rm -f "${input_file}"

  # block されない (exit 0)、counter も 2 のまま
  [ "$status" -eq 0 ]
  local _post_count
  _post_count=$(cat "${log_dir}/.dev-agent-fire-count-${session_id}")
  [ "${_post_count}" = "2" ]

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}" \
        "${log_dir}/.bundle-violation-warned-${session_id}"
}

# =============================================================================
# Case S1-I: developer-agent 初回発火 (counter 新規 =1) で bundle-pre-check を先出し inject する
# warn (2 発目) 時点では 1 体目の直列実行時間を既に浪費しているため、
# 発火前の残 task 全列挙 + bundle 判断を初回に促す。
# =============================================================================
@test "bundle-violation: first developer-agent fire injects bundle-pre-check" {
  local session_id="bundle-first-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # counter / lastts なし = session 初回 fire
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}"

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
  [[ "$output" =~ "bundle-pre-check" ]]
  # 初回 fire は warn ではない
  [[ ! "$output" =~ "bundle-violation-warn" ]]

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}"
}

# =============================================================================
# Case S1-J: 直前 bundle が並列 (size>=2) なら新 bundle 開始でも counter 加算しない
# 正当な多段 batch (並列 bundle → merge → 並列 bundle) を hard block する
# false positive の regression test (2026-07-05 incident)。
# =============================================================================
@test "bundle-violation: no block when previous fire was a parallel bundle" {
  local session_id="bundle-multibatch-$(date +%s%N | tail -c 8)"
  local log_dir="${HOME}/.claude/logs"
  mkdir -p "${log_dir}"

  local hook="${HOOKS_DIR}/pre-tool-use.sh"
  local home_dir="${HOME}"

  # 並列 bundle のみの多段 batch session = 確定 solo 0。直前 bundle size=2 (並列)
  # なら今回の新 bundle 開始は counter 対象外 → 何 batch 重ねても block しない
  printf '0\n' > "${log_dir}/.dev-agent-fire-count-${session_id}"
  printf '2\n' > "${log_dir}/.dev-agent-fire-bundlesize-${session_id}"
  touch "${log_dir}/.bundle-violation-warned-${session_id}"
  local _past_ns
  _past_ns=$(( $(date +%s%N) - 35000000000 ))
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
  [[ ! "$output" =~ "bundle-violation-block" ]]
  # counter は据え置き (並列 bundle 直後の新 bundle は solo 未確定)
  local _post_count
  _post_count=$(cat "${log_dir}/.dev-agent-fire-count-${session_id}")
  [ "${_post_count}" = "0" ]

  # cleanup
  rm -f "${log_dir}/.dev-agent-fire-count-${session_id}" \
        "${log_dir}/.dev-agent-fire-lastts-${session_id}" \
        "${log_dir}/.dev-agent-fire-bundlesize-${session_id}" \
        "${log_dir}/.bundle-violation-warned-${session_id}"
}
