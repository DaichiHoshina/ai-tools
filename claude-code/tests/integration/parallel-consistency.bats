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
  export CLAUDEMD_FILE="${PROJECT_ROOT}/CLAUDE.global.md"
  export TRIGGERS_FILE="${PROJECT_ROOT}/references/natural-language-triggers.md"
}

# Extract section: from given heading up to next same-or-higher level heading
# args: $1=file, $2=heading (e.g. "## Critical-path reduction formula")
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
  require_anchor "$PATTERNS_FILE" "## Critical-path reduction formula"
  require_anchor "$PATTERNS_FILE" "## Forbidden phrase definitions (bats validation targets)"
  require_anchor "$PATTERNS_FILE" "### Why the 8-Developer limit"
}

@test "judgment_formula_exists: 判定式に必須要素が含まれる" {
  local section
  section=$(extract_section "$PATTERNS_FILE" "## Critical-path reduction formula")
  [[ -n "$section" ]] || { echo "section empty: ## Critical-path reduction formula"; false; }
  [[ "$section" == *"expected_parallel"* ]] || { echo "missing: expected_parallel"; false; }
  [[ "$section" == *"expected_serial"* ]] || { echo "missing: expected_serial"; false; }
  [[ "$section" == *"× 0.95"* ]] || { echo "missing: × 0.95"; false; }
  [[ "$section" == *"LPT_makespan"* ]] || { echo "missing: LPT_makespan"; false; }
  [[ "$section" == *"sum(T_i)"* ]] || { echo "missing: sum(T_i)"; false; }
  [[ "$section" == *"spawn_cost(N)"* ]] || { echo "missing: spawn_cost(N)"; false; }
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

@test "flow_parallel_three_axis: flow.md / dev.md 各々に Parallel section 3 軸記述" {
  for file in "$FLOW_FILE" "$DEV_FILE"; do
    grep -qE "^## (--parallel|Parallel)" "$file" || { echo "missing Parallel section in $file"; false; }
    grep -qF "worktree proposal" "$file" || { echo "missing worktree proposal in $file"; false; }
    grep -qF "worktree creation" "$file" || { echo "missing worktree creation in $file"; false; }
  done
}

@test "flow_auto_four_conditions_with_cleanup: flow.md / dev.md は canonical 参照、実体は PARALLEL-PATTERNS.md に存在" {
  # flow.md / dev.md は summary を再記述せず canonical link のみ持つ (desync の構造的排除)
  for file in "$FLOW_FILE" "$DEV_FILE"; do
    grep -qF "skip 4 conditions" "$file" || { echo "missing skip 4 conditions ref in $file"; false; }
    grep -qF "cleanup policy" "$file" || { echo "missing cleanup policy ref in $file"; false; }
    grep -qF "PARALLEL-PATTERNS.md" "$file" || { echo "missing PARALLEL-PATTERNS.md ref in $file"; false; }
  done
  # canonical 側に実体 (4 条件 + 後片付け 3 項目) が存在すること
  grep -qF "formula PASS" "$PATTERNS_FILE" || { echo "missing formula PASS in PATTERNS_FILE"; false; }
  grep -qiF "clean worktree" "$PATTERNS_FILE" || { echo "missing clean worktree in PATTERNS_FILE"; false; }
  grep -qiE "(branch|worktree).*(collision|conflict)" "$PATTERNS_FILE" || { echo "missing collision in PATTERNS_FILE"; false; }
  grep -qiF "worktree with changes" "$PATTERNS_FILE" || { echo "missing worktree-with-changes in PATTERNS_FILE"; false; }
  grep -qiF "no changes" "$PATTERNS_FILE" || { echo "missing no changes in PATTERNS_FILE"; false; }
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

# =============================================================================
# 境界 3 で有効化されるテスト（+2 項目、計 10）
# =============================================================================

# CLAUDE.md トリガー表セクション抽出: ## Natural Language Triggers... 〜 次 ## まで
extract_trigger_table() {
  awk '
    /^## Natural Language Triggers/ { inside = 1; next }
    inside && /^## / { exit }
    inside { print }
  ' "$CLAUDEMD_FILE"
}

@test "trigger_table_no_forbidden: トリガー表に「同時に」「並走で」非含有" {
  local section
  section=$(extract_trigger_table)
  [[ -n "$section" ]] || { echo "anchor missing: ## Natural Language Triggers"; false; }
  ! echo "$section" | grep -qF "同時に" || { echo "trigger table contains 同時に"; false; }
  ! echo "$section" | grep -qF "並走で" || { echo "trigger table contains 並走で"; false; }
}

@test "trigger_table_main_phrases: CLAUDE.md トリガー表に主要 2 句存在" {
  # CLAUDE.md は「主要のみ」、全 4 句は references/natural-language-triggers.md に集約
  local section
  section=$(extract_trigger_table)
  [[ -n "$section" ]] || { echo "anchor missing: ## Natural Language Triggers"; false; }
  echo "$section" | grep -qF '"並列実行で"' || { echo "missing 並列実行で"; false; }
  echo "$section" | grep -qF '"wt 分けて"' || { echo "missing wt 分けて"; false; }
}

@test "trigger_table_four_phrases_in_references: 全リスト references に 4 句存在" {
  [[ -f "$TRIGGERS_FILE" ]] || { echo "missing $TRIGGERS_FILE"; false; }
  grep -qF '"並列実行で"' "$TRIGGERS_FILE" || { echo "missing 並列実行で in references"; false; }
  grep -qF '"Developer 並列で"' "$TRIGGERS_FILE" || { echo "missing Developer 並列で in references"; false; }
  grep -qF '"worktree 分けて"' "$TRIGGERS_FILE" || { echo "missing worktree 分けて in references"; false; }
  grep -qF '"wt 分けて"' "$TRIGGERS_FILE" || { echo "missing wt 分けて in references"; false; }
}

# =============================================================================
# 境界 4: 検算例の数値整合テスト（+2 項目、計 12）
# PARALLEL-PATTERNS.md の Team/Direct 各 N=2/4/8 検算例を導出式で再計算して照合する。
# desync（式か検算例の一方だけ変更）を機械検出するための回帰テスト。
# =============================================================================

# 検算値の照合ヘルパ
# args: $1=検索パターン(grep -F), $2=N値, $3=overhead(N)の数値
# 式: T_task_threshold = overhead(N) / (0.95*N - 1)
# 記載値を抽出し、式での再計算値と差 < 0.1 を確認する
_check_threshold() {
  local line_pattern="$1"
  local n="$2"
  local overhead="$3"

  # ファイルから該当行を抽出して末尾の数値 (例: 244.4) を取得
  local doc_line
  doc_line=$(grep -F "$line_pattern" "$PATTERNS_FILE") || {
    echo "line not found matching: $line_pattern"
    return 1
  }
  local doc_val
  doc_val=$(echo "$doc_line" | grep -oE '[0-9]+\.[0-9]+s' | tail -1 | tr -d 's')
  [[ -n "$doc_val" ]] || { echo "cannot extract numeric value from: $doc_line"; return 1; }

  # 式: overhead / (0.95 * N - 1) を awk で計算（小数第1位まで）
  local calc_val
  calc_val=$(awk -v oh="$overhead" -v n="$n" 'BEGIN {
    denom = 0.95 * n - 1
    printf "%.1f", oh / denom
  }')

  # 差が 0.1 以上なら fail
  local ok
  ok=$(awk -v a="$doc_val" -v b="$calc_val" 'BEGIN {
    diff = a - b; if (diff < 0) diff = -diff
    print (diff < 0.1) ? "ok" : "ng"
  }')

  if [[ "$ok" != "ok" ]]; then
    echo "threshold mismatch for pattern='${line_pattern}' N=${n}: doc=${doc_val}s, calc=${calc_val}s"
    return 1
  fi
}

@test "formula_consistency_team: Team path 検算例が導出式と一致" {
  # overhead_team(N) = 180 + 20N → N=2: 220, N=4: 260, N=8: 340
  # 検算行の overhead 数値でマッチ（Direct の 60/100/180 と混在しない）
  _check_threshold "220 / (1.9" 2 220 || false
  _check_threshold "260 / (3.8" 4 260 || false
  _check_threshold "340 / (7.6" 8 340 || false
}

@test "formula_consistency_direct: Direct path 検算例が導出式と一致" {
  # overhead_direct(N) = 20N + 20
  # Team と Direct は同一 N で同じ行パターンになるため、overhead 数値ごとに個別に検索する
  _check_threshold "60 / (1.9" 2  60 || false
  _check_threshold "100 / (3.8" 4 100 || false
  _check_threshold "180 / (7.6" 8 180 || false
}
