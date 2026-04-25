#!/usr/bin/env bats
# =============================================================================
# Integration Tests for scripts/skill-lint.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LINTER="${PROJECT_ROOT}/claude-code/scripts/skill-lint.sh"
  export FIXTURE_DIR="${BATS_TMPDIR}/skill-lint-fixture-${RANDOM}"
  mkdir -p "$FIXTURE_DIR"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# =============================================================================
# Basics
# =============================================================================

@test "skill-lint.sh: has valid bash syntax" {
  run bash -n "$LINTER"
  [ "$status" -eq 0 ]
}

@test "skill-lint.sh: is executable" {
  [ -x "$LINTER" ]
}

@test "skill-lint.sh: --help exits 0" {
  run "$LINTER" --help
  [ "$status" -eq 0 ]
}

# =============================================================================
# Real-skills run
# =============================================================================

@test "skill-lint.sh: runs against all real skills without errors" {
  run "$LINTER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total: "* ]]
  [[ "$output" == *"Error: 0"* ]]
}

@test "skill-lint.sh: --skill targets a single skill" {
  run "$LINTER" --skill comprehensive-review
  [ "$status" -eq 0 ]
  [[ "$output" == *"comprehensive-review"* ]]
  [[ "$output" == *"Total: 1"* ]]
}

@test "skill-lint.sh: --skill on missing skill exits 2" {
  run "$LINTER" --skill __no_such_skill__
  [ "$status" -eq 2 ]
}

# =============================================================================
# Detection: missing fields
# =============================================================================

@test "skill-lint.sh: detects missing name (via custom skills dir)" {
  # 一時的なスキルセットを作成し、SKILLS_DIR を上書きするため、
  # スクリプト本体を読み込まず、一時 PROJECT_ROOT を使うラッパーを使う。
  local fake_root="${FIXTURE_DIR}/fake_root"
  mkdir -p "$fake_root/claude-code/skills/badskill" "$fake_root/claude-code/lib"
  cp "$PROJECT_ROOT/claude-code/lib/print-functions.sh" "$fake_root/claude-code/lib/"
  cp "$PROJECT_ROOT/claude-code/lib/colors.sh" "$fake_root/claude-code/lib/"
  cp -r "$PROJECT_ROOT/claude-code/scripts" "$fake_root/claude-code/scripts"

  cat > "$fake_root/claude-code/skills/badskill/SKILL.md" <<EOF
---
description: missing name field
---
# bad
EOF

  run "$fake_root/claude-code/scripts/skill-lint.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'name' field"* ]]
}
