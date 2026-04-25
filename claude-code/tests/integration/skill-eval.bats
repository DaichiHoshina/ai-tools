#!/usr/bin/env bats
# =============================================================================
# Integration Tests for scripts/skill-eval.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export EVAL_SH="${PROJECT_ROOT}/claude-code/scripts/skill-eval.sh"
  export FIXTURE_DIR="${BATS_TMPDIR}/skill-eval-fixture-${RANDOM}"
  mkdir -p "$FIXTURE_DIR/projects/proj-A"
  export CLAUDE_PROJECTS_DIR="$FIXTURE_DIR/projects"
}

teardown() {
  rm -rf "$FIXTURE_DIR"
}

# Helper: 任意のスキル発火を含む jsonl 行を生成
write_skill_invocation() {
  local skill="$1"
  local file="$2"
  python3 - "$skill" >> "$file" <<'PY'
import json, sys
record = {
  "type": "assistant",
  "message": {
    "role": "assistant",
    "content": [
      {"type": "tool_use", "id": "x", "name": "Skill",
       "input": {"skill": sys.argv[1]}}
    ]
  }
}
print(json.dumps(record, ensure_ascii=False))
PY
}

@test "skill-eval.sh: has valid bash syntax" {
  run bash -n "$EVAL_SH"
  [ "$status" -eq 0 ]
}

@test "skill-eval.sh: --help exits 0" {
  run "$EVAL_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "skill-eval.sh: --days without arg exits 2" {
  run "$EVAL_SH" --days
  [ "$status" -eq 2 ]
}

@test "skill-eval.sh: unknown option exits 2" {
  run "$EVAL_SH" --bogus
  [ "$status" -eq 2 ]
}

@test "skill-eval.sh: empty transcripts dir produces zero hits" {
  run "$EVAL_SH" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 Skill invocations"* ]]
}

@test "skill-eval.sh: counts a local-skill invocation" {
  local fixture="$FIXTURE_DIR/projects/proj-A/session.jsonl"
  : > "$fixture"
  write_skill_invocation comprehensive-review "$fixture"
  write_skill_invocation comprehensive-review "$fixture"
  write_skill_invocation comprehensive-review "$fixture"

  run "$EVAL_SH" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 Skill invocations"* ]]
  [[ "$output" == *"3  comprehensive-review"* ]]
}

@test "skill-eval.sh: classifies unknown skills as non-local" {
  local fixture="$FIXTURE_DIR/projects/proj-A/session.jsonl"
  : > "$fixture"
  write_skill_invocation __community_skill__ "$fixture"

  run "$EVAL_SH" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"non-local"* ]]
  [[ "$output" == *"1  __community_skill__"* ]]
}

@test "skill-eval.sh: --skill filters to one skill" {
  local fixture="$FIXTURE_DIR/projects/proj-A/session.jsonl"
  : > "$fixture"
  write_skill_invocation comprehensive-review "$fixture"
  write_skill_invocation backend-dev "$fixture"

  run "$EVAL_SH" --all --skill backend-dev
  [ "$status" -eq 0 ]
  [[ "$output" == *"[backend-dev] 1 invocations"* ]]
}

@test "skill-eval.sh: --unused lists local skills with 0 hits" {
  local fixture="$FIXTURE_DIR/projects/proj-A/session.jsonl"
  : > "$fixture"
  write_skill_invocation comprehensive-review "$fixture"

  run "$EVAL_SH" --all --unused
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unused local skills"* ]]
  [[ "$output" == *"backend-dev"* ]]
  # comprehensive-review は使われたので unused には出ない
  [[ "$output" != *"- comprehensive-review"* ]]
}

@test "skill-eval.sh: respects CLAUDE_PROJECTS_DIR override" {
  # setup で既に上書き済み。空ディレクトリ指定で 0 hits になることを確認
  run "$EVAL_SH" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"$CLAUDE_PROJECTS_DIR"* ]]
}

@test "skill-eval.sh: nonexistent transcripts dir exits 2" {
  CLAUDE_PROJECTS_DIR="$FIXTURE_DIR/__no_such__" run "$EVAL_SH" --all
  [ "$status" -eq 2 ]
}
