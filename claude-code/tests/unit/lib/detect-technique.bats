#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-technique.sh
# Comprehensive test suite with actual function invocation and output validation
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../../" && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/claude-code/lib/detect-technique.sh"
}

# =============================================================================
# _detect_purpose テスト（直接呼び出し）
# =============================================================================

@test "_detect_purpose: CRUD キーワード検出" {
  run bash -c "source '$LIB_FILE'; _detect_purpose 'user data create insert update delete'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "CRUD" ]]
}

@test "_detect_purpose: Logic キーワード検出" {
  run bash -c "source '$LIB_FILE'; _detect_purpose 'ビジネスロジック条件分岐判定ルール'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Logic" ]]
}

@test "_detect_purpose: 複数キーワード同時検出（CRUD + Concurrency）" {
  run bash -c "source '$LIB_FILE'; _detect_purpose 'create データベース並行トランザクション'"
  [ "$status" -eq 0 ]
  # 複数目的が検出されるはず
  [[ "$output" =~ "CRUD" ]]
  [[ "$output" =~ "Concurrency" ]]
}

# =============================================================================
# _estimate_complexity テスト（直接呼び出し）
# =============================================================================

@test "_estimate_complexity: 低複雑度（キーワード無し）" {
  run bash -c "source '$LIB_FILE'; _estimate_complexity 'simple basic task'"
  [ "$status" -eq 0 ]
  # 出力は 1-10 の数字。基本は 1 + シンプルで -1 → 最小値 1
  [[ "$output" =~ ^[0-9]+$ ]]
  # シンプルなので 1 に近い
  [ "$output" -le 3 ]
}

@test "_estimate_complexity: 高複雑度（マイクロサービス + 分散 + 設計）" {
  run bash -c "source '$LIB_FILE'; _estimate_complexity 'マイクロサービス分散設計トランザクション'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  # マイクロサービス|分散=+2, 設計=+1, トランザクション=+1 → base(1)+5 以上
  [ "$output" -ge 4 ]
}

@test "_estimate_complexity: 範囲制限（10以上は10、負数は1）" {
  # 複数の高スコアキーワードで合計 10+ を狙う
  run bash -c "source '$LIB_FILE'; _estimate_complexity 'マイクロサービス分散トランザクション決済システム大規模'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  # スコアは 1-10 に制限されるはず
  [ "$output" -le 10 ]
}

# =============================================================================
# _estimate_difficulty テスト（直接呼び出し）
# =============================================================================

@test "_estimate_difficulty: 低難易度（基本タスク）" {
  run bash -c "source '$LIB_FILE'; _estimate_difficulty 'crud基本登録一覧'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" -le 3 ]
}

@test "_estimate_difficulty: 高難易度（並行 + 分散トランザクション）" {
  run bash -c "source '$LIB_FILE'; _estimate_difficulty 'distributed transaction race condition concurrent algorithm'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  # 並行=+2, 分散トランザクション=+2, アルゴリズム=+1 → 6+
  [ "$output" -ge 5 ]
}

@test "_estimate_difficulty: 範囲制限（1-10）" {
  run bash -c "source '$LIB_FILE'; _estimate_difficulty 'encryption encrypt security parallel concurrent distributed transaction algorithm generic type-safe'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" -le 10 ]
}

# =============================================================================
# _estimate_volume テスト（直接呼び出し）
# =============================================================================

@test "_estimate_volume: Small（デフォルト）" {
  run bash -c "source '$LIB_FILE'; _estimate_volume 'add single feature'"
  [ "$status" -eq 0 ]
  [[ "$output" == "Small" ]]
}

@test "_estimate_volume: Medium（複数キーワード）" {
  run bash -c "source '$LIB_FILE'; _estimate_volume 'multi module several components'"
  [ "$status" -eq 0 ]
  [[ "$output" == "Medium" ]]
}

@test "_estimate_volume: Large（大規模キーワード）" {
  run bash -c "source '$LIB_FILE'; _estimate_volume 'システム全体フルリライト大規模'"
  [ "$status" -eq 0 ]
  [[ "$output" == "Large" ]]
}

