# セキュリティガイドライン（サマリー版）

## 詳細仕様

| ファイル | 内容 |
|---------|------|
| `lib/security-functions.sh` | OWASP対策の共通関数ライブラリ |
| `guidelines/common/guardrails.md` | 操作ガードによる禁止操作定義 |

## セキュリティ関数

| 関数 | 用途 |
|------|------|
| `escape_for_sed()` | sed置換時の特殊文字エスケープ |
| `secure_token_input()` | トークンの安全な入力・保存 |
| `read_stdin_with_limit()` | 入力サイズ制限（1MB） |
| `validate_json()` | JSON形式の妥当性検証 |
| `validate_file_path()` | パストラバーサル防止 |

## 3層分類

| 層 | 例 |
|----|-----|
| **Forbidden** | `rm -rf /`, `chmod 777 -R`, `commit(.env)`, `git push --force` |
| **Boundary** | `git commit/push`, ファイル編集、設定変更 |
| **Safe** | ファイル読み取り、`git status/log/diff`、提案 |

## 実装チェックリスト

- [ ] ユーザー入力は全て検証（ホワイトリスト方式）
- [ ] SQL/コマンドインジェクション対策（パラメータ化）
- [ ] XSS対策（出力エスケープ）、CSRF対策
- [ ] 認証・認可の実装（bcrypt/argon2、JWT短い有効期限）
- [ ] 秘密情報: 環境変数管理、`.env`は`.gitignore`
- [ ] 暗号化: TLS 1.2+（転送時）、AES-256-GCM（保管時）
- [ ] 依存関係スキャン: `npm audit`, `go mod verify`
- [ ] 秘密情報スキャン: `gitleaks`, `trufflehog`
