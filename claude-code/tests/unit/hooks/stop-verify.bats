#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/stop-verify.sh
# opt-in smoke test gate: STOP_VERIFY_ENFORCE=1 で bats を起動し、
# FAIL 時に decision:block を出力する。
# =============================================================================

FIXTURE_DIR=""

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/stop-verify.sh"
  setup_test_tmpdir

  # HOME を差し替えてログ出力を分離
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${TEST_TMPDIR}/.claude/logs"

  # fixture dir (mock bats を PATH 先頭に置く方式)
  FIXTURE_DIR="${PROJECT_ROOT}/tests/fixtures/stop-verify"

  # テスト用 git repo を TEST_TMPDIR 配下に作成
  export FAKE_REPO="${TEST_TMPDIR}/repo"
  mkdir -p "${FAKE_REPO}"
  git -C "${FAKE_REPO}" init -q
  git -C "${FAKE_REPO}" config user.email "test@example.com"
  git -C "${FAKE_REPO}" config user.name "Test"
}

teardown() {
  teardown_test_tmpdir
}

# helper: stdin JSON を hook に渡し stdout 全体を返す
_run_hook() {
  local json="$1"
  printf '%s' "${json}" | bash "${HOOK_FILE}" 2>/dev/null
}

# helper: git repo に commit を積む
_commit_file() {
  local repo="$1" fname="$2" content="${3:-x}"
  printf '%s' "${content}" > "${repo}/${fname}"
  git -C "${repo}" add "${fname}"
  git -C "${repo}" commit -q -m "add ${fname}"
}

# =============================================================================
# 1. env 未設定 / 0 → 即 exit 0、JSON 無し
# =============================================================================

@test "stop-verify: STOP_VERIFY_ENFORCE 未設定なら即 exit 0" {
  unset STOP_VERIFY_ENFORCE
  out=$(_run_hook '{"cwd":"/tmp"}')
  [[ -z "${out}" ]]
}

@test "stop-verify: STOP_VERIFY_ENFORCE=0 なら即 exit 0" {
  out=$(STOP_VERIFY_ENFORCE=0 _run_hook '{"cwd":"/tmp"}')
  [[ -z "${out}" ]]
}

# =============================================================================
# 2. cwd 不在 / git repo でない → graceful exit 0
# =============================================================================

@test "stop-verify: cwd フィールド不在なら graceful exit 0" {
  out=$(STOP_VERIFY_ENFORCE=1 _run_hook '{}')
  [[ -z "${out}" ]]
}

@test "stop-verify: cwd が git repo でないなら graceful exit 0" {
  out=$(STOP_VERIFY_ENFORCE=1 _run_hook "{\"cwd\":\"${TEST_TMPDIR}\"}")
  [[ -z "${out}" ]]
}

# =============================================================================
# 3. 変更 file が .md のみ → skip exit 0
# =============================================================================

@test "stop-verify: .md のみ変更なら skip exit 0 (decision なし)" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "README.md" "# doc"
  out=$(STOP_VERIFY_ENFORCE=1 _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  [[ -z "${out}" ]]
}

@test "stop-verify: .yml のみ変更なら skip exit 0" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "config.yml" "key: val"
  out=$(STOP_VERIFY_ENFORCE=1 _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  [[ -z "${out}" ]]
}

# =============================================================================
# 4. .sh 変更 + bats pass → exit 0、block JSON 無し
# =============================================================================

@test "stop-verify: .sh 変更 + bats pass → exit 0、block JSON 無し" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "hook.sh" "#!/bin/bash\necho ok"

  # bats-pass を PATH 先頭の "bats" として注入、テスト dir も注入
  local mock_bin="${TEST_TMPDIR}/bin"
  local fake_test_dir="${TEST_TMPDIR}/bats_tests"
  mkdir -p "${mock_bin}" "${fake_test_dir}"
  cp "${FIXTURE_DIR}/bats-pass" "${mock_bin}/bats"

  out=$(PATH="${mock_bin}:${PATH}" STOP_VERIFY_ENFORCE=1 STOP_VERIFY_TEST_DIRS="${fake_test_dir}" \
    _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  [[ -z "${out}" ]]
}

# =============================================================================
# 5. .sh 変更 + bats FAIL → decision:block JSON + reason にテスト名
# =============================================================================

