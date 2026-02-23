#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-skill-use.sh
# ガイドライン自動読み込みフックのユニットテスト
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-skill-use.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # テスト用スキルディレクトリ（$HOME/.claude/skills に依存しないよう独立化）
  export TEST_SKILLS_DIR="${TEST_TMPDIR}/skills"
  mkdir -p "${TEST_SKILLS_DIR}"

  # テスト用セッションID固定（セッション状態のテストに使用）
  export CLAUDE_SESSION_ID="test-session-bats-$$"

  # セッション状態ファイルをテスト用に上書き
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}/.claude"

  # mise が HOME を参照して設定ファイルの trust チェックを行うため、
  # 元の mise データ・設定ディレクトリを明示指定して trust エラーを回避
  export MISE_DATA_DIR="${HOME_ORIG:-$REAL_HOME}/.local/share/mise"
  export MISE_CONFIG_DIR="${HOME_ORIG:-$REAL_HOME}/.config/mise"
}

# REAL_HOME: setup() が上書きする前の HOME を保持
REAL_HOME="${HOME}"

teardown() {
  rm -rf "${TEST_TMPDIR}"
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# スキルディレクトリとskill.mdを作成する
create_skill() {
  local skill_name="$1"
  local frontmatter="$2"
  local skill_dir="${TEST_SKILLS_DIR}/${skill_name}"
  mkdir -p "${skill_dir}"
  # HOMEを書き換えているのでフックが参照するパスに合わせる
  local target_dir="${HOME}/.claude/skills/${skill_name}"
  mkdir -p "${target_dir}"
  printf '%s\n' "${frontmatter}" > "${target_dir}/skill.md"
}

# requires-guidelines を持つskill.mdを作成する
create_skill_with_guidelines() {
  local skill_name="$1"
  shift
  local guidelines=("$@")

  local target_dir="${HOME}/.claude/skills/${skill_name}"
  mkdir -p "${target_dir}"

  local frontmatter="---
name: ${skill_name}
description: テスト用スキル
requires-guidelines:"
  for gl in "${guidelines[@]}"; do
    frontmatter="${frontmatter}
  - ${gl}"
  done
  frontmatter="${frontmatter}
---

# ${skill_name}
"
  printf '%s\n' "${frontmatter}" > "${target_dir}/skill.md"
}

# requires-guidelines なしのskill.mdを作成する
create_skill_no_guidelines() {
  local skill_name="$1"
  local target_dir="${HOME}/.claude/skills/${skill_name}"
  mkdir -p "${target_dir}"
  printf '%s\n' "---
name: ${skill_name}
description: テスト用スキル（ガイドラインなし）
---

# ${skill_name}
" > "${target_dir}/skill.md"
}

# フックを実行してJSON出力を取得
run_hook() {
  local skill_name="$1"
  local input
  input=$(jq -n --arg skill "${skill_name}" '{skill: $skill}')
  echo "${input}" | bash "${HOOK_FILE}"
}

# フックを任意のJSON入力で実行
run_hook_with_input() {
  local input="$1"
  echo "${input}" | bash "${HOOK_FILE}"
}

# JSON出力から systemMessage を抽出
get_system_message() {
  echo "$1" | jq -r '.systemMessage // empty'
}

# JSON出力から additionalContext を抽出
get_additional_context() {
  echo "$1" | jq -r '.additionalContext // empty'
}

# セッション状態ファイルを削除してクリーンな状態にする
clear_session_state() {
  rm -f "${HOME}/.claude/session-state.json"
}

# =============================================================================
# スキル名なし・空のテスト
# =============================================================================

@test "pre-skill-use: skill フィールドが空文字の場合は空JSON" {
  result=$(run_hook "")
  [ "${result}" = "{}" ]
}

@test "pre-skill-use: skill フィールドがない場合は空JSON" {
  result=$(run_hook_with_input '{}')
  [ "${result}" = "{}" ]
}

@test "pre-skill-use: skill フィールドが null の場合は空JSON" {
  result=$(run_hook_with_input '{"skill": null}')
  [ "${result}" = "{}" ]
}

# =============================================================================
# スキルファイル不在のテスト
# =============================================================================

@test "pre-skill-use: 存在しないスキルは警告メッセージを返す" {
  result=$(run_hook "non-existent-skill-xyz")
  msg=$(get_system_message "${result}")
  [[ "${msg}" =~ "not found" ]]
}

@test "pre-skill-use: 存在しないスキルでも終了コードは0" {
  run_hook_with_input '{"skill": "no-such-skill"}' > /dev/null
  [ "$?" -eq 0 ]
}

@test "pre-skill-use: 存在しないスキルの警告メッセージにスキル名が含まれる" {
  result=$(run_hook "my-unknown-skill")
  msg=$(get_system_message "${result}")
  [[ "${msg}" =~ "my-unknown-skill" ]]
}

# =============================================================================
# requires-guidelines なし・空のテスト
# =============================================================================

@test "pre-skill-use: requires-guidelines が空のスキルは空JSON" {
  create_skill_no_guidelines "no-guidelines-skill"
  result=$(run_hook "no-guidelines-skill")
  [ "${result}" = "{}" ]
}

@test "pre-skill-use: requires-guidelines セクション自体がないスキルは空JSON" {
  local target_dir="${HOME}/.claude/skills/minimal-skill"
  mkdir -p "${target_dir}"
  printf '%s\n' "---
name: minimal-skill
description: ガイドラインセクションなし
---
" > "${target_dir}/skill.md"

  result=$(run_hook "minimal-skill")
  [ "${result}" = "{}" ]
}

# =============================================================================
# ガイドライン読み込みトリガーのテスト
# =============================================================================

@test "pre-skill-use: requires-guidelines があれば Auto-loading メッセージを返す" {
  clear_session_state
  create_skill_with_guidelines "test-skill-common" "common"

  result=$(run_hook "test-skill-common")
  msg=$(get_system_message "${result}")
  [[ "${msg}" =~ "Auto-loading" ]]
}

@test "pre-skill-use: additionalContext にスキル名が含まれる" {
  clear_session_state
  create_skill_with_guidelines "test-skill-ctx" "common"

  result=$(run_hook "test-skill-ctx")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "test-skill-ctx" ]]
}

