#!/usr/bin/env bats
# =============================================================================
# /onboard command consistency tests
# =============================================================================
# 背景: onboard.md は Serena onboarding tool 相当の project 理解を作るが、
# write_memory / onboarding / edit_memory の使用は全 project 禁止 (CLAUDE.md)。
# 本 test は必須 section / 必須 keyword / 禁止 tool 不使用 / 行数上限を固定する。
# =============================================================================

setup() {
  # shellcheck source=../helpers/common.bash
  load "../helpers/common"
  ONBOARD_FILE="$PROJECT_ROOT/commands/onboard.md"
}

@test "onboard.md: 存在する" {
  [ -f "$ONBOARD_FILE" ]
}

@test "onboard.md: 7 必須 heading が存在する" {
  run grep -qxF "# /onboard - Project onboarding memory" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## Save target dir" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## 収集フェーズ" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## 保存フェーズ" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## File format" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## Guard" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qxF "## Fallback" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
}

@test "onboard.md: 末尾に ARGUMENTS 行がある" {
  # shellcheck disable=SC2016  # $ARGUMENTS は literal 文字列として grep する
  run grep -qxF 'ARGUMENTS: $ARGUMENTS' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
}

@test "onboard.md: frontmatter に allowed-tools / description がある" {
  run grep -qE "^allowed-tools:" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qE "^description:" "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -E "^allowed-tools:" "$ONBOARD_FILE"
  [[ "$output" == *"Write"* ]]
}

@test "onboard.md: 保存先 dir の必須 keyword を含む" {
  run grep -qF '~/ai-tools/memory/' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qF 'MEMORY.md' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
}

@test "onboard.md: File format に metadata / type: project を含む" {
  run grep -qF 'metadata:' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qF 'type: project' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
}

@test "onboard.md: File format に Why / How to apply を含む" {
  run grep -qF '**Why:**' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
  run grep -qF '**How to apply:**' "$ONBOARD_FILE"
  [ "$status" -eq 0 ]
}

@test "onboard.md: allowed-tools に禁止 tool (write_memory 等) が現れない" {
  run grep -E "^allowed-tools:" "$ONBOARD_FILE"
  [[ "$output" != *"write_memory"* ]]
  [[ "$output" != *"onboarding"* ]]
  [[ "$output" != *"edit_memory"* ]]
  [[ "$output" != *"mcp__serena"* ]]
}

@test "onboard.md: write_memory / onboarding / edit_memory への言及は全て禁止文脈である" {
  # 「禁止する」「使わない」を伴わない使用指示行が無いことを確認する
  # (単純な grep -qF write_memory は禁止文自体に true positive してしまうため除外パターンで判定する)
  local bad_lines
  bad_lines=$(grep -E 'write_memory|edit_memory|onboarding.*tool' "$ONBOARD_FILE" \
    | grep -vE '禁止|使わない|しない|相当' || true)
  [ -z "$bad_lines" ]
}

@test "onboard.md: 行数が150行以下" {
  local line_count
  line_count=$(wc -l < "$ONBOARD_FILE" | tr -d ' ')
  [ "$line_count" -le 150 ]
}
