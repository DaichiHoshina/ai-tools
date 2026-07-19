#!/usr/bin/env bats
# sleep-cron-run.sh: claude を stub 化し、staging / reject / idempotency を検証する。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SCRIPT="${PROJECT_ROOT}/scripts/sleep-cron-run.sh"
  export SCRIPT
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}"
  export SLEEP_STATE_DIR="${TEST_DIR}/sleep-state"

  REPO="${TEST_DIR}/repo"
  export REPO
  mkdir -p "${REPO}/memory"
  git -C "${REPO}" init -q
  git -C "${REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  echo "/memory/" > "${REPO}/.gitignore"
  git -C "${REPO}" add .gitignore
  git -C "${REPO}" -c user.email=t@t -c user.name=t commit -q -m gitignore

  export TODAY="$(date '+%F')"
  export STAGE_FILE="${REPO}/memory/sleep-proposals-${TODAY}.md"

  # harvest を軽量 stub に差し替える (sqlite / jq 依存を切る)
  export SLEEP_ANALYTICS_DB="${TEST_DIR}/none.db"
  export SLEEP_HISTORY_JSONL="${TEST_DIR}/none.jsonl"
  export SLEEP_LOG_DIR="${TEST_DIR}/logs"
  export SLEEP_SKILL_EVAL="${TEST_DIR}/none.sh"

  TEST_BIN="${TEST_DIR}/bin"
  mkdir -p "${TEST_BIN}"
  export TEST_BIN
  export CLAUDE_BIN="${TEST_BIN}/claude"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

# maker 呼び出しで proposal を書き、checker 呼び出しで APPROVE を返す stub
_stub_claude_ok() {
  cat > "${CLAUDE_BIN}" <<EOF
#!/usr/bin/env bash
input=\$(cat)
if grep -q 'independent reviewer' <<< "\${input}"; then
  echo '{"result": "VERDICT: APPROVE", "total_cost_usd": 0.01}'
else
  cat > "${STAGE_FILE}" <<'PROP'
### P1: stub proposal

- Type: claude-md
- Target: CLAUDE.md
- Evidence: Bash の失敗が 42 回あった
- Change: guard を足す。
- Risk: 特になし。
PROP
  echo '{"result": "done", "total_cost_usd": 0.05}'
fi
EOF
  chmod +x "${CLAUDE_BIN}"
}

_stub_claude_reject() {
  cat > "${CLAUDE_BIN}" <<EOF
#!/usr/bin/env bash
input=\$(cat)
if grep -q 'independent reviewer' <<< "\${input}"; then
  echo '{"result": "VERDICT: REJECT evidence が digest にない", "total_cost_usd": 0.01}'
else
  cat > "${STAGE_FILE}" <<'PROP'
### P1: stub proposal

- Type: claude-md
- Target: CLAUDE.md
- Evidence: Bash の失敗が 42 回あった
- Change: guard を足す。
- Risk: 特になし。
PROP
  echo '{"result": "done", "total_cost_usd": 0.05}'
fi
EOF
  chmod +x "${CLAUDE_BIN}"
}

@test "run: claude なしは exit 2" {
  run env CLAUDE_BIN="" PATH="/usr/bin:/bin" bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 2 ]
}

@test "run: 両 gate green で staged + Status: done" {
  _stub_claude_ok
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [ -f "${STAGE_FILE}" ]
  grep -q '^- Status: done' "${SLEEP_STATE_DIR}/state.md"
  grep -q 'STAGED' "${SLEEP_STATE_DIR}/state.md"
}

@test "run: checker REJECT で rejected rename + exit 4" {
  _stub_claude_reject
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 4 ]
  [ ! -f "${STAGE_FILE}" ]
  [ -f "${REPO}/memory/sleep-proposals-${TODAY}.rejected.md" ]
  grep -q 'VERDICT: REJECT' "${REPO}/memory/sleep-proposals-${TODAY}.rejected.md"
}

@test "run: NO-PROPOSAL は exit 3 で rejected へ" {
  cat > "${CLAUDE_BIN}" <<EOF
#!/usr/bin/env bash
cat > /dev/null
printf 'NO-PROPOSAL: signal なし\n' > "${STAGE_FILE}"
echo '{"result": "done", "total_cost_usd": 0.01}'
EOF
  chmod +x "${CLAUDE_BIN}"
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 3 ]
  [ -f "${REPO}/memory/sleep-proposals-${TODAY}.rejected.md" ]
}

@test "run: 当日分が既存なら idempotent skip (exit 0、claude 不要)" {
  echo x > "${STAGE_FILE}"
  run env CLAUDE_BIN="/bin/true" bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "idempotent" ]]
}

@test "run: staged 3 件滞留で mine skip (exit 0)" {
  echo x > "${REPO}/memory/sleep-proposals-2026-01-01.md"
  echo x > "${REPO}/memory/sleep-proposals-2026-01-02.md"
  echo x > "${REPO}/memory/sleep-proposals-2026-01-03.md"
  run env CLAUDE_BIN="/bin/true" bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sleep-review" ]]
}

@test "run: maker が tracked file を変更したら restore + exit 4 + warn flag" {
  cat > "${CLAUDE_BIN}" <<EOF
#!/usr/bin/env bash
input=\$(cat)
echo tampered >> "${REPO}/.gitignore"
cat > "${STAGE_FILE}" <<'PROP'
### P1: stub proposal

- Type: claude-md
- Target: CLAUDE.md
- Evidence: 42 回
- Change: x。
- Risk: y。
PROP
echo '{"result": "done", "total_cost_usd": 0.05}'
EOF
  chmod +x "${CLAUDE_BIN}"
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 4 ]
  run git -C "${REPO}" status --porcelain
  [ -z "$output" ]
  [ -f "${SLEEP_STATE_DIR}/tracked-change-warn" ]
}

@test "run: --dry-run は prompt を表示して claude を呼ばない" {
  run env CLAUDE_BIN="/bin/true" bash "${SCRIPT}" --repo "${REPO}" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sleep plan (dry-run)" ]]
  [[ "$output" =~ "Harvest digest" ]]
}
