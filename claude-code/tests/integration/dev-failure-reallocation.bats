#!/usr/bin/env bats
# =============================================================================
# Dev failure reallocation consistency
# =============================================================================
# 背景: Dev `status != success` を Manager が放置せず再 allocation loop
# (1 loop max) を回す仕様を canonical 3 file (manager-agent / flow / contract)
# で一貫保持する。desync が起きると dev エラー放置が再発する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export MANAGER_FILE="${PROJECT_ROOT}/agents/manager-agent.md"
  export FLOW_FILE="${PROJECT_ROOT}/commands/flow.md"
  export CONTRACT_FILE="${PROJECT_ROOT}/references/agent-team-contract.md"
}

# ---------------------------------------------------------------------------
# manager-agent: reallocation triggers section に Dev failure path がある
# ---------------------------------------------------------------------------
@test "manager-agent: Reallocation triggers (Dev failure | Reviewer P0) heading" {
  [ -f "$MANAGER_FILE" ]
  run grep -cF "### Reallocation triggers (Dev failure | Reviewer P0)" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "manager-agent: Path 1 Dev failure sub-section" {
  run grep -cF "**Path 1: Dev failure**" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "manager-agent: Path 2 Reviewer P0 sub-section" {
  run grep -cF "**Path 2: Reviewer P0**" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "manager-agent: Base flow step 7 が両 trigger を含む" {
  run grep -cF "Re-allocate (Dev failure | Reviewer P0)" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

# ---------------------------------------------------------------------------
# flow.md: step 8.7 Dev failure gate が存在
# ---------------------------------------------------------------------------
@test "flow.md: step 8.7 Dev failure gate" {
  [ -f "$FLOW_FILE" ]
  run grep -cF "8.7. **Dev failure gate**" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "flow.md: Self-Review section に Dev failure gate 行" {
  run grep -cF "**Dev failure gate** (step 8.7" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "flow.md: --auto 2nd failure stop notify literal" {
  run grep -cF "stop: dev failure 2x" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

# ---------------------------------------------------------------------------
# contract: §3.1 Dev failure reallocation input schema
# ---------------------------------------------------------------------------
@test "contract: §3.1 parent → Manager (Dev failure reallocation input) heading" {
  [ -f "$CONTRACT_FILE" ]
  run grep -cF "### 3.1. parent → Manager (Dev failure reallocation input)" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "contract: reallocation_trigger enum literal" {
  run grep -cF "reallocation_trigger: dev_failure" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "contract: failed_devs[] schema fields" {
  run grep -cF "failed_devs:" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "contract: loop_iteration 2 forbidden 明記" {
  run grep -cF "2 → forbidden" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}
