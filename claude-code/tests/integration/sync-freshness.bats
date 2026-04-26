#!/usr/bin/env bats
# =============================================================================
# Tests for sync.sh check_repo_freshness function
# race condition 対策（push 直後の sync が古い workspace を反映する事故）の回帰防止
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export TEST_TMPDIR="${BATS_TMPDIR}/sync-freshness-${RANDOM}-$$"
  mkdir -p "${TEST_TMPDIR}"

  CHECK_FUNC=$(sed -n '/^check_repo_freshness()/,/^}$/p' "${PROJECT_ROOT}/claude-code/sync.sh")
  export CHECK_FUNC
}

teardown() {
  if [[ -n "${TEST_TMPDIR}" && -d "${TEST_TMPDIR}" ]]; then
    rm -rf "${TEST_TMPDIR}"
  fi
}

# 関数を抽出して指定 SCRIPT_DIR で実行する helper
run_check() {
  local script_dir="$1"
  run bash -c "
    SCRIPT_DIR='${script_dir}'
    source '${PROJECT_ROOT}/claude-code/lib/print-functions.sh'
    ${CHECK_FUNC}
    check_repo_freshness
  "
}

# テスト用の独立 git repo + upstream を構築
setup_repo_with_upstream() {
  local upstream="${TEST_TMPDIR}/upstream.git"
  local clone="${TEST_TMPDIR}/clone"

  git init --bare --initial-branch=main "${upstream}" >/dev/null 2>&1
  git clone "${upstream}" "${clone}" >/dev/null 2>&1

  pushd "${clone}" >/dev/null
  git config user.email "test@example.com"
  git config user.name "test"
  echo "initial" > a.txt
  git add a.txt
  git commit -m "init" >/dev/null
  git push -u origin main >/dev/null 2>&1
  popd >/dev/null

  echo "${clone}"
}

# =============================================================================
# Skip cases: 0 を返して abort しない
# =============================================================================

@test "check_repo_freshness: returns 0 when SCRIPT_DIR is not a git repo" {
  run_check "${TEST_TMPDIR}/no-git-here/sub"
  [ "${status}" -eq 0 ]
}

@test "check_repo_freshness: returns 0 when upstream is not configured" {
  local repo="${TEST_TMPDIR}/no-upstream"
  git init --initial-branch=main "${repo}" >/dev/null 2>&1
  pushd "${repo}" >/dev/null
  git config user.email "test@example.com"
  git config user.name "test"
  echo "x" > a.txt
  git add a.txt
  git commit -m "init" >/dev/null
  popd >/dev/null

  # SCRIPT_DIR は repo 内のサブパス（sync.sh 実環境と同じく "${SCRIPT_DIR}/.." が repo root になる構造）
  mkdir -p "${repo}/sub"
  run_check "${repo}/sub"
  [ "${status}" -eq 0 ]
}

@test "check_repo_freshness: returns 0 when fetch fails (offline simulated)" {
  local repo="${TEST_TMPDIR}/bad-upstream"
  git init --initial-branch=main "${repo}" >/dev/null 2>&1
  pushd "${repo}" >/dev/null
  git config user.email "test@example.com"
  git config user.name "test"
  echo "x" > a.txt
  git add a.txt
  git commit -m "init" >/dev/null
  # 到達不能な upstream
  git remote add origin "${TEST_TMPDIR}/nonexistent.git"
  git update-ref refs/remotes/origin/main HEAD
  git branch --set-upstream-to=origin/main >/dev/null 2>&1
  popd >/dev/null

  mkdir -p "${repo}/sub"
  run_check "${repo}/sub"
  [ "${status}" -eq 0 ]
}

# =============================================================================
# Detect case: 未取り込みコミットあり → 1 + 警告
# =============================================================================

@test "check_repo_freshness: returns 1 when behind upstream" {
  local clone
  clone=$(setup_repo_with_upstream)
  local upstream="${TEST_TMPDIR}/upstream.git"

  # 別 clone で upstream を進める（race 状態を再現）
  local advance="${TEST_TMPDIR}/advance"
  git clone "${upstream}" "${advance}" >/dev/null 2>&1
  pushd "${advance}" >/dev/null
  git config user.email "test@example.com"
  git config user.name "test"
  echo "second" > b.txt
  git add b.txt
  git commit -m "advance" >/dev/null
  git push origin main >/dev/null 2>&1
  popd >/dev/null

  mkdir -p "${clone}/sub"
  run_check "${clone}/sub"
  [ "${status}" -eq 1 ]
  [[ "${output}" =~ "未取り込み" ]]
}

@test "check_repo_freshness: returns 0 when up to date with upstream" {
  local clone
  clone=$(setup_repo_with_upstream)

  mkdir -p "${clone}/sub"
  run_check "${clone}/sub"
  [ "${status}" -eq 0 ]
}

# =============================================================================
# Integration: --skip-git-check フラグが check を抑制する
# =============================================================================

@test "sync.sh: --skip-git-check flag is documented in usage" {
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" invalid-mode
  [ "${status}" -eq 1 ]
  [[ "${output}" =~ "--skip-git-check" ]]
}
