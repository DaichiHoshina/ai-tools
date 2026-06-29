#!/usr/bin/env bats
# =============================================================================
# PO Gate (Manager allocation oversight) consistency
# =============================================================================
# 背景: PO は initial decision を返すだけで Manager allocation を検収していな
# かった。strategy 逸脱 (goal ずれ / constraint 違反 / priority 無視) を入口
# で捕捉するため step 6.3 で PO Gate を追加。canonical 3 file (po-agent /
# flow / contract) で一貫保持する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export PO_FILE="${PROJECT_ROOT}/agents/po-agent.md"
  export FLOW_FILE="${PROJECT_ROOT}/commands/flow.md"
  export CONTRACT_FILE="${PROJECT_ROOT}/references/agent-team-contract.md"
}

# ---------------------------------------------------------------------------
# po-agent: oversight section + base flow step 6
# ---------------------------------------------------------------------------
@test "po-agent: Manager allocation oversight heading" {
  [ -f "$PO_FILE" ]
  run grep -cF "## Manager allocation oversight" "$PO_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "po-agent: base flow step 6 oversight callback" {
  run grep -cF "**Manager allocation oversight** (callback, post-Manager / pre-fan-out)" "$PO_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "po-agent: verdict enum literal (pass | fail | modify)" {
  run grep -cF "verdict: pass | fail | modify" "$PO_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "po-agent: 3 criteria (Goal / Constraints / Priority) 列挙" {
  run grep -cE "Goal alignment|Constraints compliance|Priority order" "$PO_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
}

# ---------------------------------------------------------------------------
# flow.md: step 6.3 PO Gate
# ---------------------------------------------------------------------------
@test "flow.md: step 6.3 PO Gate" {
  [ -f "$FLOW_FILE" ]
  run grep -cF "6.3. **PO Gate**" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "flow.md: Self-Review section に PO Gate 行" {
  run grep -cF "**PO Gate v2** (step 6.3" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

# ---------------------------------------------------------------------------
# contract: §1.1 PO oversight input schema
# ---------------------------------------------------------------------------
@test "contract: §1.1 parent → PO oversight callback heading" {
  [ -f "$CONTRACT_FILE" ]
  run grep -cF "### 1.1. parent → PO (Manager allocation oversight callback)" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "contract: oversight_trigger literal" {
  run grep -cF "oversight_trigger: manager_allocation" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "contract: single-shot no loop 明記" {
  run grep -cF "single-shot, no loop" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Manager hallucination guard (canonical: retrospectives/2026-06-22_manager-hallucination.md)
# 案 1 (PO modify contract に narrow-scope field 強制) + 案 2 (Manager literal echo
# 強制 + parent grep -F validation) のセット実装を 3 file で検証する。
# ---------------------------------------------------------------------------
@test "contract §1.1: fix_request narrow-scope 3 field 明記 (案 1)" {
  run grep -cF "modify_target_task_ids:" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -cF "unchanged_task_ids:" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -cF "modify_reason:" "$CONTRACT_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "manager-agent: PO literal echo 強制段落 (案 2)" {
  MANAGER_FILE="${PROJECT_ROOT}/agents/manager-agent.md"
  [ -f "$MANAGER_FILE" ]
  run grep -cF "**PO literal echo (mandatory)**" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -cF "Path 0: PO modify" "$MANAGER_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "flow.md: step 6.3 grep -F validation 明記 (案 2)" {
  run grep -cF "grep -F" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