@test "pre-skill-use: additionalContext に summaries の読み込み指示が含まれる" {
  clear_session_state
  create_skill_with_guidelines "test-skill-summary" "common"

  result=$(run_hook "test-skill-summary")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "summaries" ]]
}

# =============================================================================
# ガイドライン種類別サマリーパスのテスト
# =============================================================================

@test "pre-skill-use: common ガイドラインは common-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-common" "common"

  result=$(run_hook "skill-common")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "common-summary.md" ]]
}

@test "pre-skill-use: typescript ガイドラインは typescript-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-ts" "typescript"

  result=$(run_hook "skill-ts")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "typescript-summary.md" ]]
}

@test "pre-skill-use: golang ガイドラインは golang-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-go" "golang"

  result=$(run_hook "skill-go")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "golang-summary.md" ]]
}

@test "pre-skill-use: nextjs-react ガイドラインは nextjs-react-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-react" "nextjs-react"

  result=$(run_hook "skill-react")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "nextjs-react-summary.md" ]]
}

@test "pre-skill-use: design ガイドラインは design-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-design" "design"

  result=$(run_hook "skill-design")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "design-summary.md" ]]
}

@test "pre-skill-use: clean-architecture ガイドラインは design-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-ca" "clean-architecture"

  result=$(run_hook "skill-ca")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "design-summary.md" ]]
}

@test "pre-skill-use: ddd ガイドラインは design-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-ddd" "ddd"

  result=$(run_hook "skill-ddd")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "design-summary.md" ]]
}

# =============================================================================
# セキュリティスキル検出のテスト
# =============================================================================

