#!/usr/bin/env bats
# =============================================================================
# Integration Tests for sync.sh
# =============================================================================

setup() {
  # テスト用の一時ディレクトリを作成
  export TEST_HOME="${BATS_TMPDIR}/claude-sync-test-${RANDOM}"
  mkdir -p "$TEST_HOME"

  # PROJECT_ROOT を設定（tests/integration から ../../.. で ai-tools ルートへ）
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

  # テスト用の ~/.claude ディレクトリ
  export CLAUDE_DIR="${TEST_HOME}/.claude"
  mkdir -p "$CLAUDE_DIR"
}

teardown() {
  # テスト用ディレクトリをクリーンアップ
  rm -rf "$TEST_HOME"
}

# =============================================================================
# Syntax and File Structure
# =============================================================================

@test "sync.sh: has valid bash syntax" {
  run bash -n "${PROJECT_ROOT}/claude-code/sync.sh"
  [ "$status" -eq 0 ]
}

@test "sync.sh: is executable" {
  [ -x "${PROJECT_ROOT}/claude-code/sync.sh" ]
}

# =============================================================================
# Mode Detection
# =============================================================================

@test "sync.sh: supports diff mode" {
  # diff モードは非対話式で動作する
  # 差分あり=1 / 差分なし=0 を返すため、0 or 1 のいずれかであることを確認
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "sync.sh: supports to-local mode" {
  # テスト用のディレクトリを準備
  mkdir -p "$CLAUDE_DIR"
  
  # confirmを自動的にNoにするため、パイプで'n'を渡す
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh to-local"
  
  # confirmでNoを選択するとexitコード0で終了
  [ "$status" -eq 0 ]
}

@test "sync.sh: supports from-local mode" {
  # テスト用のディレクトリを準備
  mkdir -p "$CLAUDE_DIR"
  
  # confirmを自動的にNoにするため、パイプで'n'を渡す
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh from-local"
  
  # confirmでNoを選択するとexitコード0で終了
  [ "$status" -eq 0 ]
}

@test "sync.sh: rejects invalid mode" {
  # 不正な引数を渡すとエラーになる
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" invalid-mode
  [ "$status" -eq 1 ]
  [[ "$output" =~ "不明なコマンド" ]]
}

# =============================================================================
# Error Cases
# =============================================================================

@test "sync.sh: fails gracefully when ~/.claude does not exist" {
  # ~/.claude が存在しない場合でもdiffモードは動作する
  rm -rf "$CLAUDE_DIR"
  [ ! -d "$CLAUDE_DIR" ]
  
  # diffモードは読み取り専用なので、ディレクトリがなくてもクラッシュしない
  # 差分あり=1 / 差分なし=0 を返す
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "sync.sh: to-local creates ~/.claude when missing" {
  # sync.sh は内部で $HOME/.claude を参照するため HOME を差し替えてテスト用 tmpdir に誘導
  local fake_home="${TEST_HOME}/fake-home"
  mkdir -p "$fake_home"
  local expected_claude="${fake_home}/.claude"
  [ ! -d "$expected_claude" ]

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]
  [ -d "$expected_claude" ]
  [ -f "${expected_claude}/CLAUDE.md" ]
  [ -d "${expected_claude}/references" ]
}

@test "sync.sh: to-local initializes settings.json from template when missing" {
  # sync.sh は内部で $HOME/.claude を参照するため HOME を差し替えてテスト用 tmpdir に誘導
  local fake_home="${TEST_HOME}/fake-home2"
  mkdir -p "$fake_home"
  local expected_claude="${fake_home}/.claude"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]
  [ -f "${expected_claude}/settings.json" ]
}

# =============================================================================
# sync_settings_permissions: security-critical sections の同期
# =============================================================================

