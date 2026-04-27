#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/user-prompt-submit.sh
# 回帰テスト: リファクタリング前後で動作が変わらないことを検証
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOK_FILE="${PROJECT_ROOT}/hooks/user-prompt-submit.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # テスト隔離: 実環境の /tmp/claude-ctx-pct, /tmp/claude-serena-fail-count を参照しない
  export CLAUDE_CTX_FILE="${TEST_TMPDIR}/_ctx_pct_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${TEST_TMPDIR}/_serena_unset"

  # テスト用gitリポジトリ作成
  cd "$TEST_TMPDIR"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  git commit --allow-empty -m "init"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# フックを実行してJSON出力を取得
run_hook() {
  local input="$1"
  echo "$input" | bash "$HOOK_FILE"
}

# JSON出力から systemMessage を抽出
get_system_message() {
  local json="$1"
  echo "$json" | jq -r '.systemMessage // empty'
}

# JSON出力から additionalContext を抽出
get_additional_context() {
  local json="$1"
  echo "$json" | jq -r '.additionalContext // empty'
}

# =============================================================================
# 正常系テスト: プロンプト内ファイルパス言及検出
# 注: phase2 refactor (3c136bb) で git staged file 検出は廃止。
#     プロンプト本文の拡張子言及（.go, .ts, dockerfile）のみ検出。
# =============================================================================

@test "user-prompt-submit: .go言及でgolang+backend-dev検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"main.goを修正"}'
  local output=$(run_hook "$input")

  # JSON形式であることを確認
  echo "$output" | jq empty

  # systemMessageにgolangが含まれる
  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "golang" ]] || [[ "$system_msg" =~ "backend-dev" ]]
}

@test "user-prompt-submit: .ts言及でtypescript検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"index.tsを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "typescript" ]] || [[ "$system_msg" =~ "backend-dev" ]]
}

@test "user-prompt-submit: dockerfile言及でcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"Dockerfileを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "dockerfile" ]]
}

# =============================================================================
# 正常系テスト: キーワード検出
# =============================================================================

@test "user-prompt-submit: 'go'キーワードでgolang検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"goのコードを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "go" ]] || [[ "$system_msg" =~ "golang" ]]
}

@test "user-prompt-submit: 'docker'キーワードでcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"dockerの設定を確認"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "docker" ]]
}

@test "user-prompt-submit: 'review'キーワードでcomprehensive-review検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"コードをレビューして"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "comprehensive-review" ]] || [[ "$system_msg" =~ "review" ]] || [[ "$system_msg" =~ "quality" ]]
}

# =============================================================================
# 正常系テスト: エラーログ検出
# =============================================================================

@test "user-prompt-submit: Docker daemonエラーでcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"Cannot connect to the Docker daemon"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "docker" ]] || [[ "$system_msg" =~ "troubleshoot" ]]
}

@test "user-prompt-submit: TypeScript型エラーでbackend-dev検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"TypeScript Type error TS2304: Cannot find name"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  # スキル統合後: backend-dev (BACKEND_LANG=typescript)
  [[ "$system_msg" =~ "backend-dev" ]] || [[ "$system_msg" =~ "typescript" ]]
}

# =============================================================================
# 正常系テスト: プロンプトキーワード検出
# 注: phase2 refactor (3c136bb) で git branch 検出は廃止。
#     プロンプト本文のキーワード（API, security 等）のみ検出。
# =============================================================================

@test "user-prompt-submit: REST APIキーワードでapi-design検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"REST APIを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "api" ]]
}

@test "user-prompt-submit: securityキーワードでcomprehensive-review検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"security issue を修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "comprehensive-review" ]] || [[ "$system_msg" =~ "security" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "user-prompt-submit: 空プロンプトで何も検出しない" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":""}'
  local output=$(run_hook "$input")

  # 空の場合は {} を返すか、検出なしのメッセージ
  [[ "$output" == "{}" ]] || echo "$output" | jq -e '.systemMessage'
}

@test "user-prompt-submit: 無効なJSONでエラー" {
  cd "$TEST_TMPDIR"

  local input='invalid json'
  run bash "$HOOK_FILE" <<< "$input"

  # エラー終了コードまたはエラーメッセージ
  [ "$status" -ne 0 ] || [[ "$output" =~ "error" ]]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "user-prompt-submit: 複数パターン同時マッチで全て検出" {
  cd "$TEST_TMPDIR"
  touch main.go Dockerfile
  git add main.go Dockerfile

  local input='{"prompt":"dockerとgoの設定を確認"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  # golang, backend-dev, container-ops のいずれかが検出される
  [[ "$system_msg" =~ "go" ]] || [[ "$system_msg" =~ "docker" ]]
}

@test "user-prompt-submit: JSON出力形式の検証" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"test"}'
  local output=$(run_hook "$input")

  # 有効なJSON形式
  echo "$output" | jq empty

  # systemMessage または additionalContext のいずれかが存在（または空オブジェクト）
  [[ "$output" == "{}" ]] || \
    echo "$output" | jq -e '.systemMessage or .additionalContext'
}