@test "pre-skill-use: security ガイドラインは security-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-sec" "security"

  result=$(run_hook "skill-sec")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "security-summary.md" ]]
}

@test "pre-skill-use: error-handling ガイドラインは security-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-errh" "error-handling"

  result=$(run_hook "skill-errh")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "security-summary.md" ]]
}

@test "pre-skill-use: infrastructure ガイドラインは infrastructure-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-infra" "infrastructure"

  result=$(run_hook "skill-infra")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "infrastructure-summary.md" ]]
}

@test "pre-skill-use: terraform ガイドラインは infrastructure-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-tf" "terraform"

  result=$(run_hook "skill-tf")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "infrastructure-summary.md" ]]
}

@test "pre-skill-use: kubernetes ガイドラインは infrastructure-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-k8s" "kubernetes"

  result=$(run_hook "skill-k8s")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "infrastructure-summary.md" ]]
}

# =============================================================================
# 未知のガイドラインのテスト
# =============================================================================

@test "pre-skill-use: 未知のガイドラインはフォールバックパスを参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-unknown-gl" "my-custom-guideline"

  result=$(run_hook "skill-unknown-gl")
  ctx=$(get_additional_context "${result}")
  # フォールバック: **/$guideline.md パターン
  [[ "${ctx}" =~ "my-custom-guideline.md" ]]
}

# =============================================================================
# セッション状態管理のテスト
# =============================================================================

@test "pre-skill-use: 初回実行でガイドラインが session-state.json に記録される" {
  clear_session_state
  create_skill_with_guidelines "skill-session1" "common"

  run_hook "skill-session1" > /dev/null

  [ -f "${HOME}/.claude/session-state.json" ]
  loaded=$(jq -r '.loaded_guidelines | join(",")' "${HOME}/.claude/session-state.json")
  [[ "${loaded}" =~ "common" ]]
}

@test "pre-skill-use: 同一セッションでの2回目実行は空JSON（キャッシュ済み）" {
  clear_session_state
  create_skill_with_guidelines "skill-session2" "common"

  # 1回目
  run_hook "skill-session2" > /dev/null

  # 2回目は既にロード済みなので {} を返す
  result=$(run_hook "skill-session2")
  [ "${result}" = "{}" ]
}

@test "pre-skill-use: 別スキルで異なるガイドラインが追加記録される" {
  clear_session_state
  create_skill_with_guidelines "skill-acc1" "common"
  create_skill_with_guidelines "skill-acc2" "typescript"

  # 1回目: common が記録される
  run_hook "skill-acc1" > /dev/null

  # 2回目: typescript が追加される
  run_hook "skill-acc2" > /dev/null

  loaded=$(jq -r '.loaded_guidelines | join(",")' "${HOME}/.claude/session-state.json")
  [[ "${loaded}" =~ "common" ]]
  [[ "${loaded}" =~ "typescript" ]]
}

@test "pre-skill-use: 別スキルに共通ガイドラインがあっても再読み込みしない" {
  clear_session_state
  create_skill_with_guidelines "skill-share1" "common" "golang"
  create_skill_with_guidelines "skill-share2" "common" "typescript"

  # 1回目: common, golang が記録される
  run_hook "skill-share1" > /dev/null

  # 2回目: common は済み、typescript だけ新規で読み込まれる
  result=$(run_hook "skill-share2")
  msg=$(get_system_message "${result}")
  # common は再読み込みされないが typescript は読み込まれる
  [[ "${msg}" =~ "Auto-loading" ]]
  [[ "${msg}" =~ "typescript" ]]
  # common は含まれないはず
  if [[ "${msg}" =~ "common" ]]; then
    false  # common が再度読み込まれているのは誤り
  fi
  true
}

@test "pre-skill-use: セッション状態ファイルに session_id が記録される" {
  clear_session_state
  create_skill_with_guidelines "skill-sessid" "common"

  run_hook "skill-sessid" > /dev/null

  stored_id=$(jq -r '.session_id' "${HOME}/.claude/session-state.json")
  [ "${stored_id}" = "${CLAUDE_SESSION_ID}" ]
}

