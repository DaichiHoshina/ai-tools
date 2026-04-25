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

# Fixture 用の最小 PROJECT_ROOT を構築し、そこから skill-lint.sh を起動する
# Usage: setup_fake_root SKILL_NAME SKILL_MD_FILENAME SKILL_BODY
setup_fake_root() {
  local skill="$1"
  local filename="$2"
  local body="$3"
  local fake_root="${FIXTURE_DIR}/fake_root"

  mkdir -p "$fake_root/claude-code/skills/$skill" \
           "$fake_root/claude-code/lib" \
           "$fake_root/claude-code/scripts"
  cp "$PROJECT_ROOT/claude-code/lib/print-functions.sh" "$fake_root/claude-code/lib/"
  cp "$PROJECT_ROOT/claude-code/lib/colors.sh" "$fake_root/claude-code/lib/"
  cp "$PROJECT_ROOT/claude-code/scripts/skill-lint.sh" "$fake_root/claude-code/scripts/"
  printf '%s' "$body" > "$fake_root/claude-code/skills/$skill/$filename"
  echo "$fake_root/claude-code/scripts/skill-lint.sh"
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

@test "skill-lint.sh: --help exits 0 and prints usage" {
  run "$LINTER" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "skill-lint.sh: unknown option exits 2" {
  run "$LINTER" --no-such-option
  [ "$status" -eq 2 ]
}

@test "skill-lint.sh: --skill without argument exits 2" {
  run "$LINTER" --skill
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires an argument"* ]]
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
# Filename casing (skill.md / SKILL.md 両対応)
# =============================================================================

@test "skill-lint.sh: recognizes lowercase skill.md (truth source)" {
  local body=$'---\nname: lower\ndescription: lowercase fixture works fine、トリガー語(対応)を含む\n---\n# body'
  local linter
  linter="$(setup_fake_root lower skill.md "$body")"
  run "$linter"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[lower] ok"* ]]
}

@test "skill-lint.sh: recognizes uppercase SKILL.md as fallback" {
  local body=$'---\nname: upper\ndescription: uppercase fallback works fine、トリガー語(対応)を含む\n---\n# body'
  local linter
  linter="$(setup_fake_root upper SKILL.md "$body")"
  run "$linter"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[upper] ok"* ]]
}

@test "skill-lint.sh: missing both skill.md and SKILL.md is error" {
  local fake_root="${FIXTURE_DIR}/no_md"
  mkdir -p "$fake_root/claude-code/skills/empty" \
           "$fake_root/claude-code/lib" \
           "$fake_root/claude-code/scripts"
  cp "$PROJECT_ROOT/claude-code/lib/print-functions.sh" "$fake_root/claude-code/lib/"
  cp "$PROJECT_ROOT/claude-code/lib/colors.sh" "$fake_root/claude-code/lib/"
  cp "$PROJECT_ROOT/claude-code/scripts/skill-lint.sh" "$fake_root/claude-code/scripts/"

  run "$fake_root/claude-code/scripts/skill-lint.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"skill.md not found"* ]]
}

# =============================================================================
# Frontmatter validation
# =============================================================================

@test "skill-lint.sh: detects missing name field" {
  local body=$'---\ndescription: missing name field, includes 使用\n---\n# body'
  local linter
  linter="$(setup_fake_root noname skill.md "$body")"
  run "$linter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'name' field"* ]]
}

@test "skill-lint.sh: detects name vs dir mismatch" {
  local body=$'---\nname: wrong-name\ndescription: name mismatch detection、トリガー語(使用)を含む\n---\n# body'
  local linter
  linter="$(setup_fake_root mismatch skill.md "$body")"
  run "$linter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match dir name"* ]]
}

@test "skill-lint.sh: detects missing description" {
  local body=$'---\nname: nodesc\n---\n# body'
  local linter
  linter="$(setup_fake_root nodesc skill.md "$body")"
  run "$linter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing 'description' field"* ]]
}

@test "skill-lint.sh: warns when description is too short" {
  local body=$'---\nname: short\ndescription: 短いです、対応\n---\n# body'
  local linter
  linter="$(setup_fake_root short skill.md "$body")"
  run "$linter" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"description too short"* ]]
}

@test "skill-lint.sh: warns when description is too long" {
  local long
  long="$(printf 'x%.0s' {1..250})"
  local body
  body="---"$'\n'"name: longdesc"$'\n'"description: ${long} 使用"$'\n'"---"$'\n'"# body"
  local linter
  linter="$(setup_fake_root longdesc skill.md "$body")"
  run "$linter" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"description too long"* ]]
}

@test "skill-lint.sh: warns when description lacks trigger phrase" {
  local body=$'---\nname: notrigger\ndescription: this description has no recognized japanese trigger token here\n---\n# body'
  local linter
  linter="$(setup_fake_root notrigger skill.md "$body")"
  run "$linter" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"lacks trigger phrase"* ]]
}

@test "skill-lint.sh: detects requires-guidelines as scalar (not list)" {
  local body=$'---\nname: rg-scalar\ndescription: scalar requires-guidelines は不正、検出に使用\nrequires-guidelines: common\n---\n# body'
  local linter
  linter="$(setup_fake_root rg-scalar skill.md "$body")"
  run "$linter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires-guidelines must be a list"* ]]
}

@test "skill-lint.sh: detects missing leading frontmatter delimiter" {
  local body=$'name: nofm\ndescription: leading --- なし、検出時に使用\n# body'
  local linter
  linter="$(setup_fake_root nofm skill.md "$body")"
  run "$linter"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing leading"* ]]
}

# =============================================================================
# Strict mode
# =============================================================================

@test "skill-lint.sh: --strict treats warnings as failures" {
  local body=$'---\nname: warnonly\ndescription: short\n---\n# body'
  local linter
  linter="$(setup_fake_root warnonly skill.md "$body")"
  run "$linter" --strict
  [ "$status" -eq 1 ]
}

@test "skill-lint.sh: warnings alone exit 0 without --strict" {
  local body=$'---\nname: warnonly2\ndescription: nope short text\n---\n# body'
  local linter
  linter="$(setup_fake_root warnonly2 skill.md "$body")"
  run "$linter"
  [ "$status" -eq 0 ]
}