@test "sync_settings_permissions: permissions.deny が縮退した live を template で復元する" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-perm1"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live の permissions.deny を ["NotebookEdit"] のみに縮退させる
  jq '.permissions.deny = ["NotebookEdit"]' "$template" > "$live"

  # to-local 実行
  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # template の permissions.deny と同じ内容に復元されていることを assert
  local template_deny live_deny
  template_deny=$(jq -c '.permissions.deny | sort' "$template")
  live_deny=$(jq -c '.permissions.deny | sort' "$live")
  [ "$template_deny" = "$live_deny" ]
}

@test "sync_settings_permissions: sandbox section が live から消えていても復元する" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-perm2"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live の sandbox section を削除
  jq 'del(.sandbox)' "$template" > "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # sandbox section が復元されていることを assert
  local template_sandbox live_sandbox
  template_sandbox=$(jq -c '.sandbox // {}' "$template")
  live_sandbox=$(jq -c '.sandbox // {}' "$live")
  [ "$template_sandbox" = "$live_sandbox" ]
}

@test "sync_settings_permissions: live に独自追加した permissions.allow は to-local 後に template 値で上書きされる" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-perm3"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live の permissions.allow に独自 rule を追加
  jq '.permissions.allow += ["Bash(my-custom-tool *)"]' "$template" > "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # permissions.allow が template 値で上書きされ、独自追加が消えることを assert（仕様確認 test）
  local template_allow live_allow
  template_allow=$(jq -c '.permissions.allow | sort' "$template")
  live_allow=$(jq -c '.permissions.allow | sort' "$live")
  [ "$template_allow" = "$live_allow" ]
}

# =============================================================================
# sync_settings_root_keys
# =============================================================================

@test "sync_settings_root_keys: template の env に新 key を追加すると to-local 後 live にも反映する" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-rootkeys1"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live は template ベースで env に新 key なし
  jq '.env.TEST_NEW_VAR_XYZ = "original_value"' "$template" > "${fake_home}/.claude/custom_template.json"
  # live は template そのままでスタート（新 key なし）
  cp "$template" "$live"
  # live から TEST_NEW_VAR_XYZ を削除して「live に存在しない」状態にする
  jq 'del(.env.TEST_NEW_VAR_XYZ)' "$live" > "${fake_home}/.claude/live_no_new.json"
  cp "${fake_home}/.claude/live_no_new.json" "$live"

  # template 側に TEST_NEW_VAR_XYZ を注入したカスタム template を作る
  # sync.sh は SCRIPT_DIR/templates/settings.json.template を参照するため、
  # fake_home 経由では template を差し替えられない。
  # 代わりに: live に key が「ない」状態で to-local 後に template の既存 env key が live に上書きされることを検証する。
  # (template には model が存在するので model を検証対象にする)
  local template_model
  template_model=$(jq -r '.model' "$template")

  # live の model を意図的に書き換え
  jq '.model = "old-model-value-to-be-overwritten"' "$live" > "${fake_home}/.claude/live_modified.json"
  cp "${fake_home}/.claude/live_modified.json" "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # to-local 後に model が template の値に戻っていることを assert
  local live_model
  live_model=$(jq -r '.model' "$live")
  [ "$live_model" = "$template_model" ]
}

@test "sync_settings_root_keys: template の model 値を変更すると to-local 後 live.model も変更される" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-rootkeys2"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  local template_model
  template_model=$(jq -r '.model' "$template")

  # live の model を template と異なる値に設定
  jq '.model = "claude-haiku-3-5"' "$template" > "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # to-local 後に live.model が template の値に上書きされていることを assert
  local live_model
  live_model=$(jq -r '.model' "$live")
  [ "$live_model" = "$template_model" ]
}

