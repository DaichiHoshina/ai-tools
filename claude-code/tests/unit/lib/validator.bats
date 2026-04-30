#!/usr/bin/env bats
# =============================================================================
# BATS Tests for validator.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/validator.sh"
  export COMMON_LIB="${PROJECT_ROOT}/lib/common.sh"
  export TEST_TMPDIR="$(mktemp -d)"
  export HOME="${TEST_TMPDIR}/home"
  export ORIG_PATH="${PATH}"
  export PATH="${TEST_TMPDIR}/bin:${PATH}"
  mkdir -p "${HOME}/.claude"
  mkdir -p "${TEST_TMPDIR}/bin"
  export SCRIPT_DIR="${TEST_TMPDIR}/scripts"
  mkdir -p "${SCRIPT_DIR}"
}

teardown() {
  rm -rf "${TEST_TMPDIR}"
  export PATH="${ORIG_PATH}"
  unset TEST_TMPDIR HOME ORIG_PATH SCRIPT_DIR
}

# =============================================================================
# check_prerequisites テスト
# =============================================================================

@test "check_prerequisites: node と npx が存在 → SUCCESS" {
  # stub: node と npx を PATH に配置
  cat > "${TEST_TMPDIR}/bin/node" << 'EOF'
#!/bin/bash
echo "v16.0.0"
EOF
  chmod +x "${TEST_TMPDIR}/bin/node"

  cat > "${TEST_TMPDIR}/bin/npx" << 'EOF'
#!/bin/bash
true
EOF
  chmod +x "${TEST_TMPDIR}/bin/npx"

  run bash -c "PATH='${TEST_TMPDIR}/bin:${ORIG_PATH}' source '$COMMON_LIB' && source '$LIB_FILE' && check_prerequisites" 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "前提条件のチェック完了" ]]
}

@test "check_prerequisites: node が見つからない場合をテスト（PATH 制限）" {
  # npx のみ配置、node なし
  cat > "${TEST_TMPDIR}/bin/npx" << 'EOF'
#!/bin/bash
true
EOF
  chmod +x "${TEST_TMPDIR}/bin/npx"

  # PATH を制限してテスト - node が見つからないので exit 1
  # 標準的なコマンド PATH (/usr/bin など) を含めて基本的なコマンドは利用可能にする
  run bash -c "export PATH='${TEST_TMPDIR}/bin:/usr/bin:/bin:/usr/local/bin' && source '$COMMON_LIB' && source '$LIB_FILE' && check_prerequisites" 2>&1
  [ "$status" -eq 1 ]
  [[ "$output" =~ "node" ]]
}

@test "check_prerequisites: npx が見つからない場合をテスト（PATH 制限）" {
  # node のみ配置、npx なし
  cat > "${TEST_TMPDIR}/bin/node" << 'EOF'
#!/bin/bash
echo "v16.0.0"
EOF
  chmod +x "${TEST_TMPDIR}/bin/node"

  # PATH を制限してテスト - npx が見つからないので exit 1
  # 標準的なコマンド PATH (/usr/bin など) を含めて基本的なコマンドは利用可能にする
  run bash -c "export PATH='${TEST_TMPDIR}/bin:/usr/bin:/bin:/usr/local/bin' && source '$COMMON_LIB' && source '$LIB_FILE' && check_prerequisites" 2>&1
  [ "$status" -eq 1 ]
  [[ "$output" =~ "npx" ]]
}

# =============================================================================
# verify_installation テスト
# =============================================================================

@test "verify_installation: 全ファイル存在 → success" {
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"/{guidelines,scripts,commands,agents,skills}

  # 必須ファイルを作成
  touch "${CLAUDE_DIR}/settings.json"
  touch "${CLAUDE_DIR}/CLAUDE.md"
  touch "${CLAUDE_DIR}/statusline.js"
  touch "${SCRIPT_DIR}/.mcp.json"

  run bash -c "CLAUDE_DIR='${CLAUDE_DIR}' SCRIPT_DIR='${SCRIPT_DIR}' source '$COMMON_LIB' && source '$LIB_FILE' && verify_installation" 2>&1
  [ "$status" -eq 0 ]
}

@test "verify_installation: settings.json がない → 出力に警告" {
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"
  # settings.json なし
  touch "${CLAUDE_DIR}/CLAUDE.md"
  touch "${CLAUDE_DIR}/statusline.js"

  run bash -c "CLAUDE_DIR='${CLAUDE_DIR}' SCRIPT_DIR='${SCRIPT_DIR}' source '$COMMON_LIB' && source '$LIB_FILE' && verify_installation" 2>&1
  [[ "$output" =~ "settings.json" ]]
}

@test "verify_installation: ディレクトリが存在" {
  export CLAUDE_DIR="${HOME}/.claude"
  mkdir -p "${CLAUDE_DIR}"/{guidelines,scripts,commands,agents,skills}
  touch "${CLAUDE_DIR}/settings.json"
  touch "${CLAUDE_DIR}/CLAUDE.md"
  touch "${CLAUDE_DIR}/statusline.js"

  run bash -c "CLAUDE_DIR='${CLAUDE_DIR}' SCRIPT_DIR='${SCRIPT_DIR}' source '$COMMON_LIB' && source '$LIB_FILE' && verify_installation" 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" =~ "guidelines" ]]
}
