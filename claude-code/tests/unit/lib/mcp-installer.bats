#!/usr/bin/env bats
# =============================================================================
# BATS Tests for mcp-installer.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../" && pwd)"
  export LIB_DIR="${PROJECT_ROOT}/claude-code/lib"
  export LIB_FILE="${LIB_DIR}/mcp-installer.sh"

  # PATH 退避（テスト内で stub で上書き）
  export ORIG_PATH="$PATH"
}

teardown() {
  # PATH 復元
  export PATH="$ORIG_PATH"
}

# =============================================================================
# generate_gitlab_mcp_sh テスト
# =============================================================================

@test "generate_gitlab_mcp_sh: template読み込みと変数置換、ファイル生成" {
  # stub tmpdir を PATH に追加（元の PATH も後ろに追加）
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  # stub: chmod コマンド（ファイル権限を記録するだけ）
  cat > "${stub_dir}/chmod" << 'EOF'
#!/bin/bash
exec /bin/chmod "$@"
EOF
  chmod +x "${stub_dir}/chmod"

  # テスト用の HOME/CLAUDE_DIR
  local test_home
  test_home=$(mktemp -d)

  # 関数実呼び出し
  run bash -c "
    export HOME='${test_home}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    export CLAUDE_DIR='${test_home}/.claude'
    export GITLAB_API_URL='https://gitlab.example.com/api/v4'
    export PATH='${stub_dir}:${ORIG_PATH}'
    mkdir -p '${test_home}/.claude'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_gitlab_mcp_sh
  "

  [ "$status" -eq 0 ]
  # 出力に print_success の結果が含まれることを確認
  [[ "$output" =~ "gitlab-mcp.sh" ]]

  # 生成されたファイルが存在
  [ -f "${test_home}/.claude/gitlab-mcp.sh" ]

  # テンプレート変数が置換されているか確認
  grep -q "GITLAB_API_URL=" "${test_home}/.claude/gitlab-mcp.sh"

  # cleanup
  rm -rf "${stub_dir}" "${test_home}"
}

@test "generate_gitlab_mcp_sh: デフォルト GITLAB_API_URL が使用される" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  cat > "${stub_dir}/chmod" << 'EOF'
#!/bin/bash
exec /bin/chmod "$@"
EOF
  chmod +x "${stub_dir}/chmod"

  local test_home
  test_home=$(mktemp -d)

  # GITLAB_API_URL を未設定（デフォルト値を使用）
  run bash -c "
    export HOME='${test_home}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    export CLAUDE_DIR='${test_home}/.claude'
    unset GITLAB_API_URL
    export PATH='${stub_dir}:${ORIG_PATH}'
    mkdir -p '${test_home}/.claude'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_gitlab_mcp_sh
  "

  [ "$status" -eq 0 ]
  [ -f "${test_home}/.claude/gitlab-mcp.sh" ]

  # デフォルト値（https://gitlab.example.com/api/v4）が含まれる
  grep -q "https://gitlab.example.com/api/v4" "${test_home}/.claude/gitlab-mcp.sh"

  rm -rf "${stub_dir}" "${test_home}"
}

@test "generate_gitlab_mcp_sh: CLAUDE_DIR デフォルトは ~/.claude" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  cat > "${stub_dir}/chmod" << 'EOF'
#!/bin/bash
exec /bin/chmod "$@"
EOF
  chmod +x "${stub_dir}/chmod"

  local test_home
  test_home=$(mktemp -d)

  # CLAUDE_DIR を未設定（デフォルト ~/.claude）
  run bash -c "
    export HOME='${test_home}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    unset CLAUDE_DIR
    export GITLAB_API_URL='https://custom.url'
    export PATH='${stub_dir}:${ORIG_PATH}'
    mkdir -p '${test_home}/.claude'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_gitlab_mcp_sh
  "

  [ "$status" -eq 0 ]

  # デフォルト ~/.claude に生成されている
  [ -f "${test_home}/.claude/gitlab-mcp.sh" ]

  rm -rf "${stub_dir}" "${test_home}"
}

# =============================================================================
# generate_mcp_json テスト
# =============================================================================

@test "generate_mcp_json: テンプレート読み込み＆envsubst で PROJECT_ROOT/SERENA_PATH を置換" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  # stub: envsubst
  cat > "${stub_dir}/envsubst" << 'EOF'
#!/bin/bash
# 簡易版：${VAR} パターンを replace
sed 's|\${SERENA_PATH}|'"$SERENA_PATH"'|g' | sed 's|\${PROJECT_ROOT}|'"$PROJECT_ROOT"'|g'
EOF
  chmod +x "${stub_dir}/envsubst"

  local test_project_root
  test_project_root=$(mktemp -d)
  local serena_path="/home/user/serena"

  run bash -c "
    export SERENA_PATH='${serena_path}'
    export PROJECT_ROOT='${test_project_root}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_mcp_json '${test_project_root}'
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ "PROJECT_ROOT=${test_project_root}" ]]
  [[ "$output" =~ "SERENA_PATH=${serena_path}" ]]

  # .mcp.json が生成される
  [ -f "${test_project_root}/.mcp.json" ]

  rm -rf "${stub_dir}" "${test_project_root}"
}