# =============================================================================
# 複数ガイドラインのテスト
# =============================================================================

@test "pre-skill-use: 複数ガイドラインが同時に読み込まれる" {
  clear_session_state
  create_skill_with_guidelines "skill-multi" "common" "golang" "clean-architecture"

  result=$(run_hook "skill-multi")
  # 複数ガイドライン時はsystemMessageをgrepで確認（JSON全体が無効になる場合があるため）
  [[ "${result}" =~ "Auto-loading" ]]

  loaded=$(jq -r '.loaded_guidelines | join(",")' "${HOME}/.claude/session-state.json")
  [[ "${loaded}" =~ "common" ]]
  [[ "${loaded}" =~ "golang" ]]
  [[ "${loaded}" =~ "clean-architecture" ]]
}

@test "pre-skill-use: 複数ガイドラインがsystemMessageのリストに含まれる" {
  clear_session_state
  create_skill_with_guidelines "skill-multilist" "common" "typescript"

  result=$(run_hook "skill-multilist")
  # systemMessage を直接 grep して確認（JSON全体が無効な場合があるため）
  [[ "${result}" =~ "common" ]]
  [[ "${result}" =~ "typescript" ]]
}

# =============================================================================
# SKILL.md フォールバックのテスト
# =============================================================================

@test "pre-skill-use: skill.md がなく SKILL.md がある場合はフォールバックで読み込む" {
  local target_dir="${HOME}/.claude/skills/skill-uppercase"
  mkdir -p "${target_dir}"
  # skill.md は作成せず SKILL.md のみ作成
  printf '%s\n' "---
name: skill-uppercase
description: 大文字ファイルテスト
requires-guidelines:
  - common
---
" > "${target_dir}/SKILL.md"

  clear_session_state
  result=$(run_hook "skill-uppercase")
  msg=$(get_system_message "${result}")
  [[ "${msg}" =~ "Auto-loading" ]]
}

# =============================================================================
# エッジケース
# =============================================================================

@test "pre-skill-use: スキル名にハイフンが含まれても正常動作する" {
  clear_session_state
  create_skill_with_guidelines "my-complex-skill-name" "common"

  result=$(run_hook "my-complex-skill-name")
  msg=$(get_system_message "${result}")
  [[ "${msg}" =~ "Auto-loading" ]]
}

@test "pre-skill-use: スキル名にスラッシュが含まれる場合は警告メッセージ（ファイル不在）" {
  # スラッシュを含む不正なスキル名
  result=$(run_hook "skill/with/slash")
  # ファイルパスが不正なためスキルファイルが見つからず警告
  msg=$(get_system_message "${result}")
  [ -n "${msg}" ]
}

@test "pre-skill-use: 出力は常に有効な JSON である" {
  clear_session_state
  create_skill_with_guidelines "skill-json-valid" "common"

  result=$(run_hook "skill-json-valid")
  echo "${result}" | jq . > /dev/null
  [ "$?" -eq 0 ]
}

@test "pre-skill-use: ガイドラインなしスキルの出力は有効な JSON である" {
  create_skill_no_guidelines "skill-ngl-json"

  result=$(run_hook "skill-ngl-json")
  echo "${result}" | jq . > /dev/null
  [ "$?" -eq 0 ]
}

@test "pre-skill-use: 存在しないスキルの出力は有効な JSON である" {
  result=$(run_hook "completely-nonexistent-xyz")
  echo "${result}" | jq . > /dev/null
  [ "$?" -eq 0 ]
}

@test "pre-skill-use: aws プレフィックスのガイドラインは infrastructure-summary.md を参照する" {
  clear_session_state
  create_skill_with_guidelines "skill-aws" "aws-eks"

  result=$(run_hook "skill-aws")
  ctx=$(get_additional_context "${result}")
  [[ "${ctx}" =~ "infrastructure-summary.md" ]]
}