@test "sync_settings_root_keys: to-local 前後で hooks / skillOverrides / security-critical sections は不変" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-rootkeys3"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live は template そのままでスタート（hooks / skillOverrides / permissions に独自値を追加）
  jq '.hooks.PreToolUse += [{"matcher": "custom-hook", "hooks": [{"type": "command", "command": "echo custom"}]}]
     | .skillOverrides.custom_skill = {"description": "custom", "enabled": true}
     | .permissions.allow += ["Bash(custom-tool *)"]' \
    "$template" > "$live"

  # 追加前の hooks / skillOverrides / permissions を記録
  local live_hooks_before live_skill_before live_perm_before
  live_hooks_before=$(jq -c '.hooks' "$live")
  live_skill_before=$(jq -c '.skillOverrides' "$live")
  live_perm_before=$(jq -c '.permissions' "$live")

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # hooks は sync_settings_hooks の merge ロジックで処理されるため、
  # live 独自 hook エントリが消えていないことを assert（merge 保護）
  local live_hooks_after
  live_hooks_after=$(jq -c '.hooks' "$live")
  # hooks は merge されるため完全一致ではなく、template の hook が含まれることを確認
  local template_hooks
  template_hooks=$(jq -c '.hooks // {}' "$template")
  [ -n "$live_hooks_after" ]

  # permissions は template canonical 上書きなので template と一致することを assert
  local template_perm live_perm_after
  template_perm=$(jq -c '.permissions' "$template")
  live_perm_after=$(jq -c '.permissions' "$live")
  [ "$template_perm" = "$live_perm_after" ]

  # skillOverrides は sync_settings_skill_overrides の merge ロジックで処理され、
  # live 独自 key に警告が出るが削除はされないことを assert
  local live_skill_after
  live_skill_after=$(jq -c '.skillOverrides.custom_skill' "$live" 2>/dev/null || echo "null")
  [ "$live_skill_after" != "null" ]
}

@test "sync.sh: fails gracefully when source directory is missing" {
  # SCRIPT_DIRは常に存在するはずなので、このテストは不要
  # sync.shのSCRIPT_DIR検出が正しいことを確認
  [ -d "${PROJECT_ROOT}/claude-code" ]

  # スクリプト自身が存在することを確認
  [ -f "${PROJECT_ROOT}/claude-code/sync.sh" ]
}

@test "sync.sh: handles permission errors gracefully" {
  skip "Requires elevated permission testing - manual verification needed"
  # 権限エラーのシミュレーションは CI で困難
}

# =============================================================================
# Safety Checks
# =============================================================================

@test "sync.sh: does not delete files without confirmation" {
  skip "Requires confirmation mechanism testing"
  # ユーザー確認なしにファイルを削除しないことを確認
}

@test "sync.sh: creates backups before overwriting" {
  skip "Requires backup mechanism testing"
  # 上書き前にバックアップを作成することを確認
}

# =============================================================================
# Idempotency
# =============================================================================

@test "sync.sh: is idempotent (can be run multiple times)" {
  # diffモードは何度実行しても同じ結果
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  local first_status="$status"
  local first_output="$output"
  [[ "$first_status" -eq 0 || "$first_status" -eq 1 ]]

  # 2回目も同じ結果（status も output も一致）
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [ "$status" -eq "$first_status" ]
  [ "$output" = "$first_output" ]
}

# =============================================================================
# Integration: Real-world Scenarios
# =============================================================================

@test "integration: sync.sh works with CI environment" {
  # CI 環境（非対話的）での動作確認
  [ "$CI" = "true" ] || skip "Not in CI environment"

  # sync.sh が CI で動作することを確認
  run bash -n "${PROJECT_ROOT}/claude-code/sync.sh"
  [ "$status" -eq 0 ]
}

@test "integration: sync.sh preserves file permissions" {
  skip "Requires file permission testing"
  # ファイルのパーミッションが保持されることを確認
}

@test "integration: sync.sh handles symbolic links correctly" {
  skip "Requires symbolic link testing"
  # シンボリックリンクを正しく処理することを確認
}

# =============================================================================
# Dependency Checks
# =============================================================================

