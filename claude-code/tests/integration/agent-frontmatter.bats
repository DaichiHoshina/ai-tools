#!/usr/bin/env bats
# =============================================================================
# Agent Frontmatter Invariants
# =============================================================================
# 背景: Claude Code の sub-agent は他の sub-agent を spawn できない仕様
# (https://code.claude.com/docs/en/sub-agents.md)。
# 非実装系 agent (po/manager/explore) が Write/Edit を獲得したり tools に
# Task(...) を追加されたりすると回帰する。本テストで機械的に防止する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export AGENTS_DIR="${PROJECT_ROOT}/agents"
}

# フロントマター抽出: 最初の --- と 2 番目の --- の間を出力
get_frontmatter() {
  awk '/^---$/{c++; next} c==1' "$1"
}

# =============================================================================
# po-agent: 戦略決定のみ。実装禁止・Manager 自走起動禁止。
# =============================================================================

@test "po-agent: disallowedTools で Write/Edit/MultiEdit を封じている" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/po-agent.md")
  [[ "$fm" =~ disallowedTools ]]
  [[ "$fm" =~ Write ]]
  [[ "$fm" =~ Edit ]]
  [[ "$fm" =~ MultiEdit ]]
}

@test "po-agent: tools に Task(...) を含まない (sub-agent spec 準拠)" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/po-agent.md")
  ! [[ "$fm" =~ Task\( ]]
}

# =============================================================================
# manager-agent: 配分計画のみ。実装禁止・Developer 自走起動禁止。
# =============================================================================

@test "manager-agent: disallowedTools で Write/Edit/MultiEdit を封じている" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/manager-agent.md")
  [[ "$fm" =~ disallowedTools ]]
  [[ "$fm" =~ Write ]]
  [[ "$fm" =~ Edit ]]
  [[ "$fm" =~ MultiEdit ]]
}

@test "manager-agent: tools に Task(...) を含まない (sub-agent spec 準拠)" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/manager-agent.md")
  ! [[ "$fm" =~ Task\( ]]
}

# =============================================================================
# explore-agent: 読み取り専用。Write/Edit を物理封じ。
# =============================================================================

@test "explore-agent: disallowedTools で Write/Edit/MultiEdit を封じている" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/explore-agent.md")
  [[ "$fm" =~ disallowedTools ]]
  [[ "$fm" =~ Write ]]
  [[ "$fm" =~ Edit ]]
  [[ "$fm" =~ MultiEdit ]]
}

@test "explore-agent: tools に Task(...) を含まない (sub-agent spec 準拠)" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/explore-agent.md")
  ! [[ "$fm" =~ Task\( ]]
}

# =============================================================================
# developer-agent: 実装担当。Write/Edit を許可、Task() は禁止。
# =============================================================================

@test "developer-agent: tools に Task(...) を含まない (sub-agent spec 準拠)" {
  local fm=$(get_frontmatter "${AGENTS_DIR}/developer-agent.md")
  ! [[ "$fm" =~ Task\( ]]
}
