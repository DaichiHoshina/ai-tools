---
paths:
  - "**/*"
---
# エンタープライズセキュリティルール

## 1. シークレット漏洩防止

**絶対禁止**（レスポンス含めない）: APIキー / トークン / パスワード / クラウド認証情報 / SSH秘密鍵 / TLS証明書 / `.env` / 環境変数ダンプ（env, printenv, set）

検出時: 該当部を `[REDACTED: 種別]` でマスク + ユーザーに「秘密情報検出のため省略」と伝達

## 2. Git コミット前チェック

以下パターン検出で**警告して停止**:

| パターン | 種別 |
|---------|-----|
| `AKIA[0-9A-Z]{16}` | AWS Access Key |
| `ghp_[a-zA-Z0-9]{36}` | GitHub PAT |
| `sk-[a-zA-Z0-9]{48}` | OpenAI/Anthropic Key |
| `xoxb-`, `xoxp-` | Slack Token |
| `-----BEGIN.*PRIVATE KEY-----` | 秘密鍵 |
| 64文字以上の Base64 | 連続英数字 |

## 3. クラウドメタデータ保護（SSRF防止）

アクセス禁止: `169.254.169.254` (AWS/Azure) / `metadata.google.internal` (GCP) / `100.100.100.200` (Alibaba)

- **第一防御**: `permissions.deny` の `Bash(curl*169.254*)` 等
- **第二防御**: sandbox 有効時のみ `sandbox.network.deniedDomains` 適用（`claude --sandbox` 起動、worktree isolation、`EnterWorktree` 経由時）

## 4. MCP/外部API データ分類

| 分類 | 例 | 取り扱い |
|------|------|---------|
| Forbidden | PII、認証情報、個人メッセージ | 取得禁止 |
| Restricted | ソースコード、内部API定義 | コンテキスト内のみ、ファイル保存時要確認 |
| Internal | メトリクス集計、ダッシュボード定義 | 取得OK、外部共有禁止 |
| Public | 公開ドキュメント、OSSコード | 制限なし |

## 5. 出力サニタイズ

自動マスク対象: 内部IP（10.x / 172.16-31.x / 192.168.x） / 社内メアド / AWSアカウントID（12桁数字） / DB接続文字列

## 6. PII 保護（MCP/外部API共通）

会話は Anthropic API に送信される。外部ツール取得データも「入力」扱い。

- 個人情報（user_id / IP / メアド / 電話番号）を MCP で取得しない
- 個別レコード生データ取得禁止（集計のみ: count, GROUP BY, SUM）
- 個別ユーザー調査必要 → 該当ツールUI URL案内
- ファイル保存時は匿名化（User-A, User-B 方式）

**MCP別**: Datadog `extra_fields` PII含めない / Slack DM内容取得禁止 / Notion 個人情報ページ展開禁止
