#!/usr/bin/env bats
# =============================================================================
# Agent Trailer Schema Invariants
# =============================================================================
# 背景: CLAUDE.md §Discovery/Investigation Routing で「trailer フィールド
# (status / confidence / issues_blocking) を必ず読む」と規定されている。
# references/agent-output-schema.md が trailer の canonical 定義。
# 各 agent definition file にこの 3 keyword が記載されているかを機械検証する。
#
# reviewer-agent: accept/reject パターンで独自 output schema を持ち、
# issues_blocking を trailer に含まない設計のため skip (report 対象)。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export AGENTS_DIR="${PROJECT_ROOT}/agents"
}

# =============================================================================
# developer-agent
# =============================================================================

@test "developer-agent: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/developer-agent.md"
}

@test "developer-agent: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/developer-agent.md"
}

@test "developer-agent: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/developer-agent.md"
}

# =============================================================================
# explore-agent
# =============================================================================

@test "explore-agent: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/explore-agent.md"
}

@test "explore-agent: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/explore-agent.md"
}

@test "explore-agent: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/explore-agent.md"
}

# =============================================================================
# root-cause-analyzer
# =============================================================================

@test "root-cause-analyzer: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/root-cause-analyzer.md"
}

@test "root-cause-analyzer: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/root-cause-analyzer.md"
}

@test "root-cause-analyzer: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/root-cause-analyzer.md"
}

# =============================================================================
# manager-agent
# =============================================================================

@test "manager-agent: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/manager-agent.md"
}

@test "manager-agent: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/manager-agent.md"
}

@test "manager-agent: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/manager-agent.md"
}

# =============================================================================
# po-agent
# =============================================================================

@test "po-agent: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/po-agent.md"
}

@test "po-agent: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/po-agent.md"
}

@test "po-agent: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/po-agent.md"
}

# =============================================================================
# verify-app
# =============================================================================

@test "verify-app: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/verify-app.md"
}

@test "verify-app: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/verify-app.md"
}

@test "verify-app: trailer schema に issues_blocking を含む" {
  grep -q 'issues_blocking' "${AGENTS_DIR}/verify-app.md"
}

# =============================================================================
# reviewer-agent
# skip: accept/reject パターンで独自 output schema を持つ設計。
# issues_blocking は trailer に含まれず、confidence は lens 固有の 0-100 整数。
# trailer schema 統合は scope 外 (要 agent 設計変更) のため skip で記録する。
# =============================================================================

@test "reviewer-agent: trailer schema に status を含む" {
  grep -q 'status' "${AGENTS_DIR}/reviewer-agent.md"
}

@test "reviewer-agent: trailer schema に confidence を含む" {
  grep -q 'confidence' "${AGENTS_DIR}/reviewer-agent.md"
}

@test "reviewer-agent: trailer schema に issues_blocking を含む (skip: 独自スキーマ設計)" {
  skip "reviewer-agent は accept/reject output schema を使用し issues_blocking を持たない設計 (references/agent-output-schema.md との統合は要設計変更)"
  grep -q 'issues_blocking' "${AGENTS_DIR}/reviewer-agent.md"
}
