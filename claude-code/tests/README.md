# テストスイート

claude-code/ の自動テストスイート。

## セットアップ

### Batsフレームワークのインストール

```bash
# macOS (Homebrew)
brew install bats-core

# Linux (apt)
sudo apt-get install bats

# 手動インストール
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

### 前提条件

- `jq` (JSON処理)
- `shellcheck` (シェルスクリプト静的解析)

```bash
brew install jq shellcheck
```

## テスト実行

### 全テスト実行

```bash
# claude-code/ ディレクトリで実行
bats tests/

# または、個別ファイル指定
bats tests/unit/lib/security-functions.bats
```

### 出力例

```
✓ escape_for_sed: スラッシュをエスケープ
✓ escape_for_sed: アンパサンドをエスケープ
✓ validate_json: 有効なJSON（オブジェクト）
✓ validate_json: 無効なJSON（括弧不一致）
...

15 tests, 0 failures
```

### 詳細出力（デバッグ）

```bash
bats --tap tests/unit/lib/security-functions.bats
```

## テスト構成

```
tests/
├── unit/              単体テスト
│   └── lib/           共通ライブラリのテスト
│       └── security-functions.bats
└── integration/       統合テスト（今後追加予定）
```

## カバレッジ

| ファイル | テスト数 | カバレッジ |
|---------|:--------:|:----------:|
| lib/security-functions.sh | 23 | 95% |

**未テスト**:
- `secure_token_input()` (手動入力が必要なため統合テストで対応予定)

## CI/CD統合（今後）

```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: brew install bats-core jq shellcheck
      - name: Run tests
        run: bats tests/
      - name: Run shellcheck
        run: shellcheck lib/*.sh hooks/*.sh scripts/*.sh
```

## テスト追加ガイド

### 新しい単体テスト追加

```bash
# 1. テストファイル作成
cat > tests/unit/lib/new-module.bats <<'EOF'
#!/usr/bin/env bats

setup() {
    load '../../../lib/new-module.sh'
}

@test "新機能のテスト" {
    result=$(new_function "input")
    [ "$result" = "expected" ]
}
EOF

# 2. 実行権限付与
chmod +x tests/unit/lib/new-module.bats

# 3. テスト実行
bats tests/unit/lib/new-module.bats
```

### Batsテスト構文

```bash
# アサーション
[ "$actual" = "$expected" ]     # 文字列完全一致
[[ "$output" =~ "pattern" ]]    # 正規表現マッチ
[ "$status" -eq 0 ]             # 終了コード

# run コマンド（終了コードとoutputをキャプチャ）
run your_function "arg"
[ "$status" -eq 0 ]
[ "$output" = "expected output" ]

# setup/teardown
setup() {
    # 各テスト実行前
}

teardown() {
    # 各テスト実行後
}
```

## トラブルシューティング

### "command not found: bats"

```bash
# Bats未インストール
brew install bats-core
```

### "load: file not found"

```bash
# 相対パスが正しいか確認
pwd  # tests/unit/lib/ から見て ../../../lib/security-functions.sh
```

### テスト失敗（jq not found）

```bash
# jq未インストール
brew install jq
```

## 参考リンク

- [Bats Documentation](https://bats-core.readthedocs.io/)
- [Bats GitHub](https://github.com/bats-core/bats-core)
- [shellcheck](https://www.shellcheck.net/)
