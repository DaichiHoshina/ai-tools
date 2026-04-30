#!/usr/bin/env bats
# =============================================================================
# Parallel Execution Consistency Tests
# =============================================================================
# 背景: 並列実行に関する判断基準・責務分離・worktree 適用判定は
# references/PARALLEL-PATTERNS.md に単一ソース化する。
# 他ファイル（manager-agent / po-agent / developer-agent / agents/README /
# session-management）が並列実行パターン詳細を再記述すると責務分散し、
# 実装後に不整合が生じる。本テストで機械的に防止する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export PATTERNS_FILE="${PROJECT_ROOT}/references/PARALLEL-PATTERNS.md"
  export MANAGER_FILE="${PROJECT_ROOT}/agents/manager-agent.md"
  export FLOW_FILE="${PROJECT_ROOT}/commands/flow.md"
  export DEV_FILE="${PROJECT_ROOT}/commands/dev.md"
}

# セクション抽出: 指定見出しから次の同レベル以下の見出しまでを出力
# args: $1=ファイル, $2=見出し（例: "## critical path 短縮判定式"）
extract_section() {
  local file="$1"
  local heading="$2"
  awk -v hdr="$heading" '
    $0 == hdr { inside = 1; next }
    inside && /^## / { exit }
    inside { print }
  ' "$file"
}

# anchor 存在確認: 見出しがファイル内に存在するか
# args: $1=ファイル, $2=見出し
require_anchor() {
  local file="$1"
  local heading="$2"
  if ! grep -qxF "$heading" "$file"; then
    echo "anchor missing: $heading (in $file)" >&2
    return 1
  fi
}

# =============================================================================
# 境界 1 で有効化されるテスト（3 項目）
# =============================================================================

@test "anchor_exists: PARALLEL-PATTERNS.md に必須 anchor が存在" {
  require_anchor "$PATTERNS_FILE" "## critical path 短縮判定式"
  require_anchor "$PATTERNS_FILE" "## 禁止語句定義（bats 検証対象）"
  require_anchor "$PATTERNS_FILE" "### 4 Developer 上限の根拠"
}

@test "judgment_formula_exists: 判定式に必須要素が含まれる" {
  local section
  section=$(extract_section "$PATTERNS_FILE" "## critical path 短縮判定式")
  [[ -n "$section" ]] || { echo "section empty: ## critical path 短縮判定式"; false; }
  [[ "$section" == *"expected_parallel"* ]] || { echo "missing: expected_parallel"; false; }
  [[ "$section" == *"expected_serial"* ]] || { echo "missing: expected_serial"; false; }
  [[ "$section" == *"× 0.7"* ]] || { echo "missing: × 0.7"; false; }
  [[ "$section" == *"LPT_makespan"* ]] || { echo "missing: LPT_makespan"; false; }
  [[ "$section" == *"sum(T_i)"* ]] || { echo "missing: sum(T_i)"; false; }
  [[ "$section" == *"spawn_cost(N)"* ]] || { echo "missing: spawn_cost(N)"; false; }
  [[ "$section" == *"worktree_setup_cost(N)"* ]] || { echo "missing: worktree_setup_cost(N)"; false; }
}

@test "manager_agent_pattern_removed: manager-agent.md にパターン詳細が残らない" {
  # 並列実行パターン詳細記述が再記述されていないか
  ! grep -qF "パターン1: 完全並列実行" "$MANAGER_FILE"
  ! grep -qF "パターン2: 段階的実行" "$MANAGER_FILE"
  ! grep -qF "パターン3: 順次実行" "$MANAGER_FILE"
  ! grep -qF "同一ファイル変更? → Yes → 順次" "$MANAGER_FILE"
}

# =============================================================================
# 境界 2a で有効化されるテスト（+3 項目、計 6）
# =============================================================================

@test "flow_dev_pattern_ref: flow.md / dev.md 両方に PARALLEL-PATTERNS.md 参照" {
  grep -qE 'references/PARALLEL-PATTERNS\.md' "$FLOW_FILE" \
    || { echo "missing PARALLEL-PATTERNS.md ref in flow.md"; false; }
  grep -qE 'references/PARALLEL-PATTERNS\.md' "$DEV_FILE" \
    || { echo "missing PARALLEL-PATTERNS.md ref in dev.md"; false; }
}