# =============================================================================
# detect_technique_recommendation テスト（メイン関数、nameref出力検証）
# =============================================================================

@test "detect_technique_recommendation: 低複雑度は空文字列を返す" {
  run bash -c "
    source '$LIB_FILE'
    result=''
    detect_technique_recommendation 'simple fix typo' result
    # 結果が空かどうかチェック
    if [ -z \"\${result}\" ]; then
      echo 'EMPTY'
    else
      echo \"VALUE: \${result}\"
    fi
  "
  [ "$status" -eq 0 ]
  # 低複雑度（2）× 低難易度（1） → 空出力
  [[ "$output" == "EMPTY" ]]
}

@test "detect_technique_recommendation: CRUD + 複雑性で推奨を返す" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'create read update delete database microservice distributed architecture algorithm parallel async' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # CRUD + microservice + parallel で複雑度/難易度上昇 → テクニック推奨
  [[ "$output" =~ "Techniques" ]]
}

@test "detect_technique_recommendation: 複雑度高（マイクロサービス分散）で複数テクニック推奨" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'マイクロサービス分散アーキテクチャ設計' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # complexity >= 5 で複数テクニックが推奨されるはず
  # 出力に "Techniques" が含まれ、複数テクニック（カンマ区切り）が含まれる
  [[ "$output" =~ "Techniques" ]]
  # カンマが複数あれば複数テクニック（最低 Result/Either + 1以上）
  output_commas=$(echo "$output" | grep -o ',' | wc -l)
  [ "$output_commas" -ge 1 ]
}

@test "detect_technique_recommendation: 難易度高（並行 + 暗号）で形式手法推奨" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'parallel concurrent race condition encryption security algorithm' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # 難易度高 → 形式手法や契約プログラミング等が推奨されるはず
  [[ "$output" =~ "Techniques" ]]
  # "形式手法" または "契約" 等が含まれるか確認
  [[ "$output" =~ "形式手法" ]] || [[ "$output" =~ "契約" ]] || [[ "$output" =~ "圏論" ]]
}

@test "detect_technique_recommendation: Concurrency目的で形式手法とイミュータビリティ推奨" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'parallel async distributed トランザクション race condition' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # Concurrency 検出 → 形式手法 + イミュータビリティ推奨
  [[ "$output" =~ "Techniques" ]]
  [[ "$output" =~ "形式手法" ]]
  [[ "$output" =~ "イミュータビリティ" ]]
}

@test "detect_technique_recommendation: Token cost が数値で出力される" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'マイクロサービス分散architecture設計トランザクション' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # Token cost が含まれる（~数字tokens の形式）
  [[ "$output" =~ ~[0-9]+tokens ]]
}

@test "detect_technique_recommendation: complexity と difficulty スコアが含まれる" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'encryption parallel distributed' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # complexity: と difficulty: が含まれる
  [[ "$output" =~ complexity:[0-9]+ ]]
  [[ "$output" =~ difficulty:[0-9]+ ]]
}

@test "detect_technique_recommendation: volume metric が含まれる" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'システム全体フルリライト大規模architecture分散' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # volume が含まれ、値は Small/Medium/Large のいずれか
  [[ "$output" =~ volume:(Small|Medium|Large) ]]
}

@test "detect_technique_recommendation: Logic目的で純粋関数と状態機械推奨" {
  run bash -c "
    source '$LIB_FILE'
    r=''
    detect_technique_recommendation 'ビジネスロジック条件判定ワークフロー状態遷移 microservice architecture algorithm concurrent' r
    echo \"\${r}\"
  "
  [ "$status" -eq 0 ]
  # Logic 検出 + microservice + concurrent で複雑度/難易度上昇 → 純粋関数 + 状態機械推奨
  [[ "$output" =~ "Techniques" ]]
  [[ "$output" =~ "純粋関数" ]]
  [[ "$output" =~ "状態機械" ]]
}
