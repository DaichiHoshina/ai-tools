#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-keywords.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-keywords.sh"

  # キャッシュをクリア（テスト間の干渉を防ぐ）
  rm -f "${HOME}/.claude/cache/keyword-patterns.json"
}

# =============================================================================
# ヘルパー関数: JSON出力形式でテスト
# =============================================================================

# detect_from_keywords を呼び出してJSON形式で結果を返す
run_detect_from_keywords() {
  local prompt="$1"
  PROMPT_ARG="$prompt" bash -c '
    source "$LIB_FILE"
    declare -A langs skills
    context=""
    # プロンプトを小文字化（detect_from_keywordsの第1引数はprompt_lower）
    prompt_lower=$(echo "$PROMPT_ARG" | tr "[:upper:]" "[:lower:]")
    detect_from_keywords "$prompt_lower" langs skills context

    # JSON形式で出力
    printf "{\"langs\":["
    first=1
    for lang in "${!langs[@]}"; do
      [ $first -eq 0 ] && printf ","
      printf "\"%s\"" "$lang"
      first=0
    done
    printf "],\"skills\":["
    first=1
    for skill in "${!skills[@]}"; do
      [ $first -eq 0 ] && printf ","
      printf "\"%s\"" "$skill"
      first=0
    done
    printf "],\"context\":\"%s\"}" "$context"
  '
}

# =============================================================================
# 正常系テスト: Go/Golang検出
# =============================================================================

@test "detect-from-keywords: detects golang from 'go' keyword" {
  run run_detect_from_keywords 'goのコードを修正'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_golang=$(echo "$output" | jq '.langs | contains(["golang"])')
  local has_backend=$(echo "$output" | jq '.skills | map(select(. == "backend-dev" or . == "go-backend")) | length > 0')
  [ "$has_golang" = "true" ]
  [ "$has_backend" = "true" ]
}

@test "detect-from-keywords: detects golang from 'golang' keyword" {
  run run_detect_from_keywords 'golang backend implementation'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_golang=$(echo "$output" | jq '.langs | contains(["golang"])')
  local has_backend=$(echo "$output" | jq '.skills | map(select(. == "backend-dev" or . == "go-backend")) | length > 0')
  [ "$has_golang" = "true" ]
  [ "$has_backend" = "true" ]
}

# =============================================================================
# 正常系テスト: TypeScript検出
# =============================================================================

@test "detect-from-keywords: detects typescript from 'typescript' keyword" {
  run run_detect_from_keywords 'typescriptのコードレビュー'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_typescript=$(echo "$output" | jq '.langs | contains(["typescript"])')
  local has_backend=$(echo "$output" | jq '.skills | map(select(. == "backend-dev" or . == "typescript-backend")) | length > 0')
  [ "$has_typescript" = "true" ]
  [ "$has_backend" = "true" ]
}

# =============================================================================
# 正常系テスト: React検出
# =============================================================================

@test "detect-from-keywords: detects react from 'react' keyword" {
  run run_detect_from_keywords 'reactコンポーネント作成'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_react=$(echo "$output" | jq '.langs | contains(["react"])')
  local has_practices=$(echo "$output" | jq '.skills | contains(["react-best-practices"])')
  [ "$has_react" = "true" ]
  [ "$has_practices" = "true" ]
}

# =============================================================================
# 正常系テスト: Docker検出
# =============================================================================

@test "detect-from-keywords: detects docker from 'docker' keyword" {
  run run_detect_from_keywords 'dockerの設定を確認'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops" or . == "dockerfile-best-practices")) | length > 0')
  [ "$has_docker" = "true" ]
}

# =============================================================================
# 正常系テスト: レビュー系スキル検出
# =============================================================================

@test "detect-from-keywords: detects code-quality-review from 'review' keyword" {
  run run_detect_from_keywords 'コードをレビューして'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_review=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review" or . == "code-quality-review")) | length > 0')
  [ "$has_review" = "true" ]
}

@test "detect-from-keywords: detects security-error-review from 'security' keyword" {
  run run_detect_from_keywords 'セキュリティチェック'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_security=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review" or . == "security-error-review")) | length > 0')
  [ "$has_security" = "true" ]
}

@test "detect-from-keywords: detects docs-test-review from 'test' keyword" {
  run run_detect_from_keywords 'テストコードのレビュー'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_test=$(echo "$output" | jq '.skills | map(select(. == "comprehensive-review" or . == "docs-test-review")) | length > 0')
  [ "$has_test" = "true" ]
}

# =============================================================================
# 正常系テスト: アーキテクチャ系検出
# =============================================================================

@test "detect-from-keywords: detects clean-architecture-ddd from 'architecture' keyword" {
  run run_detect_from_keywords 'アーキテクチャの設計相談'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_arch=$(echo "$output" | jq '.skills | contains(["clean-architecture-ddd"])')
  [ "$has_arch" = "true" ]
}

# =============================================================================
# 正常系テスト: API Design検出
# =============================================================================

@test "detect-from-keywords: detects api-design from 'api design' keyword" {
  run run_detect_from_keywords 'rest api design review'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_api=$(echo "$output" | jq '.skills | contains(["api-design"])')
  [ "$has_api" = "true" ]
}

# =============================================================================
# 正常系テスト: Serena検出
# =============================================================================

@test "detect-from-keywords: detects serena from 'serena mcp' keyword" {
  run run_detect_from_keywords 'serena mcp を使って分析'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local context=$(echo "$output" | jq -r '.context')
  [[ "$context" =~ "Serena MCP detected" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-keywords: returns nothing when no keywords match" {
  run run_detect_from_keywords '何もマッチしないプロンプト xyz123'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local langs_count=$(echo "$output" | jq '.langs | length')
  local skills_count=$(echo "$output" | jq '.skills | length')
  [ "$langs_count" -eq 0 ]
  [ "$skills_count" -eq 0 ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: detects multiple keywords in single prompt" {
  run run_detect_from_keywords 'docker と kubernetes と terraform の設定'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  # 複数のスキルが検出されることを確認（エイリアス変換後）
  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops" or . == "dockerfile-best-practices")) | length > 0')
  local has_k8s=$(echo "$output" | jq '.skills | map(select(. == "container-ops" or . == "kubernetes")) | length > 0')
  local has_terraform=$(echo "$output" | jq '.skills | contains(["terraform"])')

  [ "$has_docker" = "true" ]
  [ "$has_k8s" = "true" ]
  [ "$has_terraform" = "true" ]
}

@test "boundary: handles case-insensitive matching" {
  run run_detect_from_keywords 'DOCKER SETUP'
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local has_docker=$(echo "$output" | jq '.skills | map(select(. == "container-ops" or . == "dockerfile-best-practices")) | length > 0')
  [ "$has_docker" = "true" ]
}

@test "boundary: handles empty prompt" {
  run run_detect_from_keywords ''
  [ "$status" -eq 0 ]
  echo "$output" | jq empty

  local langs_count=$(echo "$output" | jq '.langs | length')
  local skills_count=$(echo "$output" | jq '.skills | length')
  [ "$langs_count" -eq 0 ]
  [ "$skills_count" -eq 0 ]
}