@test "generate_mcp_json: テンプレートが見つからない場合、warning で return" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  cat > "${stub_dir}/envsubst" << 'EOF'
#!/bin/bash
EOF
  chmod +x "${stub_dir}/envsubst"

  local test_project_root
  test_project_root=$(mktemp -d)
  local fake_script_dir
  fake_script_dir=$(mktemp -d)

  # テンプレートが存在しないディレクトリを SCRIPT_DIR に指定
  run bash -c "
    export SCRIPT_DIR='${fake_script_dir}'
    export PROJECT_ROOT='${test_project_root}'
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_mcp_json '${test_project_root}'
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ "見つかりません" ]]

  # .mcp.json は生成されない
  [ ! -f "${test_project_root}/.mcp.json" ]

  rm -rf "${stub_dir}" "${test_project_root}" "${fake_script_dir}"
}

@test "generate_mcp_json: SERENA_PATH が指定されていない場合、common locations を検索" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  cat > "${stub_dir}/envsubst" << 'EOF'
#!/bin/bash
sed 's|\${SERENA_PATH}|'"$SERENA_PATH"'|g' | sed 's|\${PROJECT_ROOT}|'"$PROJECT_ROOT"'|g'
EOF
  chmod +x "${stub_dir}/envsubst"

  local test_home
  test_home=$(mktemp -d)
  local test_project_root
  test_project_root=$(mktemp -d)

  # serena パスを common location に作成
  mkdir -p "${test_home}/serena"

  run bash -c "
    export HOME='${test_home}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    export PROJECT_ROOT='${test_project_root}'
    unset SERENA_PATH
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_mcp_json '${test_project_root}'
  "

  [ "$status" -eq 0 ]
  # 出力に検出されたパスが含まれる
  [[ "$output" =~ "${test_home}/serena" ]]

  rm -rf "${stub_dir}" "${test_home}" "${test_project_root}"
}

@test "generate_mcp_json: SERENA_PATH が見つからない場合、デフォルト値を使用" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  cat > "${stub_dir}/envsubst" << 'EOF'
#!/bin/bash
sed 's|\${SERENA_PATH}|'"$SERENA_PATH"'|g' | sed 's|\${PROJECT_ROOT}|'"$PROJECT_ROOT"'|g'
EOF
  chmod +x "${stub_dir}/envsubst"

  local test_home
  test_home=$(mktemp -d)
  local test_project_root
  test_project_root=$(mktemp -d)

  run bash -c "
    export HOME='${test_home}'
    export SCRIPT_DIR='${LIB_DIR}/..'
    export PROJECT_ROOT='${test_project_root}'
    unset SERENA_PATH
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'
    generate_mcp_json '${test_project_root}'
  "

  [ "$status" -eq 0 ]
  # warning が出力される
  [[ "$output" =~ "見つかりません" ]]
  # デフォルト値が使用される
  [[ "$output" =~ "/path/to/serena" ]]

  rm -rf "${stub_dir}" "${test_home}" "${test_project_root}"
}

# =============================================================================
# install_mcp_servers テスト
# =============================================================================

@test "install_mcp_servers: confirm で yes → npm install を実行" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  # stub: npm（実行ログを記録）
  cat > "${stub_dir}/npm" << 'EOF'
#!/bin/bash
echo "npm $@" > "$stub_dir/npm.log"
exit 0
EOF
  chmod +x "${stub_dir}/npm"

  run bash -c "
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'

    # common.sh 読み込み後に confirm をoverride
    confirm() {
      return 0  # success（yes）
    }

    install_mcp_servers
  "

  [ "$status" -eq 0 ]
  [[ "$output" =~ "インストール完了" ]]

  rm -rf "${stub_dir}"
}

@test "install_mcp_servers: confirm で no → npm install をスキップ" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  # stub: npm（呼ばれないはず）
  cat > "${stub_dir}/npm" << 'EOF'
#!/bin/bash
echo "npm $@" > "$stub_dir/npm.log"
EOF
  chmod +x "${stub_dir}/npm"

  run bash -c "
    export PATH='${stub_dir}:${ORIG_PATH}'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'

    # common.sh 読み込み後に confirm をoverride
    confirm() {
      return 1  # fail（no）
    }

    install_mcp_servers
  "

  [ "$status" -eq 0 ]
  # npm が呼ばれていない（npm.log が存在しない）
  [ ! -f "${stub_dir}/npm.log" ]

  rm -rf "${stub_dir}"
}

@test "install_mcp_servers: npm install に複数パッケージが含まれる" {
  local stub_dir
  stub_dir=$(mktemp -d)
  export PATH="${stub_dir}:${ORIG_PATH}"

  # stub: npm
  cat > "${stub_dir}/npm" << 'EOF'
#!/bin/bash
echo "$@" > "${npm_log_path}"
exit 0
EOF
  chmod +x "${stub_dir}/npm"

  run bash -c "
    export PATH='${stub_dir}:${ORIG_PATH}'
    export npm_log_path='${stub_dir}/npm.log'
    source '${LIB_DIR}/common.sh'
    source '$LIB_FILE'

    # common.sh 読み込み後に confirm をoverride
    confirm() {
      return 0
    }

    install_mcp_servers
  "

  [ "$status" -eq 0 ]

  # npm パッケージが含まれているか確認
  [ -f "${stub_dir}/npm.log" ]
  grep -q "mcp-confluence-server" "${stub_dir}/npm.log"
  grep -q "mcp-jira-server" "${stub_dir}/npm.log"
  grep -q "@anthropic-ai/claude-code" "${stub_dir}/npm.log"

  rm -rf "${stub_dir}"
}
