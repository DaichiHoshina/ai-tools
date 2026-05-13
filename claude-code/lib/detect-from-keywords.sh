#!/usr/bin/env bash
# =============================================================================
# Detect Technology Stack from Prompt Keywords
# user-prompt-submit.sh から分離（保守性向上）
# Performance optimization: キャッシング機構追加
# =============================================================================

set -euo pipefail

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

# スキル名マッピング（旧名→新名+パラメータ）
# Phase2-5 スキル統合で追加
declare -g -A SKILL_ALIASES=(
  ["docker-troubleshoot"]="container-ops:CONTAINER_PLATFORM=docker:CONTAINER_MODE=troubleshoot"
  ["kubernetes"]="container-ops:CONTAINER_PLATFORM=kubernetes"
)

# スキルエイリアス変換関数
_apply_skill_aliases() {
  local -n _skills_ref=$1
  local -A new_skills=()
  
  set +u
  for skill in "${!_skills_ref[@]}"; do
    if [[ -n "${SKILL_ALIASES[$skill]:-}" ]]; then
      # エイリアス検出: 新スキル名+環境変数設定に変換
      IFS=':' read -ra parts <<< "${SKILL_ALIASES[$skill]}"
      local new_skill="${parts[0]}"
      new_skills["$new_skill"]=1
      
      # 環境変数設定（パラメータ）
      for ((i=1; i<${#parts[@]}; i++)); do
        IFS='=' read -r var_name var_value <<< "${parts[$i]}"
        export "$var_name=$var_value"
      done
    else
      # エイリアスなし: そのまま保持
      new_skills["$skill"]=1
    fi
  done
  set -u

  # 元の配列を上書き
  set +u
  _skills_ref=()
  for skill in "${!new_skills[@]}"; do
    _skills_ref["$skill"]=1
  done
  set -u
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

  # スラッシュコマンドはスキル側でルーティングするため検出スキップ
  if [[ "$prompt_lower" =~ ^/ ]]; then
    return 0
  fi

  # キャッシュチェック
  local prompt_hash=$(_hash_prompt "$prompt_lower")
  if _get_cached_result "$prompt_hash" _langs _skills; then
    # キャッシュヒット → エイリアス変換適用
    _apply_skill_aliases _skills
    return 0
  fi

  # キーワードパターンテーブル（pattern → language:skill）
  declare -A keyword_patterns=(
    ['go|golang|\.go|go\.mod']="golang:backend-dev"
    ['python|\.py|pip|poetry|pyproject\.toml|requirements\.txt|django|fastapi']="python:"
    ['rust|\.rs|cargo|cargo\.toml|tokio|axum']="rust:"
    ['typescript|\.ts|\.tsx|tsconfig']="typescript:backend-dev"
    ['react|next\\.js|nextjs|\\.jsx']="react:react-best-practices"
    ['tailwind']="tailwind:"
    ['docker|dockerfile|docker-compose']=":container-ops"
    ['kubernetes|k8s|kubectl|deployment\\.yaml']=":kubernetes"
    ['terraform|\\.tf|tfvars']=":terraform"
    ['grpc|protobuf|\\.proto']=":grpc-protobuf"
    ['review|レビュー|確認して|refactor|リファクタ']=":comprehensive-review"
    ['security|セキュリティ|脆弱性']=":comprehensive-review"
    ['test|テスト|doc|ドキュメント']=":comprehensive-review"
    ['ui|ux|デザイン|accessibility']=":uiux-review"
    ['architecture|アーキテクチャ|設計|ddd|domain']=":clean-architecture-ddd"
    ['api.*design|rest.*api|graphql']=":api-design"
    ['microservices|マイクロサービス|monorepo']=":microservices-monorepo"
    ['brainstorm|ブレスト|設計相談|アイデア出し']=":superpowers:brainstorm"
    ['tdd|test.*driven|red.*green.*refactor|テスト駆動']=":superpowers:test-driven-development"
    ['systematic.*debug|根本原因|デバッグ.*体系']=":superpowers:systematic-debugging"
    ['monitoring|alert|slo|burn.*rate|runbook|障害対応|アラート']=":incident-response"
    ['async.*job|queue|worker|job.*pattern|非同期|キュー|ワーカー|dlq|dead.*letter']=":backend-dev"
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

  # 執筆意図検出（ヒト向けdoc執筆時に writing-principles を強制ロード）
  # 対象: Notion/Design Doc/PRD/PR description/issue本文/RCA/記事/まとめ
  # genshijin chat 応答とは別軸（doc出力前のみ発火）
  if echo "$prompt_lower" | grep -qE '書いて|まとめて|ドラフト|draft|design.?doc|デザインドック|prd|要件定義|要件定|notion|記事|レポート|議事録|報告書|執筆|文章|pr.?description|pr本文|issue本文|rca|障害報告|振り返り|retrospective|プレスリリース|お知らせ|案内文|提案書|adr|技術選定|意思決定記録|ears|受け入れ基準|productspec|techspec|技術仕様書|プロダクト仕様'; then
    _context="${_context}
📝 執筆検出: 最優先は読み手の認知負荷を下げる/1回読めば理解できる/「で、つまり何？」と思わせない/賢そうでなく伝わる。

書く前の4問: 読み手は具体的に誰／読後の行動／裏付ける数字or事例／なぜ必要。

指針:
- 用語を並べるだけで説明しない、関係を1文で繋ぐ（×可観測性/疎結合/スケーラビリティ並列）
- 暗黙知を前提にしない（「いつもの」「ご存知の通り」の内容を1文で書く）
- 抽象説明の直後に具体例を1つ。抽象だけで段落を終わらせない
- 次の疑問を先回り（1段落書いたら、読み手が次に聞きたいことを次段落に置く）
- 見出しはラベルでなく主張（×アーキテクチャ ○読み書きを分離して負荷を分散する）
- 段落に役割（背景/理由/具体例/結論/注意点）。曖昧なら削除 or 分割
- AI定型語禁止: 効果的に/シームレスに/革新的な/〜を実現します/ご紹介します
- 評価語に根拠1文: 必須/推奨/重要 → 直後に「なぜ・事例・数字」
- 抽象→具体: 大幅改善→「p99 1.2s→320ms (-73%)」
- 短文(issue/PR/Slack)はPREP 400字、長文はTL;DR+常体統一
- 指示語禁止: これ/上記/前述 → 具体名

避ける段落型: 抽象ポエム/用語羅列/過剰丁寧/余分形容詞/同義反復/中身のないまとめ

段落手本: 「注文処理が重くなったときに一部の処理だけ遅延できるようにしたい。そのため、メール送信や通知処理を別の非同期処理に分離する。本処理の応答時間を p95 500ms 以内に保つことが目的。」（抽象名詞ゼロ・具体状況→具体行動→数値目標）

出力直前の自問: ①「で、つまり何？」と思わせないか ②初見が途中で止まらないか ③各段落の役割が明確か

詳細: claude-code/references/writing-principles.md"
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
  
  # スキルエイリアス変換適用
  _apply_skill_aliases _skills
}

# Export functions
export -f detect_from_keywords
export -f _apply_skill_aliases
export -f _init_cache
export -f _hash_prompt
export -f _get_cached_result
export -f _save_to_cache
