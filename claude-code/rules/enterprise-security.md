---
paths:
  - "**/*"
---
# エンタープライズセキュリティルール

## 1. シークレット漏洩防止

### 絶対禁止（レスポンスに含めない）
- APIキー、トークン、パスワード、シークレット
- AWS/GCP/Azure認証情報（アクセスキー、サービスアカウント）
- SSH秘密鍵、TLS証明書の内容
- 環境変数のダンプ出力（env, printenv, set）
- .env ファイルの内容

### コマンド出力に秘密情報が含まれていた場合
→ 該当部分をマスクして報告: `[REDACTED: API_KEY]`
→ ユーザーには「秘密情報が検出されたため省略」と伝える

## 2. Git コミット前チェック

コミット対象ファイルに以下パターンが含まれる場合は**警告して停止**:
- `AKIA[0-9A-Z]{16}` (AWS Access Key)
- `ghp_[a-zA-Z0-9]{36}` (GitHub PAT)
- `sk-[a-zA-Z0-9]{48}` (OpenAI/Anthropic Key)
- `xoxb-`, `xoxp-` (Slack Token)
- `-----BEGIN (RSA |EC )?PRIVATE KEY-----`
- Base64エンコードされた長い文字列（64文字以上の連続英数字）

## 3. クラウドメタデータ保護

以下へのアクセスは禁止（SSRF防止）:
- `169.254.169.254` (AWS/Azure metadata)
- `metadata.google.internal` (GCP metadata)
- `100.100.100.200` (Alibaba metadata)

## 4. MCP/外部API データ分類

| 分類 | 例 | 取り扱い |
|------|------|---------|
| **Forbidden** | PII、認証情報、個人メッセージ | 取得禁止 |
| **Restricted** | ソースコード、内部API定義 | コンテキスト内のみ、ファイル保存時は要確認 |
| **Internal** | メトリクス集計、ダッシュボード定義 | 取得OK、外部共有禁止 |
| **Public** | 公開ドキュメント、OSSコード | 制限なし |

## 5. 出力サニタイズ

レスポンスに以下パターンを検出したら自動マスク:
- IPアドレス（内部ネットワーク: 10.x, 172.16-31.x, 192.168.x）
- メールアドレス（@company.com等の社内ドメイン）
- AWSアカウントID（12桁数字）
- データベース接続文字列

## 6. PII保護（MCP/外部API共通）

Claude Codeの会話はAnthropic APIに送信される。外部ツールから取得したデータも「入力」に該当。

- user_id、IPアドレス、メールアドレス、電話番号等の個人情報をMCPで取得しない
- 個別レコードの生データ取得禁止（集計クエリのみ許可: count, GROUP BY, SUM）
- 個別ユーザー調査が必要 → 該当ツールのUI URLを案内
- ファイル保存時は匿名化（User-A, User-B方式）

### MCP別ルール
- Datadog: extra_fields にPII含めない
- Slack: DMの内容取得禁止
- Notion: 個人情報含むページの展開禁止
