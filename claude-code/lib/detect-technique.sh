#!/usr/bin/env bash
# =============================================================================
# Detect Recommended Techniques from Prompt Analysis
# technique-selection.md のロジックをシェルスクリプトで実装
# =============================================================================

# タスク目的を検出
# Args: $1 = prompt_lower
# Returns: スペース区切りの目的リスト
_detect_purpose() {
  local prompt=$1
  local purposes=""

  # CRUD
  if [[ "$prompt" =~ crud|登録|更新|削除|一覧|取得|create|read|update|delete|insert|select|fetch|list ]]; then
    purposes="${purposes} CRUD"
  fi

  # Logic
  if [[ "$prompt" =~ ロジック|計算|判定|バリデーション|ルール|条件分岐|ワークフロー|状態遷移|logic|validation|rule|workflow|state.*machine|algorithm|アルゴリズム ]]; then
    purposes="${purposes} Logic"
  fi

  # Concurrency
  if [[ "$prompt" =~ 並行|並列|非同期|concurrent|parallel|async|distributed|分散|トランザクション|transaction|デッドロック|排他|lock|mutex|race.*condition ]]; then
    purposes="${purposes} Concurrency"
  fi

  # Security
  if [[ "$prompt" =~ セキュリティ|認証|認可|暗号|security|auth|encrypt|token|jwt|oauth|csrf|xss|injection|脆弱性|vulnerability|権限|permission ]]; then
    purposes="${purposes} Security"
  fi

  # Performance
  if [[ "$prompt" =~ 性能|パフォーマンス|最適化|キャッシュ|performance|optimize|cache|latency|throughput|レイテンシ|スループット|メモリ|memory.*leak ]]; then
    purposes="${purposes} Performance"
  fi

  # デフォルト: 何も検出されなければCRUD
  if [ -z "$purposes" ]; then
    purposes=" CRUD"
  fi

  echo "$purposes"
}

# 複雑さスコアを推定 (1-10)
_estimate_complexity() {
  local prompt=$1
  local score=1  # ベース（3→1に変更で分散改善）

  # 複雑さを上げるキーワード（加算値を半減）
  [[ "$prompt" =~ マイクロサービス|microservice|分散|distributed ]] && score=$((score + 2))
  [[ "$prompt" =~ アーキテクチャ|architecture|設計|リファクタ|refactor ]] && score=$((score + 1))
  [[ "$prompt" =~ トランザクション|transaction|saga|イベント駆動|event.*driven ]] && score=$((score + 1))
  [[ "$prompt" =~ 複雑|complex|大規模|large.*scale ]] && score=$((score + 1))
  [[ "$prompt" =~ ddd|domain.*driven|ドメイン駆動 ]] && score=$((score + 1))
  [[ "$prompt" =~ 統合|integration|連携|migration|移行 ]] && score=$((score + 1))
  [[ "$prompt" =~ 決済|payment|課金|billing|金融|financial ]] && score=$((score + 2))

  # 複雑さを下げるキーワード（半減）
  [[ "$prompt" =~ シンプル|simple|簡単|basic|基本 ]] && score=$((score - 1))
  [[ "$prompt" =~ fix|修正|バグ|bug|typo ]] && score=$((score - 1))

  # 範囲制限 1-10
  [ "$score" -lt 1 ] && score=1
  [ "$score" -gt 10 ] && score=10

  echo "$score"
}

# 難しさスコアを推定 (1-10)
_estimate_difficulty() {
  local prompt=$1
  local score=1  # ベース（3→1に変更で分散改善）

  [[ "$prompt" =~ 暗号|encrypt|security|セキュリティ ]] && score=$((score + 1))
  [[ "$prompt" =~ 並行|concurrent|parallel|race|デッドロック ]] && score=$((score + 2))
  [[ "$prompt" =~ 最適化|optimize|performance|パフォーマンス ]] && score=$((score + 1))
  [[ "$prompt" =~ 分散.*トランザクション|distributed.*transaction|saga ]] && score=$((score + 2))
  [[ "$prompt" =~ アルゴリズム|algorithm|数学|math ]] && score=$((score + 1))
  [[ "$prompt" =~ 型安全|type.*safe|generic|ジェネリック ]] && score=$((score + 1))

  [[ "$prompt" =~ シンプル|simple|簡単|basic ]] && score=$((score - 1))
  [[ "$prompt" =~ crud|登録|一覧 ]] && score=$((score - 1))

  [ "$score" -lt 1 ] && score=1
  [ "$score" -gt 10 ] && score=10

  echo "$score"
}

