#!/usr/bin/env bats
# =============================================================================
# Orchestrate Mode Consistency Tests
# =============================================================================
# 背景: orchestrate-mode の設計仕様は references/orchestrate-mode.md に単一ソース化する。
# commands/flow.md の --orchestrate sub-mode entry、
# references/developer-agent-delegation-prompt.md の Parent pre-delegation checklist
# がそれぞれ整合していることを機械的に検証する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

@test "orchestrate-mode.md: 6 必須 section が存在する" {
  local file="$PROJECT_ROOT/references/orchestrate-mode.md"
  [ -f "$file" ]
  run grep -c "^## " "$file"
  [ "$status" -eq 0 ]
  [ "$output" -eq 6 ]
  run grep -F "## Activation" "$file"
  [ "$status" -eq 0 ]
  run grep -F "## Pre-delegation steps (parent 必須)" "$file"
  [ "$status" -eq 0 ]
  run grep -F "## Firing protocol" "$file"
  [ "$status" -eq 0 ]
  run grep -F "## Verify allocation" "$file"
  [ "$status" -eq 0 ]
  run grep -F "## Fail behavior" "$file"
  [ "$status" -eq 0 ]
  run grep -F "## Related" "$file"
  [ "$status" -eq 0 ]
}

@test "flow.md: Orchestration forced section が存在、行数 ≤170" {
  local file="$PROJECT_ROOT/commands/flow.md"
  [ -f "$file" ]
  run grep -c "^## Orchestration (forced)" "$file"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -F "references/orchestrate-mode.md" "$file"
  [ "$status" -eq 0 ]
  # 行数制約 (orchestration 専用化で +20 緩和、新仕様 1bfb29e)
  local line_count
  line_count=$(wc -l < "$file" | tr -d ' ')
  [ "$line_count" -le 170 ]
}

@test "delegation-prompt.md: §0 Parent pre-delegation checklist が存在する" {
  local file="$PROJECT_ROOT/references/developer-agent-delegation-prompt.md"
  [ -f "$file" ]
  run grep -F "## 0. Parent pre-delegation checklist" "$file"
  [ "$status" -eq 0 ]
  # 4 checklist 項目存在
  run grep -F "target file:line 特定済" "$file"
  [ "$status" -eq 0 ]
  run grep -F "verify cmd 確定済" "$file"
  [ "$status" -eq 0 ]
  run grep -F "DoD 1 行化済" "$file"
  [ "$status" -eq 0 ]
  run grep -F "単 domain" "$file"
  [ "$status" -eq 0 ]
}

# self-verify red 化手順 (実装者必須実行):
# 1. orchestrate-mode.md から `## Firing protocol` heading を削除 → case 1 FAIL 確認
# 2. flow.md から `## --orchestrate` heading を削除 → case 2 FAIL 確認
# 3. delegation-prompt.md から `## 0. Parent pre-delegation checklist` heading を削除 → case 3 FAIL 確認
# 4. 全 file を git checkout で復元 → bats 全件 PASS 確認
# pass-by-coincidence 排除確認済