@test "stop-verify: .sh 変更 + bats FAIL → decision:block JSON を出力" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "hook.sh" "#!/bin/bash\necho fail"

  local mock_bin="${TEST_TMPDIR}/bin"
  local fake_test_dir="${TEST_TMPDIR}/bats_tests"
  mkdir -p "${mock_bin}" "${fake_test_dir}"
  cp "${FIXTURE_DIR}/bats-fail" "${mock_bin}/bats"

  out=$(PATH="${mock_bin}:${PATH}" STOP_VERIFY_ENFORCE=1 STOP_VERIFY_TEST_DIRS="${fake_test_dir}" \
    _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  decision=$(printf '%s' "${out}" | jq -r '.decision // ""')
  [[ "${decision}" == "block" ]]
}

@test "stop-verify: block JSON の reason にテスト名が含まれる" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "hook.sh" "#!/bin/bash"

  local mock_bin="${TEST_TMPDIR}/bin"
  local fake_test_dir="${TEST_TMPDIR}/bats_tests"
  mkdir -p "${mock_bin}" "${fake_test_dir}"
  cp "${FIXTURE_DIR}/bats-fail" "${mock_bin}/bats"

  out=$(PATH="${mock_bin}:${PATH}" STOP_VERIFY_ENFORCE=1 STOP_VERIFY_TEST_DIRS="${fake_test_dir}" \
    _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  reason=$(printf '%s' "${out}" | jq -r '.reason // ""')
  [[ "${reason}" == *"stop-verify: .sh syntax check"* ]]
}

# =============================================================================
# 6. bats 不在 → graceful skip (block しない)
# =============================================================================

@test "stop-verify: bats 不在なら graceful skip (block JSON 無し)" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "hook.sh" "#!/bin/bash"

  # bats のみ見えない: PATH 先頭に空ディレクトリを追加し、かつ bats という名の空ディレクトリ (非実行可能) を置く
  local no_bats_bin="${TEST_TMPDIR}/no_bats_bin"
  mkdir -p "${no_bats_bin}"
  # bats という名のディレクトリを置くと command -v bats が失敗する
  mkdir -p "${no_bats_bin}/bats"
  local fake_test_dir="${TEST_TMPDIR}/bats_tests"
  mkdir -p "${fake_test_dir}"

  out=$(PATH="${no_bats_bin}:${PATH}" STOP_VERIFY_ENFORCE=1 STOP_VERIFY_TEST_DIRS="${fake_test_dir}" \
    _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  [[ -z "${out}" ]]
}

# =============================================================================
# 7. ログ file が追記される
# =============================================================================

@test "stop-verify: env=0 でもログは書かれない (early exit)" {
  out=$(STOP_VERIFY_ENFORCE=0 _run_hook '{"cwd":"/tmp"}')
  # early exit なのでログ file は作られない (または空)
  log="${HOME}/.claude/logs/stop-verify.log"
  if [[ -f "${log}" ]]; then
    count=$(wc -l < "${log}")
    [[ "${count}" -eq 0 ]]
  fi
}

@test "stop-verify: skip 時にログ 1 行が追記される" {
  _commit_file "${FAKE_REPO}" "init.sh" "#!/bin/bash"
  _commit_file "${FAKE_REPO}" "README.md" "# doc"

  STOP_VERIFY_ENFORCE=1 _run_hook "{\"cwd\":\"${FAKE_REPO}\"}" >/dev/null || true
  log="${HOME}/.claude/logs/stop-verify.log"
  [[ -f "${log}" ]]
  count=$(wc -l < "${log}")
  [[ "${count}" -ge 1 ]]
}

# =============================================================================
# 8. shallow history: HEAD~1 不在時の --cached fallback
# =============================================================================

@test "stop-verify: 初回 commit (HEAD~1 不在) でも graceful動作" {
  # repo に 1 commit だけ (HEAD~1 は存在しない)
  _commit_file "${FAKE_REPO}" "hook.sh" "#!/bin/bash"

  local mock_bin="${TEST_TMPDIR}/bin"
  mkdir -p "${mock_bin}"
  cp "${FIXTURE_DIR}/bats-pass" "${mock_bin}/bats"

  # staged なし → skip or pass のどちらでも block しないことを確認
  out=$(PATH="${mock_bin}:${PATH}" STOP_VERIFY_ENFORCE=1 _run_hook "{\"cwd\":\"${FAKE_REPO}\"}")
  decision=$(printf '%s' "${out}" | jq -r '.decision // "PASS"')
  [[ "${decision}" != "block" ]]
}
