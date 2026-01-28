#!/usr/bin/env bats
# security-functions.sh 単体テスト
# 実行方法: bats tests/unit/lib/security-functions.bats

setup() {
    # テスト対象のスクリプトを読み込み
    load '../../../lib/security-functions.sh'
}

# =============================================================================
# escape_for_sed() テスト
# =============================================================================

@test "escape_for_sed: スラッシュをエスケープ" {
    result=$(escape_for_sed "https://example.com/api")
    expected="https:\/\/example.com\/api"
    [ "$result" = "$expected" ]
}

@test "escape_for_sed: アンパサンドをエスケープ" {
    result=$(escape_for_sed "foo&bar")
    expected="foo\&bar"
    [ "$result" = "$expected" ]
}

@test "escape_for_sed: バックスラッシュをエスケープ" {
    result=$(escape_for_sed 'C:\Users\test')
    expected='C:\\Users\\test'
    [ "$result" = "$expected" ]
}

@test "escape_for_sed: 複合パターンをエスケープ" {
    result=$(escape_for_sed "url=https://api.example.com/v1&key=secret")
    expected="url=https:\/\/api.example.com\/v1\&key=secret"
    [ "$result" = "$expected" ]
}

@test "escape_for_sed: 空文字列を処理" {
    result=$(escape_for_sed "")
    [ "$result" = "" ]
}

# =============================================================================
# validate_json() テスト
# =============================================================================

@test "validate_json: 有効なJSON（オブジェクト）" {
    json='{"key": "value", "number": 123}'
    run validate_json "$json"
    [ "$status" -eq 0 ]
}

@test "validate_json: 有効なJSON（配列）" {
    json='[1, 2, 3, "test"]'
    run validate_json "$json"
    [ "$status" -eq 0 ]
}

@test "validate_json: 有効なJSON（文字列）" {
    json='"simple string"'
    run validate_json "$json"
    [ "$status" -eq 0 ]
}

@test "validate_json: 有効なJSON（数値）" {
    json='42'
    run validate_json "$json"
    [ "$status" -eq 0 ]
}

@test "validate_json: 無効なJSON（括弧不一致）" {
    json='{"key": "value"'
    run validate_json "$json"
    [ "$status" -eq 1 ]
}

@test "validate_json: 無効なJSON（カンマ誤り）" {
    json='{"key": "value",}'
    run validate_json "$json"
    [ "$status" -eq 1 ]
}

@test "validate_json: 無効なJSON（クォート誤り）" {
    json="{key: 'value'}"
    run validate_json "$json"
    [ "$status" -eq 1 ]
}

@test "validate_json: 空文字列" {
    json=''
    run validate_json "$json"
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_file_path() テスト
# =============================================================================

@test "validate_file_path: 存在するディレクトリ（HOME）" {
    run validate_file_path "$HOME"
    [ "$status" -eq 0 ]
}

@test "validate_file_path: 存在するディレクトリ（/tmp）" {
    run validate_file_path "/tmp"
    [ "$status" -eq 0 ]
}

@test "validate_file_path: 存在しないパス" {
    run validate_file_path "/nonexistent/path/12345"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
}

@test "validate_file_path: 親ディレクトリ制約（許可）" {
    run validate_file_path "$HOME" "$HOME"
    [ "$status" -eq 0 ]
}

@test "validate_file_path: 親ディレクトリ制約（拒否）" {
    run validate_file_path "/tmp" "$HOME"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "outside allowed directory" ]]
}

@test "validate_file_path: シンボリックリンク解決" {
    # /tmp はシンボリックリンクの可能性あり（macOS: /private/tmp）
    run validate_file_path "/tmp"
    [ "$status" -eq 0 ]
}

# =============================================================================
# read_stdin_with_limit() テスト
# =============================================================================

@test "read_stdin_with_limit: 通常サイズ入力" {
    input="test data"
    result=$(echo "$input" | read_stdin_with_limit 1024)
    [ "$result" = "$input" ]
}

@test "read_stdin_with_limit: サイズ超過検出" {
    # 100バイト制限で200バイト入力
    input=$(printf 'a%.0s' {1..200})
    run bash -c "echo '$input' | source lib/security-functions.sh && read_stdin_with_limit 100"
    [ "$status" -eq 1 ]
}

# =============================================================================
# 統合テスト
# =============================================================================

@test "統合: sed置換でescape_for_sedを使用" {
    url="https://example.com/api?key=value&id=123"
    escaped=$(escape_for_sed "$url")

    # sedで置換が正しく動作することを確認
    result=$(echo "URL: placeholder" | sed "s|placeholder|$escaped|g")
    expected="URL: $url"
    [ "$result" = "$expected" ]
}

@test "統合: JSONバリデーション→jqパース" {
    json='{"name": "test", "value": 42}'

    # バリデーション成功
    run validate_json "$json"
    [ "$status" -eq 0 ]

    # jqでパース可能
    name=$(echo "$json" | jq -r '.name')
    [ "$name" = "test" ]
}