# 量を推定
_estimate_volume() {
  local prompt=$1

  if [[ "$prompt" =~ 大規模|large|全体|全サービス|システム全体|フルリライト ]]; then
    echo "Large"
  elif [[ "$prompt" =~ 複数|several|multi|一部|partial ]]; then
    echo "Medium"
  else
    echo "Small"
  fi
}

# テクニック選択（メイン関数）
# Args:
#   $1: prompt_lower
#   $2: variable name for technique recommendations (string)
detect_technique_recommendation() {
  local prompt=$1
  local -n _technique_result=$2

  local purposes=$(_detect_purpose "$prompt")
  local complexity=$(_estimate_complexity "$prompt")
  local difficulty=$(_estimate_difficulty "$prompt")
  local volume=$(_estimate_volume "$prompt")

  # 必須テクニック
  local techniques="Result/Either型, CQS"
  local token_cost=700

  # 複雑さベース選択
  if [ "$complexity" -ge 9 ]; then
    techniques="${techniques}, 形式手法"
    token_cost=$((token_cost + 1000))
  fi
  if [ "$complexity" -ge 7 ]; then
    techniques="${techniques}, DDD戦術的パターン"
    token_cost=$((token_cost + 1500))
  fi
  if [ "$complexity" -ge 6 ]; then
    techniques="${techniques}, プロパティベーステスト, 状態機械"
    token_cost=$((token_cost + 1500))
  fi
  if [ "$complexity" -ge 5 ]; then
    techniques="${techniques}, イミュータビリティ"
    token_cost=$((token_cost + 300))
  fi

  # 難しさベース選択
  if [ "$difficulty" -ge 8 ]; then
    [[ "$techniques" != *"形式手法"* ]] && { techniques="${techniques}, 形式手法"; token_cost=$((token_cost + 1000)); }
  fi
  if [ "$difficulty" -ge 6 ]; then
    [[ "$techniques" != *"圏論"* ]] && { techniques="${techniques}, 圏論"; token_cost=$((token_cost + 2000)); }
    techniques="${techniques}, 契約プログラミング"
    token_cost=$((token_cost + 600))
  fi
  if [ "$difficulty" -ge 5 ]; then
    [[ "$techniques" != *"プロパティベーステスト"* ]] && { techniques="${techniques}, プロパティベーステスト"; token_cost=$((token_cost + 800)); }
  fi
  if [ "$difficulty" -ge 4 ]; then
    techniques="${techniques}, 純粋関数"
    token_cost=$((token_cost + 400))
  fi

  # 目的ベース選択
  if [[ "$purposes" == *"Concurrency"* ]]; then
    [[ "$techniques" != *"形式手法"* ]] && { techniques="${techniques}, 形式手法"; token_cost=$((token_cost + 1000)); }
    [[ "$techniques" != *"イミュータビリティ"* ]] && { techniques="${techniques}, イミュータビリティ"; token_cost=$((token_cost + 300)); }
  fi
  if [[ "$purposes" == *"Security"* ]]; then
    [[ "$techniques" != *"契約プログラミング"* ]] && { techniques="${techniques}, 契約プログラミング"; token_cost=$((token_cost + 600)); }
  fi
  if [[ "$purposes" == *"Logic"* ]]; then
    [[ "$techniques" != *"純粋関数"* ]] && { techniques="${techniques}, 純粋関数"; token_cost=$((token_cost + 400)); }
    [[ "$techniques" != *"状態機械"* ]] && { techniques="${techniques}, 状態機械"; token_cost=$((token_cost + 700)); }
  fi

  # 量ベース選択
  if [[ "$volume" == "Large" ]]; then
    [[ "$techniques" != *"DDD戦術的パターン"* ]] && { techniques="${techniques}, DDD戦術的パターン"; token_cost=$((token_cost + 1500)); }
  fi

  # 必須のみ（低複雑度）なら推奨メッセージなし
  if [ "$complexity" -le 3 ] && [ "$difficulty" -le 3 ]; then
    _technique_result=""
    return 0
  fi

  # 結果構築
  _technique_result="Techniques [${techniques}] (complexity:${complexity} difficulty:${difficulty} volume:${volume} ~${token_cost}tokens)"
}

# Export（メイン関数のみ）
export -f detect_technique_recommendation
