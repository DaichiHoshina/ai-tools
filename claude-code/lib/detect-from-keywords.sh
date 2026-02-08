#!/usr/bin/env bash
# =============================================================================
# Detect Technology Stack from Prompt Keywords
# user-prompt-submit.sh から分離（保守性向上）
# Performance optimization: キャッシング機構追加
# =============================================================================

# キャッシュディレクトリ
CACHE_DIR="${HOME}/.claude/cache"
CACHE_FILE="${CACHE_DIR}/keyword-patterns.json"
CACHE_MAX_ENTRIES=100

# キャッシュの初期化
_init_cache() {
  if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
  fi

  if [ ! -f "$CACHE_FILE" ]; then
    echo '{}' > "$CACHE_FILE"
  fi
}

# プロンプトのハッシュ値を計算
_hash_prompt() {
  local prompt=$1
  echo -n "$prompt" | md5sum 2>/dev/null || echo -n "$prompt" | md5
}

# キャッシュから検出結果を取得
# Returns: 0 if cache hit, 1 if cache miss
_get_cached_result() {
  local prompt_hash=$1
  local -n _cache_langs=$2
  local -n _cache_skills=$3

  if [ ! -f "$CACHE_FILE" ]; then
    return 1
  fi

  local cached=$(jq -r ".\"$prompt_hash\" // empty" "$CACHE_FILE" 2>/dev/null)
  if [ -z "$cached" ] || [ "$cached" = "null" ]; then
    return 1
  fi

  # キャッシュヒット: 結果を復元
  local langs=$(echo "$cached" | jq -r '.langs // empty')
  local skills=$(echo "$cached" | jq -r '.skills // empty')

  if [ -n "$langs" ]; then
    IFS=',' read -ra lang_array <<< "$langs"
    for lang in "${lang_array[@]}"; do
      _cache_langs["$lang"]=1
    done
  fi

  if [ -n "$skills" ]; then
    IFS=',' read -ra skill_array <<< "$skills"
    for skill in "${skill_array[@]}"; do
      _cache_skills["$skill"]=1
    done
  fi

  return 0
}

# 検出結果をキャッシュに保存
_save_to_cache() {
  local prompt_hash=$1
  local langs=$2
  local skills=$3

  _init_cache

  # 新しいエントリを作成
  local new_entry=$(jq -n \
    --arg l "$langs" \
    --arg s "$skills" \
    '{langs: $l, skills: $s, timestamp: now}')

  # キャッシュファイルを更新
  local updated_cache=$(jq \
    --arg hash "$prompt_hash" \
    --argjson entry "$new_entry" \
    '.[$hash] = $entry' \
    "$CACHE_FILE" 2>/dev/null || echo '{}')

  # エントリ数が上限を超えた場合、古いものを削除（LRU）
  local entry_count=$(echo "$updated_cache" | jq 'length')
  if [ "$entry_count" -gt "$CACHE_MAX_ENTRIES" ]; then
    updated_cache=$(echo "$updated_cache" | jq '
      to_entries |
      sort_by(.value.timestamp) |
      reverse |
      .[0:'"$CACHE_MAX_ENTRIES"'] |
      from_entries
    ')
  fi

  echo "$updated_cache" > "$CACHE_FILE"
}

# キーワードパターンから技術スタックを検出
# Args:
#   $1: prompt_lower (lowercase prompt)
#   $2: detected_langs (associative array name)
#   $3: detected_skills (associative array name)
#   $4: additional_context (string variable name)
detect_from_keywords() {
  local prompt_lower=$1
  local -n _langs=$2
  local -n _skills=$3
  local -n _context=$4

  # キャッシュチェック
  local prompt_hash=$(_hash_prompt "$prompt_lower")
  if _get_cached_result "$prompt_hash" _langs _skills; then
    # キャッシュヒット
    return 0
  fi

  # キーワードパターンテーブル（pattern → language:skill）
  declare -A keyword_patterns=(
    ['go|golang|\.go|go\.mod']="golang:go-backend"
    ['python|\.py|pip|poetry|pyproject\.toml|requirements\.txt|django|fastapi']="python:"
    ['rust|\.rs|cargo|cargo\.toml|tokio|axum']="rust:"
    ['typescript|\.ts|\.tsx|tsconfig']="typescript:typescript-backend"
    ['react|next\\.js|nextjs|\\.jsx']="react:react-best-practices"
    ['tailwind']="tailwind:"
    ['docker|dockerfile|docker-compose']=":dockerfile-best-practices"
    ['kubernetes|k8s|kubectl|deployment\\.yaml']=":kubernetes"
    ['terraform|\\.tf|tfvars']=":terraform"
    ['grpc|protobuf|\\.proto']=":grpc-protobuf"
    ['review|レビュー|確認して|refactor|リファクタ']=":code-quality-review"
    ['security|セキュリティ|脆弱性']=":security-error-review"
    ['test|テスト|doc|ドキュメント']=":docs-test-review"
    ['ui|ux|デザイン|accessibility']=":uiux-review"
    ['architecture|アーキテクチャ|設計|ddd|domain']=":clean-architecture-ddd"
    ['api.*design|rest.*api|graphql']=":api-design"
    ['microservices|マイクロサービス|monorepo']=":microservices-monorepo"
    ['brainstorm|ブレスト|設計相談|アイデア出し']=":superpowers:brainstorm"
    ['tdd|test.*driven|red.*green.*refactor|テスト駆動']=":superpowers:test-driven-development"
    ['systematic.*debug|根本原因|デバッグ.*体系']=":superpowers:systematic-debugging"
  )

  # set -u対応
  set +u
  for keywords in "${!keyword_patterns[@]}"; do
    if echo "$prompt_lower" | grep -qE "$keywords"; then
      IFS=':' read -r lang skill <<< "${keyword_patterns[$keywords]}"
      [ -n "$lang" ] && _langs["$lang"]=1
      [ -n "$skill" ] && _skills["$skill"]=1
    fi
  done
  set -u

  # Serena検出（特殊処理）
  if echo "$prompt_lower" | grep -qE '/serena|serena.*mcp|memory'; then
    _context="${_context}\\n- 🧠 Serena MCP detected: Use mcp__serena__* tools for project analysis"
  fi

  # 検出結果をキャッシュに保存（set -u対応）
  local langs_str=""
  set +u
  for lang in "${!_langs[@]}"; do
    langs_str="${langs_str}${lang},"
  done
  set -u
  langs_str="${langs_str%,}"

  local skills_str=""
  set +u
  for skill in "${!_skills[@]}"; do
    skills_str="${skills_str}${skill},"
  done
  set -u
  skills_str="${skills_str%,}"

  _save_to_cache "$prompt_hash" "$langs_str" "$skills_str"
}

# Export functions
export -f detect_from_keywords
export -f _init_cache
export -f _hash_prompt
export -f _get_cached_result
export -f _save_to_cache