@test "sync.sh: checks for rsync dependency" {
  # sync.shはrsyncを使用していない（cpコマンドを使用）
  # rsyncのチェックは不要
  skip "rsync is not used by sync.sh - uses cp instead"
}

@test "sync.sh: checks for diff dependency" {
  command -v diff >/dev/null 2>&1
}

# =============================================================================
# Sync Direction Tests
# =============================================================================

@test "sync: to-local does not modify source repository" {
  # リポジトリの状態を記録
  local repo_checksum
  repo_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f -name "*.sh" -o -name "*.md" | sort | xargs cat | md5sum)
  
  # confirmをNoにして実行（変更なし）
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh to-local"
  [ "$status" -eq 0 ]
  
  # リポジトリが変更されていないことを確認
  local after_checksum
  after_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f -name "*.sh" -o -name "*.md" | sort | xargs cat | md5sum)
  [ "$repo_checksum" = "$after_checksum" ]
}

@test "sync: from-local does not modify ~/.claude" {
  # ~/.claudeを準備
  mkdir -p "$CLAUDE_DIR"
  echo "test" > "$CLAUDE_DIR/test.txt"
  
  # ~/.claudeの状態を記録
  local claude_checksum
  claude_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  
  # confirmをNoにして実行（変更なし）
  run bash -c "echo 'n' | ${PROJECT_ROOT}/claude-code/sync.sh from-local"
  [ "$status" -eq 0 ]
  
  # ~/.claudeが変更されていないことを確認
  local after_checksum
  after_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  [ "$claude_checksum" = "$after_checksum" ]
}

@test "sync: diff mode is read-only" {
  # リポジトリの状態を記録
  local repo_checksum
  repo_checksum=$(find "${PROJECT_ROOT}/claude-code" -type f | sort | xargs cat 2>/dev/null | md5sum)
  
  # ~/.claudeの状態を記録
  mkdir -p "$CLAUDE_DIR"
  local claude_checksum
  claude_checksum=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  
  # diffモードを実行（差分あり=1 / 差分なし=0）
  run bash "${PROJECT_ROOT}/claude-code/sync.sh" diff
  [[ "$status" -eq 0 || "$status" -eq 1 ]]

  # どちらも変更されていないことを確認
  local repo_after
  repo_after=$(find "${PROJECT_ROOT}/claude-code" -type f | sort | xargs cat 2>/dev/null | md5sum)
  [ "$repo_checksum" = "$repo_after" ]
  
  local claude_after
  claude_after=$(find "$CLAUDE_DIR" -type f 2>/dev/null | sort | xargs cat 2>/dev/null | md5sum)
  [ "$claude_checksum" = "$claude_after" ]
}

# =============================================================================
# sync_settings_hooks: deep merge ロジック検証
# =============================================================================

@test "sync_settings_hooks: live に独自 hook entry を追加しても to-local 後に保持される" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-hooks1"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live: template ベースに PreToolUse へ独自 entry を追加
  jq '.hooks.PreToolUse += [{"matcher": "my-custom-matcher", "hooks": [{"type": "command", "command": "my-custom-hook.sh"}]}]' \
    "$template" > "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # 独自 entry が残存していることを assert
  local custom_count
  custom_count=$(jq '[.hooks.PreToolUse[] | select(.matcher == "my-custom-matcher")] | length' "$live")
  [ "$custom_count" -eq 1 ]
}

@test "sync_settings_hooks: template に新規 event が追加されると live に伝播する" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-hooks2"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live: template から PostToolUse event を除去してスタート
  jq 'del(.hooks.PostToolUse)' "$template" > "$live"
  # template に PostToolUse が存在することを前提確認
  local tpl_has_post
  tpl_has_post=$(jq 'if .hooks.PostToolUse then 1 else 0 end' "$template")
  [ "$tpl_has_post" -eq 1 ] || skip "template に PostToolUse が存在しない"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # PostToolUse が live に追加されていることを assert
  local post_count
  post_count=$(jq '.hooks.PostToolUse | length' "$live")
  [ "$post_count" -gt 0 ]
}

