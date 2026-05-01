---
name: incident-response
description: インシデント対応。エラー分類→影響判定→原因特定→チケット作成→記録の統合フロー
requires-guidelines:
  - operations
---

# incident-response - インシデント対応スキル

## インフラ障害 クイック診断

### 403 Forbidden

| チェック順 | 確認項目 | コマンド例 |
|-----------|---------|-----------|
| 1 | IAMロール/権限 | `aws iam simulate-principal-policy` |
| 2 | ALB/API Gatewayルール | ALBコンソール → ルール確認 |
| 3 | CORSヘッダー | `curl -v -X OPTIONS <URL>` |
| 4 | サービスアカウント | `kubectl describe sa <name>` |
| 5 | 直近のデプロイ変更 | `git log --oneline -10` / ArgoCD |

### ワーカー起動失敗

| チェック順 | 確認項目 | コマンド例 |
|-----------|---------|-----------|
| 1 | Pod状態確認 | `kubectl get pods -n <ns>` |
| 2 | 起動ログ確認 | `kubectl logs <pod> --previous` |
| 3 | リソース不足 | `kubectl describe node` |
| 4 | ConfigMap/Secret | `kubectl describe pod <pod>` → Events |
| 5 | DB接続/外部依存 | 接続先サービスのヘルスチェック |

> 繰り返す場合は根本原因分析（`/root-cause`）を実行し、恒久対応を必ず提案すること。

## 対応フロー

```
エラー受領 → Step 1-5 を順に実行
```

### Step 1: 分類

| 分類 | 判定基準 | 次アクション |
|------|---------|-------------|
| 既知・想定内 | 認証失敗（未登録メール等）、rate limit | ユーザーに報告して終了 |
| 既知・要対応 | 設定ミス、リソース不足、依存サービス障害 | Step 2へ |
| 未知 | 過去に見たことがないエラー | Step 2へ（優先度上げ） |
| 分類不能 | エラー情報不足（スタックトレース欠落、ログ未取得） | ユーザーに追加情報要求して停止 |

### Step 2: 影響範囲

| レベル | 条件 | 対応速度 |
|--------|------|---------|
| Critical | 本番ユーザー影響あり・データ不整合 | 即時対応 |
| High | 本番一部機能停止・tes環境全停止 | 当日中 |
| Medium | 本番ログエラーのみ・tes一部不具合 | 次スプリント |
| Low | dev環境のみ・警告レベル | バックログ |

### Step 3: 原因特定

1. エラーログからスタックトレース・エラーコード抽出
2. 関連サービスのログ横断確認（k8s pods/logs）
3. 直近のデプロイ・設定変更確認（git log/ArgoCD）
4. 根本原因特定（対症療法禁止 → `/root-cause` 参照）

調査が長引く場合は3ステップごとに「確定事項 / 未確定事項 / 次アクション / 判断必要な点」を再出力（ユーザーの「つまり？」「残タスクは？」を予防）。

### Step 4: チケット作成

Jira MCP（`mcp__jira__jira_post`）で作成。必須項目: summary（`[影響レベル] 概要`、80字以内）、description（PREP 3点: 結論=対応方針 / 理由=現象+影響範囲+原因 / 次アクション=担当+期限）、priority（影響レベル準拠）、labels（`["incident"]`）。

**投稿前 self-check（`~/.claude/rules/ai-output.md` の 4問）通過必須**。詳細ログは `<details>` 折りたたみ。違反時は draft 修正して再 self-check。

**MCP 失敗時 fallback**:

| 失敗 | 動作 |
|------|------|
| `mcp__jira__jira_post` 接続不可 | チケット本文を draft として出力フォーマットに含め、ユーザーに手動投稿案内 |
| 認証エラー | 認証 URL を提示して停止（draft は保持） |
| priority 値拒否 | `Medium` で再投稿、warning ログ |

### Step 5: 記録

Confluence MCP（`mcp__confluence__conf_post`）でインシデント記録作成、必要ならSlack通知。

**MCP 失敗時 fallback**: ローカルに `incidents/{YYYY-MM-DD}-{topic}.md` で保存、後続で手動アップロード案内。Slack 通知失敗は warning のみ（記録の方を優先）。

## 出力フォーマット

通常ケース:

```markdown
## インシデント報告

| 項目 | 内容 |
|------|------|
| 分類 | 既知/未知 |
| 影響レベル | Critical/High/Medium/Low |
| 環境 | dev/tes/prd |
| 発生日時 | YYYY-MM-DD HH:MM |

### エラー内容
（ログ引用）

### 原因
（根本原因の説明）

### 対応
- [ ] 修正方針
- [ ] チケットURL
```

原因未確定（Step 3 で特定不能時）:

```markdown
## インシデント報告（調査中）
> [WARN] 根本原因未特定。暫定対応のみ実施、継続調査が必要。

| 項目 | 内容 |
|------|------|
| 分類 | 未知 |
| 影響レベル | Critical/High/Medium/Low |

### 確定事項
- 現象: ...
- 影響範囲: ...

### 未確定事項
- 原因: 候補 A / B / C のうち切り分け未完
- 再現条件: ...

### 暫定対応
- [ ] rollback / feature flag off 等
- [ ] 継続調査タスク（担当 / 期限）
```

チケット作成失敗時:

```markdown
## インシデント報告（手動投稿要）
> [WARN] Jira MCP 失敗。下記 draft を Jira UI に手動投稿してください。

### Jira draft
- summary: [影響レベル] 概要
- description: ...
- priority: ...
- labels: ["incident"]

### 投稿先 URL
{jira-base-url}/secure/CreateIssue.jspa
```
