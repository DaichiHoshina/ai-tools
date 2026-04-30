#!/usr/bin/env bats
# =============================================================================
# BATS Tests for env-configurator.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/env-configurator.sh"
  export COMMON_LIB="${PROJECT_ROOT}/lib/common.sh"
  export TEST_TMPDIR="$(mktemp -d)"
  export HOME="${TEST_TMPDIR}/home"
  export ENV_FILE="${HOME}/.env"
  export SCRIPT_DIR="${TEST_TMPDIR}/scripts"
  mkdir -p "${HOME}"
  mkdir -p "${SCRIPT_DIR}/templates"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  unset TEST_TMPDIR HOME ENV_FILE SCRIPT_DIR
}

# Mock function: common.sh に依存するため最小スタブ提供
# common.sh から実関数を取得するため、mock 関数は削除（source で読み込み）

# =============================================================================
# update_env_var テスト
# =============================================================================

@test "update_env_var: 新しい KEY を .env に追加" {
  touch "${ENV_FILE}"
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && update_env_var 'TEST_KEY' 'test_value'"
  [ "$status" -eq 0 ]
  grep -q "^TEST_KEY=test_value$" "${ENV_FILE}"
}

@test "update_env_var: 既存 KEY を更新" {
  echo "TEST_KEY=old_value" > "${ENV_FILE}"
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && update_env_var 'TEST_KEY' 'new_value'"
  [ "$status" -eq 0 ]
  grep -q "^TEST_KEY=new_value$" "${ENV_FILE}"
  ! grep -q "old_value" "${ENV_FILE}"
}

@test "update_env_var: 複数キーが共存できる" {
  echo "KEY1=value1" > "${ENV_FILE}"
  bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && update_env_var 'KEY2' 'value2'"
  [ $(wc -l < "${ENV_FILE}") -eq 2 ]
  grep -q "^KEY1=value1$" "${ENV_FILE}"
  grep -q "^KEY2=value2$" "${ENV_FILE}"
}

@test "update_env_var: 値に特殊文字が含まれても動く" {
  touch "${ENV_FILE}"
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && update_env_var 'API_URL' 'https://example.com/api?key=value&id=123'"
  [ "$status" -eq 0 ]
  grep -q "API_URL=https://example.com" "${ENV_FILE}"
}

# =============================================================================
# generate_settings_json テスト
# =============================================================================

@test "generate_settings_json: settings.json.template があれば生成" {
  cat > "${SCRIPT_DIR}/templates/settings.json.template" << 'EOF'
{
  "home": "__HOME__",
  "nodePath": "__NODE_PATH__"
}
EOF
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && generate_settings_json" 2>/dev/null
  [ -f "${CLAUDE_DIR}/settings.json" ]
  grep -q "${HOME}" "${CLAUDE_DIR}/settings.json"
}

@test "generate_settings_json: template がなければ exit 1" {
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && generate_settings_json"
  [ "$status" -eq 1 ]
}

@test "generate_settings_json: __HOME__ を実際のパスに置換" {
  cat > "${SCRIPT_DIR}/templates/settings.json.template" << 'EOF'
{
  "path": "__HOME__/test"
}
EOF
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && generate_settings_json" 2>/dev/null
  grep -q "${HOME}/test" "${CLAUDE_DIR}/settings.json"
}

# =============================================================================
# configure_settings_json テスト
# =============================================================================

@test "configure_settings_json: settings.json が存在しなければ生成" {
  cat > "${SCRIPT_DIR}/templates/settings.json.template" << 'EOF'
{"test": "__HOME__"}
EOF
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && configure_settings_json" 2>/dev/null
  [ -f "${CLAUDE_DIR}/settings.json" ]
}

@test "configure_settings_json: 既存 settings.json → generate_settings_json を呼ぶ" {
  cat > "${SCRIPT_DIR}/templates/settings.json.template" << 'EOF'
{"new": "config"}
EOF
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  echo '{"old": "config"}' > "${CLAUDE_DIR}/settings.json"

  # 実関数を呼び出し - confirm は yes (0) を返すと仮定
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && configure_settings_json" <<< "y" 2>/dev/null
  [ "$status" -eq 0 ]
  # settings.json が新しい内容で更新されている
  grep -q '"new"' "${CLAUDE_DIR}/settings.json"
}

# =============================================================================
# setup_env_file テスト（read 相当のテスト）
# =============================================================================

@test "setup_env_file: .env が既存なら update 関数が呼ばれる（READ TEST）" {
  touch "${ENV_FILE}"
  # setup_env_file は confirm() の戻り値に依存
  # confirm が 0 を返す（yes）と仮定して、setup_env_interactive の入力なしでも成功
  run bash -c "source '$COMMON_LIB' && source '$LIB_FILE' && setup_env_file" < /dev/null 2>&1
  [ "$status" -eq 0 ]
}

@test "setup_env_file: .env がなければ template をコピー + setup_env_interactive 呼ぶ" {
  cat > "${SCRIPT_DIR}/templates/.env.example" << 'TMPL'
EXAMPLE_KEY=example_value
TMPL
  # env ファイルは存在しない
  [ ! -f "${ENV_FILE}" ]

  # setup_env_interactive が read で EOF に遭遇しないよう、
  # 10 個の read に空行で応答（改行のみで全スキップ）
  run bash -c "export SCRIPT_DIR='${SCRIPT_DIR}' && export ENV_FILE='${ENV_FILE}' && source '$COMMON_LIB' && source '$LIB_FILE' && setup_env_file" << 'STDIN'










STDIN
  [ "$status" -eq 0 ]
  # template がコピーされている
  [ -f "${ENV_FILE}" ]
}

# =============================================================================
# setup_env_interactive テスト（read のみ）
# =============================================================================

@test "setup_env_interactive: stdin=empty なら何も追加されない" {
  # .env を作成して初期化（変更前）
  touch "${ENV_FILE}"
  local size_before=$(wc -c < "${ENV_FILE}")

  # setup_env_interactive に 10 個の空行を供給（read は EOF ではなく空文字を返す）
  run bash -c "export ENV_FILE='${ENV_FILE}' && source '$COMMON_LIB' && source '$LIB_FILE' && setup_env_interactive" << 'STDIN'










STDIN
  [ "$status" -eq 0 ]

  # .env サイズが変わらないことを確認（何も追加されない）
  local size_after=$(wc -c < "${ENV_FILE}")
  [ "$size_after" -eq "$size_before" ]
}

@test "setup_env_interactive: stdin で値を入力すると update_env_var が呼ばれる" {
  touch "${ENV_FILE}"
  # stdin で各質問に回答（改行で区切る）
  run bash -c "export ENV_FILE='${ENV_FILE}' && source '$COMMON_LIB' && source '$LIB_FILE' && setup_env_interactive" << 'EOF' 2>/dev/null
https://gitlab.example.com/api/v4

https://confluence.example.com

user@example.com

https://jira.example.com

user@jira.com

sk-1234567890

/opt/serena
EOF
  [ "$status" -eq 0 ]
  # GITLAB_API_URL が .env に記録されることを確認（|| true なし）
  grep -q "GITLAB_API_URL" "${ENV_FILE}"
}
