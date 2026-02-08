#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-from-keywords.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/detect-from-keywords.sh"
}

# =============================================================================
# 正常系テスト: Go/Golang検出
# =============================================================================

@test "detect-from-keywords: detects golang from 'go' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'goのコードを修正' langs skills context
    echo \${langs[golang]:-0}:\${skills[go-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

@test "detect-from-keywords: detects golang from 'golang' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'golang backend implementation' langs skills context
    echo \${langs[golang]:-0}:\${skills[go-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: TypeScript検出
# =============================================================================

@test "detect-from-keywords: detects typescript from 'typescript' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'typescriptのコードレビュー' langs skills context
    echo \${langs[typescript]:-0}:\${skills[typescript-backend]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: React検出
# =============================================================================

@test "detect-from-keywords: detects react from 'react' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'reactコンポーネント作成' langs skills context
    echo \${langs[react]:-0}:\${skills[react-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1:1" ]]
}

# =============================================================================
# 正常系テスト: Docker検出
# =============================================================================

@test "detect-from-keywords: detects docker from 'docker' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'dockerの設定を確認' langs skills context
    echo \${skills[dockerfile-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: レビュー系スキル検出
# =============================================================================

@test "detect-from-keywords: detects code-quality-review from 'review' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'コードをレビューして' langs skills context
    echo \${skills[code-quality-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-keywords: detects security-error-review from 'security' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'セキュリティチェック' langs skills context
    echo \${skills[security-error-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "detect-from-keywords: detects docs-test-review from 'test' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'テストコードのレビュー' langs skills context
    echo \${skills[docs-test-review]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: アーキテクチャ系検出
# =============================================================================

@test "detect-from-keywords: detects clean-architecture-ddd from 'architecture' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'アーキテクチャの設計相談' langs skills context
    echo \${skills[clean-architecture-ddd]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: API Design検出
# =============================================================================

@test "detect-from-keywords: detects api-design from 'api design' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'rest api design review' langs skills context
    echo \${skills[api-design]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

# =============================================================================
# 正常系テスト: Serena検出
# =============================================================================

@test "detect-from-keywords: detects serena from 'serena mcp' keyword" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'serena mcp を使って分析' langs skills context
    echo \"\$context\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Serena MCP detected" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "detect-from-keywords: returns nothing when no keywords match" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords '何もマッチしないプロンプト xyz123' langs skills context
    echo \${#langs[@]}:\${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0:0" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: detects multiple keywords in single prompt" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'docker と kubernetes と terraform の設定' langs skills context
    # Check multiple skills detected
    [ \${skills[dockerfile-best-practices]:-0} -eq 1 ] && \
    [ \${skills[kubernetes]:-0} -eq 1 ] && \
    [ \${skills[terraform]:-0} -eq 1 ]
  "
  [ "$status" -eq 0 ]
}

@test "boundary: handles case-insensitive matching" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords 'DOCKER SETUP' langs skills context
    echo \${skills[dockerfile-best-practices]:-0}
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1" ]]
}

@test "boundary: handles empty prompt" {
  run bash -c "
    source '$LIB_FILE'
    declare -A langs skills
    context=''
    detect_from_keywords '' langs skills context
    echo \${#langs[@]}:\${#skills[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "0:0" ]
}
