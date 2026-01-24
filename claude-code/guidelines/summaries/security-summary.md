# セキュリティガイドライン（サマリー版）

## 📚 詳細仕様一覧

| ファイル | 内容 |
|---------|------|
| `lib/security-functions.sh` | OWASP対策の共通関数ライブラリ |
| `guidelines/common/guardrails.md` | Guard関手によるForbidden射定義 |

---

## OWASP Top 10 対策

### 実装済みセキュリティ関数

| 関数 | 対策 | 用途 |
|------|------|------|
| `escape_for_sed()` | A03: コマンドインジェクション | sed置換時の特殊文字エスケープ |
| `secure_token_input()` | A02/A07: 認証情報保護 | トークンの安全な入力・保存 |
| `read_stdin_with_limit()` | DoS攻撃防止 | 入力サイズ制限（1MB） |
| `validate_json()` | 入力検証 | JSON形式の妥当性検証 |
| `validate_file_path()` | パストラバーサル防止 | ファイルパスの安全性検証 |

---

## Guard関手による3層分類

### Forbidden射（実行不可）

| カテゴリ | 禁止操作 |
|---------|---------|
| **システム破壊** | `rm -rf /`, `shutdown`, `mkfs` |
| **セキュリティ侵害** | `chmod 777 -R`, `commit(.env)`, `push(secrets)` |
| **Git危険操作** | `git push --force`（許可なし）, `git reset --hard`（リモート） |
| **YAGNI違反** | 未使用コード生成、「念のため」実装 |

### Boundary射（確認必要）

| カテゴリ | 操作 |
|---------|------|
| **Git操作** | `git commit`, `git push` |
| **ファイル操作** | ファイル編集・削除 |
| **設定変更** | 環境変数、config修正 |
| **パッケージ** | npm install, go get |

### Safe射（即座実行）

| カテゴリ | 操作 |
|---------|------|
| **読み取り** | ファイル読み取り、分析、検索 |
| **Git情報** | `git status`, `git log`, `git diff` |
| **提案** | 説明、提案、質問 |

---

## 入力検証ベストプラクティス

### JSON処理

```bash
# 1. サイズ制限
input=$(read_stdin_with_limit 1048576)  # 1MB

# 2. 形式検証
validate_json "$input"

# 3. jqでパース
data=$(echo "$input" | jq -r '.field')
```

### トークン管理

```bash
# 1. 安全な入力（echo抑制）
secure_token_input "TOKEN_NAME" "$ENV_FILE"

# 2. パーミッション制限
chmod 600 "$ENV_FILE"

# 3. メモリから削除
unset token
```

### ファイルパス検証

```bash
# シンボリックリンク解決 + パストラバーサル防止
validate_file_path "$target" "$allowed_parent"
```

---

## セキュリティスキャン（推奨）

### Node.js / TypeScript

```bash
# 依存関係の脆弱性チェック
npm audit --audit-level=moderate

# または
yarn audit --level moderate
```

### Go

```bash
# モジュール整合性検証
go mod verify

# 脆弱性スキャン
go list -json -m all | nancy sleuth
```

### 秘密情報スキャン

```bash
# gitleaks（pre-commitフックで自動実行推奨）
gitleaks detect --no-git

# または truffleHog
trufflehog filesystem .
```

---

## 認証・認可

| 項目 | 推奨 |
|------|------|
| **パスワード** | bcrypt/argon2 でハッシュ化 |
| **トークン** | JWT（短い有効期限 + リフレッシュトークン） |
| **API Key** | 環境変数管理、`.env`は`.gitignore` |
| **OAuth** | 標準ライブラリ使用（自作NG） |

---

## 暗号化

| 対象 | 推奨方式 |
|------|---------|
| **転送時** | TLS 1.2+ |
| **保管時** | AES-256-GCM |
| **パスワード** | bcrypt (cost ≥ 12) |
| **トークン** | ランダム生成（crypto.randomBytes） |

---

## ログ・監査

| 項目 | 推奨 |
|------|------|
| **ログレベル** | ERROR/WARN/INFO/DEBUG 分離 |
| **秘密情報** | パスワード・トークンはマスク |
| **監査ログ** | 認証・認可・重要操作を記録 |
| **保存期間** | 最低90日（法令要件確認） |

---

## セキュリティチェックリスト

### コード実装時

- [ ] ユーザー入力は全て検証（ホワイトリスト方式）
- [ ] SQL/コマンドインジェクション対策（パラメータ化）
- [ ] XSS対策（出力エスケープ）
- [ ] CSRF対策（トークン検証）
- [ ] 認証・認可を適切に実装

### デプロイ前

- [ ] 依存関係の脆弱性スキャン（`npm audit`, `go mod verify`）
- [ ] 秘密情報スキャン（`gitleaks`, `trufflehog`）
- [ ] `.env`ファイルが`.gitignore`に含まれている
- [ ] ハードコードされた秘密情報がない

### 本番運用

- [ ] HTTPS強制
- [ ] セキュリティヘッダー設定（CSP, HSTS等）
- [ ] レート制限実装
- [ ] 定期的な脆弱性スキャン
