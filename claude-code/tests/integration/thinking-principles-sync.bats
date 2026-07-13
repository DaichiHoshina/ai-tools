#!/usr/bin/env bats
# =============================================================================
# Integration Tests for 思考原則の 3 tool 同期 (drift 検出)
#   - claude-code/rules/thinking-principles.md (canonical)
#   - codex/AGENTS.md.example managed:codex-thinking block
#   - cursor/rules/ai-tools-thinking.mdc
#   - agents/*.md の Universal core 一致
# =============================================================================

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  RULE="${PROJECT_ROOT}/claude-code/rules/thinking-principles.md"
  CODEX="${PROJECT_ROOT}/codex/AGENTS.md.example"
  CURSOR="${PROJECT_ROOT}/cursor/rules/ai-tools-thinking.mdc"
  AGENTS_DIR="${PROJECT_ROOT}/claude-code/agents"
}

@test "rule: 7 原則 section が揃っている" {
  for n in 1 2 3 4 5 6 7; do
    grep -q "^## ${n}\." "$RULE"
  done
  [ "$(grep -c '^## [0-9]\.' "$RULE")" -eq 7 ]
}

@test "anchor 語句が 3 file 全てに存在する (片側編集 drift 検出)" {
  anchors=(書かれた時点の事実 委譲した調査 略称 中断 反証 立ち止ま 元の依頼 "2 回失敗")
  for a in "${anchors[@]}"; do
    grep -q "$a" "$RULE"   || { echo "rule に anchor なし: $a"; false; }
    grep -q "$a" "$CODEX"  || { echo "codex に anchor なし: $a"; false; }
    grep -q "$a" "$CURSOR" || { echo "cursor に anchor なし: $a"; false; }
  done
}

@test "codex: managed:codex-thinking block の marker が存在する" {
  grep -q '<!-- BEGIN managed:codex-thinking -->' "$CODEX"
  grep -q '<!-- END managed:codex-thinking -->' "$CODEX"
}

@test "cursor: frontmatter alwaysApply: true" {
  head -5 "$CURSOR" | grep -q '^alwaysApply: true$'
}

@test "agents: 8 file の Universal core が完全一致" {
  count="$(grep -l '^\*\*Universal core\*\*:' "$AGENTS_DIR"/*.md | wc -l | tr -d ' ')"
  [ "$count" -eq 8 ]
  uniq_lines="$(grep -h '^\*\*Universal core\*\*:' "$AGENTS_DIR"/*.md | sort -u | wc -l | tr -d ' ')"
  [ "$uniq_lines" -eq 1 ]
}
