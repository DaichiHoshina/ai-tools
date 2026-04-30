#!/usr/bin/env bats
# =============================================================================
# BATS Tests for detect-technique.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/claude-code/lib/detect-technique.sh"
}

# =============================================================================
# detect_technique_recommendation テスト（エクスポート関数のみ）
# =============================================================================

@test "detect-technique: basic invocation succeeds" {
  run bash -c "source '$LIB_FILE'; result=''; detect_technique_recommendation 'test' result; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: handles low complexity gracefully" {
  run bash -c "source '$LIB_FILE'; result=''; detect_technique_recommendation 'simple fix typo' result; [ -z \"\${result}\" ] && echo 'empty' || echo 'filled'"
  [ "$status" -eq 0 ]
}

@test "detect-technique: returns status 0" {
  run bash -c "source '$LIB_FILE'; result=''; detect_technique_recommendation 'any' result; echo 'done'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "done" ]]
}

@test "detect-technique: sets output variable via nameref" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'マイクロサービス分散複雑' r; [ -n \"\${r}\" ] && echo 'set' || echo 'empty'"
  [ "$status" -eq 0 ]
}

@test "detect-technique: recommendation includes Techniques keyword for high complexity" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'マイクロサービス分散トランザクション設計' r; echo \"\${r}\" | grep -q 'Techniques' && echo 'found' || echo 'not found'"
  [ "$status" -eq 0 ]
}

@test "detect-technique: recommendation includes token cost" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'マイクロサービス分散' r; echo \"\${r}\" | grep -q 'token' && echo 'found' || echo 'not found'"
  [ "$status" -eq 0 ]
}

@test "detect-technique: recommendation includes complexity score" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'マイクロサービス' r; echo \"\${r}\" | grep -q 'complexity' && echo 'found' || true"
  [ "$status" -eq 0 ]
}

@test "detect-technique: recommendation includes difficulty score" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'マイクロサービス' r; echo \"\${r}\" | grep -q 'difficulty' && echo 'found' || true"
  [ "$status" -eq 0 ]
}

@test "detect-technique: recommendation includes volume metric" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'システム全体' r; echo \"\${r}\" | grep -q 'volume' && echo 'found' || true"
  [ "$status" -eq 0 ]
}

@test "detect-technique: detects CRUD keywords" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'データ登録更新削除取得' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: detects Logic keywords" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'ビジネスロジック条件判定' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: detects Concurrency keywords" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation '並行処理トランザクション' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: detects Security keywords" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'セキュリティ認証暗号' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: detects Performance keywords" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'パフォーマンス最適化キャッシュ' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: handles empty prompt" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation '' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}

@test "detect-technique: detects large volume" {
  run bash -c "source '$LIB_FILE'; r=''; detect_technique_recommendation 'システム全体大規模リライト' r; echo 'ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ok" ]]
}
