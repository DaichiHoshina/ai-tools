#!/usr/bin/env bats
# sleep-proposal-check.sh: schema 検証 gate の exit code を検証する。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  SCRIPT="${PROJECT_ROOT}/scripts/sleep-proposal-check.sh"
  export SCRIPT
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}"
  REPO="${TEST_DIR}/repo"
  export REPO
  mkdir -p "${REPO}/claude-code/skills"
  touch "${REPO}/claude-code/skills/existing.md"
  FILE="${TEST_DIR}/proposals.md"
  export FILE
}

teardown() {
  rm -rf "${TEST_DIR}"
}

_valid_block() {
  cat <<'EOF'
### P1: test proposal

- Type: skill-edit
- Target: claude-code/skills/existing.md
- Evidence: tool X の失敗が 12 回あった
- Change: skill に guard を足す。
- Risk: 誤検知の可能性がある。
EOF
}

@test "check: 正常な proposal は exit 0" {
  _valid_block > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK: 1 proposals" ]]
}

@test "check: NO-PROPOSAL 行があれば exit 3" {
  echo "NO-PROPOSAL: 有意な signal がない" > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 3 ]
}

@test "check: block ゼロかつ NO-PROPOSAL なしは exit 1" {
  echo "# empty" > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
}

@test "check: Type が enum 外なら exit 1" {
  _valid_block | sed 's/Type: skill-edit/Type: banana/' > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Type" ]]
}

@test "check: Evidence に数値がなければ exit 1" {
  _valid_block | sed 's/^- Evidence: .*/- Evidence: なんとなく多い/' > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Evidence" ]]
}

@test "check: skill-edit の Target が実在しなければ exit 1" {
  _valid_block | sed 's|Target: claude-code/skills/existing.md|Target: claude-code/skills/ghost.md|' > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "実在しない" ]]
}

@test "check: 6 件以上の proposal は exit 1" {
  : > "${FILE}"
  for i in 1 2 3 4 5 6; do
    _valid_block | sed "s/P1:/P${i}:/" >> "${FILE}"
  done
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "5 件を超える" ]]
}

@test "check: private term を含むと exit 1" {
  mkdir -p "${HOME}/.claude/references-private"
  echo "secretcorp" > "${HOME}/.claude/references-private/private-name-list.txt"
  _valid_block | sed 's/test proposal/secretcorp 対応/' > "${FILE}"
  run bash "${SCRIPT}" "${FILE}" --repo "${REPO}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "private term" ]]
}