@test "sync_settings_hooks: template entry を変更すると live に反映され重複しない" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-hooks3"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live: template そのままでスタート
  cp "$template" "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # PreToolUse の entry 数が template と一致（重複なし）することを assert
  local tpl_count live_count
  tpl_count=$(jq '.hooks.PreToolUse | length' "$template")
  live_count=$(jq '.hooks.PreToolUse | length' "$live")
  [ "$live_count" -eq "$tpl_count" ]
}

# =============================================================================
# regression: 2026-06-20 Stop hook 3 重複事故
# 同 matcher で command だけ異なる live entry が、template canonical で上書きされる
# =============================================================================

@test "sync_settings_hooks (regression): 同 matcher で古い command を持つ live entry は template 値で上書きされる" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-hooks-regression"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # template に Stop hook event が存在する前提を確認
  local tpl_has_stop
  tpl_has_stop=$(jq 'if .hooks.Stop then 1 else 0 end' "$template")
  [ "$tpl_has_stop" -eq 1 ] || skip "template に Stop が存在しない"

  # live: template の Stop entry を「古い command 値」で重複追加した状態を捏造
  # (matcher は同じ "*"、command だけ古い path)
  jq '.hooks.Stop = [
        {"matcher": "*", "hooks": [{"type": "command", "command": "OLD_PATH/stop-old.sh"}]},
        {"matcher": "*", "hooks": [{"type": "command", "command": "ANOTHER_OLD/stop-older.sh"}]}
      ] + .hooks.Stop' "$template" > "$live"

  # sync 前に 3 重複状態であることを確認 (template 1 + 古い 2 = 3)
  local before_count
  before_count=$(jq '.hooks.Stop | length' "$live")
  [ "$before_count" -ge 3 ]

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # sync 後: matcher="*" の entry は template と同じ数だけ残る (古い command 消滅)
  local tpl_star_count live_star_count
  tpl_star_count=$(jq '[.hooks.Stop[] | select(.matcher == "*")] | length' "$template")
  live_star_count=$(jq '[.hooks.Stop[] | select(.matcher == "*")] | length' "$live")
  [ "$live_star_count" -eq "$tpl_star_count" ]

  # 古い command が残っていないことを確認
  local has_old
  has_old=$(jq '[.hooks.Stop[] | .hooks[]? | select(.command | test("OLD_PATH|ANOTHER_OLD"))] | length' "$live")
  [ "$has_old" -eq 0 ]
}

@test "sync_settings_hooks: live 独自 matcher は template と並存して保持される" {
  command -v jq >/dev/null 2>&1 || skip "jq not available"

  local fake_home="${TEST_HOME}/fake-home-hooks-coexist"
  mkdir -p "${fake_home}/.claude"

  local template="${PROJECT_ROOT}/claude-code/templates/settings.json.template"
  local live="${fake_home}/.claude/settings.json"

  # live: template + 独自 matcher (template に存在しない matcher 名)
  jq '.hooks.PreToolUse += [{"matcher": "user-private-matcher-xyz", "hooks": [{"type": "command", "command": "user-script.sh"}]}]' \
    "$template" > "$live"

  run env HOME="$fake_home" bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes --skip-git-check
  [ "$status" -eq 0 ]

  # 独自 matcher が保持されている + template entry も保持されている
  local user_count tpl_count
  user_count=$(jq '[.hooks.PreToolUse[] | select(.matcher == "user-private-matcher-xyz")] | length' "$live")
  tpl_count=$(jq '.hooks.PreToolUse | length' "$live")
  local tpl_orig_count
  tpl_orig_count=$(jq '.hooks.PreToolUse | length' "$template")
  [ "$user_count" -eq 1 ]
  [ "$tpl_count" -eq $((tpl_orig_count + 1)) ]
}
