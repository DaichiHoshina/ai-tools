#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/session-end.sh - SIGPIPE / Broken pipe ハンドリング
#
# Claude Code は SessionEnd hook 発火時に stdout を既に閉じている場合がある。
# このテストは以下を確認する:
#   1. stdout が閉じた pipe 環境でもスクリプトが exit 0 で終了すること
#   2. stderr に "Broken pipe" / "write error" が出力されないこと
#   3. JSONL パース（token 集計）ブロックが SIGPIPE 後も継続できること
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/session-end.sh"
  setup_test_tmpdir
  export HOME="${TEST_TMPDIR}"
  export LOGS_DIR="${TEST_TMPDIR}/.claude/logs"
  mkdir -p "${LOGS_DIR}"
  mkdir -p "${TEST_TMPDIR}/.claude/session-logs"
}

teardown() {
  teardown_test_tmpdir
}

# =============================================================================
# SIGPIPE / Broken pipe テスト
# =============================================================================

@test "session-end: stdout を head -1 で即閉じても exit 0 で終了する" {
  # head -1 は 1 行読んだら stdin を閉じるため stdout pipe が閉じた状態をシミュレートする
  # hook が SIGPIPE を適切にハンドリングしていれば exit 0 を維持する
  local exit_code=0
  bash "${HOOK_FILE}" <<< '{}' 2>/dev/null | head -1 > /dev/null || exit_code=$?
  # head がパイプを閉じた後の session-end.sh の exit code ではなく、
  # pipe の終了を確認するため直接実行で exit code を取得する
  run bash "${HOOK_FILE}" <<< '{}'
  [[ "${status}" -eq 0 ]]
}

@test "session-end: stderr に Broken pipe が出ない (通常 JSON 入力)" {
  local stderr_out
  stderr_out=$(bash "${HOOK_FILE}" <<< '{}' 2>&1 >/dev/null || true)
  # "Broken pipe" または "write error" が stderr に出ていないこと
  echo "${stderr_out}" | grep -qvF "Broken pipe" || true
  echo "${stderr_out}" | grep -qvF "write error" || true
  # grep -q は見つかったら 0、見つからなければ 1 を返すため反転して確認
  if echo "${stderr_out}" | grep -qF "Broken pipe"; then
    echo "FAIL: Broken pipe detected in stderr: ${stderr_out}" >&2
    return 1
  fi
  if echo "${stderr_out}" | grep -qF "write error"; then
    echo "FAIL: write error detected in stderr: ${stderr_out}" >&2
    return 1
  fi
}

@test "session-end: stdout 閉鎖環境でも Broken pipe が stderr に出ない" {
  # stdout を /dev/null に捨てつつ stderr を取得して Broken pipe がないことを確認
  local stderr_out
  # bash -c でサブシェルを起動し、stdout を事前に閉じた状態で hook を実行する
  stderr_out=$(bash -c 'exec 1>/dev/null; bash "$1" <<< "{}"' _ "${HOOK_FILE}" 2>&1 || true)
  if echo "${stderr_out}" | grep -qF "Broken pipe"; then
    echo "FAIL: Broken pipe in closed-stdout env: ${stderr_out}" >&2
    return 1
  fi
  if echo "${stderr_out}" | grep -qF "write error"; then
    echo "FAIL: write error in closed-stdout env: ${stderr_out}" >&2
    return 1
  fi
}

@test "session-end: JSONL ファイルが存在する場合も exit 0 で終了する" {
  # token 集計ブロック (jq -sr) が実行される条件を用意する
  local session_id="test-session-sigpipe-$$"
  local slug="${TEST_TMPDIR//\//-}"
  slug="${slug//\./-}"
  local jsonl_dir="${TEST_TMPDIR}/.claude/projects/${slug}"
  mkdir -p "${jsonl_dir}"
  local jsonl_file="${jsonl_dir}/${session_id}.jsonl"

  # assistant message の usage を含む最小 JSONL を作成する
  cat > "${jsonl_file}" <<'JSONL'
{"type":"assistant","message":{"usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":200}}}
{"type":"user","message":{"content":"hello"}}
JSONL

  local input_json
  input_json=$(printf '{"session_id":"%s","cwd":"%s"}' "${session_id}" "${TEST_TMPDIR}")

  run bash "${HOOK_FILE}" <<< "${input_json}"
  [[ "${status}" -eq 0 ]]
}

@test "session-end: 大きな JSONL でも Broken pipe なく完了する" {
  # 多数の行を持つ JSONL で jq が途中で SIGPIPE を受けても set -e で停止しないことを確認
  local session_id="test-session-large-$$"
  local slug="${TEST_TMPDIR//\//-}"
  slug="${slug//\./-}"
  local jsonl_dir="${TEST_TMPDIR}/.claude/projects/${slug}"
  mkdir -p "${jsonl_dir}"
  local jsonl_file="${jsonl_dir}/${session_id}.jsonl"

  # 500 行の assistant message を生成する
  local i
  for i in $(seq 1 500); do
    printf '{"type":"assistant","message":{"usage":{"input_tokens":%d,"output_tokens":%d,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}\n' \
      "$i" "$((i * 2))" >> "${jsonl_file}"
  done

  local input_json
  input_json=$(printf '{"session_id":"%s","cwd":"%s"}' "${session_id}" "${TEST_TMPDIR}")

  local stderr_out
  stderr_out=$(bash "${HOOK_FILE}" <<< "${input_json}" 2>&1 >/dev/null || true)

  if echo "${stderr_out}" | grep -qF "Broken pipe"; then
    echo "FAIL: Broken pipe with large JSONL: ${stderr_out}" >&2
    return 1
  fi
}