@test "flow_parallel_three_axis: flow.md / dev.md 各々に --parallel 3 軸記述" {
  for file in "$FLOW_FILE" "$DEV_FILE"; do
    grep -qF "並列度評価" "$file" || { echo "missing 並列度評価 in $file"; false; }
    grep -qF "worktree 提案" "$file" || { echo "missing worktree 提案 in $file"; false; }
    grep -qF "worktree 作成" "$file" || { echo "missing worktree 作成 in $file"; false; }
  done
}

@test "flow_auto_four_conditions_with_cleanup: flow.md / dev.md に --auto 4 条件 + 後片付け 3 項目" {
  for file in "$FLOW_FILE" "$DEV_FILE"; do
    # --auto 4 条件
    grep -qF "判定式 PASS" "$file" || { echo "missing 判定式 PASS in $file"; false; }
    grep -qF "clean worktree" "$file" || { echo "missing clean worktree in $file"; false; }
    grep -qE "(branch|worktree).*衝突" "$file" || { echo "missing 衝突なし in $file"; false; }
    grep -qE "(フォールバック|自動フォールバック)" "$file" || { echo "missing フォールバック in $file"; false; }
    # 後片付け 3 項目
    grep -qF "変更あり" "$file" || { echo "missing 変更あり in $file"; false; }
    grep -qF "変更なし" "$file" || { echo "missing 変更なし in $file"; false; }
    grep -qF "マージ衝突" "$file" || { echo "missing マージ衝突 in $file"; false; }
  done
}

# =============================================================================
# 境界 2b で有効化されるテスト（+2 項目、計 8）
# =============================================================================

@test "readme_md_pattern_ref: agents/README.md に PARALLEL-PATTERNS.md 参照" {
  local file="${PROJECT_ROOT}/agents/README.md"
  grep -qE 'references/PARALLEL-PATTERNS\.md' "$file" \
    || { echo "missing PARALLEL-PATTERNS.md ref in agents/README.md"; false; }
}

# YAML 風 target_files / forbidden_phrases リスト抽出
# args: $1=ヘッダ名（"target_files:" or "forbidden_phrases:"）
extract_yaml_list() {
  local header="$1"
  local file="$PATTERNS_FILE"
  # ヘッダ出現回数チェック（0 件 / 2 件以上で fail）
  local count
  count=$(grep -cE "^${header}\$" "$file")
  if [[ "$count" -ne 1 ]]; then
    echo "expected 1 occurrence of '${header}', got ${count}" >&2
    return 1
  fi
  # ヘッダ行から次の空行までを抽出 → ^- 行のみ採用
  awk -v hdr="$header" '
    $0 == hdr { inside = 1; next }
    inside && /^$/ { exit }
    inside {
      if (/^- /) { print substr($0, 3) }
      else { print "INVALID: " $0; exit_code = 1 }
    }
    END { exit exit_code+0 }
  ' "$file"
}

@test "forbidden_phrases_target_files: target_files に禁止語句が含まれない" {
  # target_files / forbidden_phrases の重複/欠落チェック付き抽出
  local target_files
  target_files=$(extract_yaml_list "target_files:") || { echo "$target_files"; false; }
  local forbidden_phrases
  forbidden_phrases=$(extract_yaml_list "forbidden_phrases:") || { echo "$forbidden_phrases"; false; }

  # 抽出範囲内の非空 / 非リスト行検出
  echo "$target_files" | grep -q "^INVALID:" && { echo "target_files has invalid lines"; false; } || true
  echo "$forbidden_phrases" | grep -q "^INVALID:" && { echo "forbidden_phrases has invalid lines"; false; } || true

  # 各 target_file に対し、各 forbidden_phrase が含まれないことを確認
  while IFS= read -r tf; do
    [[ -n "$tf" ]] || continue
    local target_path="${PROJECT_ROOT}/${tf}"
    [[ -f "$target_path" ]] || { echo "target_file missing: $tf"; false; }
    while IFS= read -r phrase; do
      [[ -n "$phrase" ]] || continue
      # ダブルクォート除去
      phrase="${phrase#\"}"
      phrase="${phrase%\"}"
      if grep -qF -- "$phrase" "$target_path"; then
        echo "forbidden phrase '$phrase' found in $tf"
        false
      fi
    done <<< "$forbidden_phrases"
  done <<< "$target_files"
}
