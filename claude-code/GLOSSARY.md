# 用語集（GLOSSARY）

Claude Code 設定で使用される主要な用語の定義。

---

## Agent（エージェント）

特定の役割を持つ自律的なタスク実行者。Task toolで起動し、専門分野のタスクを担当する。

| エージェント | 役割 | 実装禁止 |
|-------------|------|:--------:|
| `po-agent` | 戦略決定・Worktree管理 | Yes |
| `manager-agent` | タスク分割・配分計画 | Yes |
| `developer-agent` | 実装担当（dev1-4で並列実行） | No |
| `explore-agent` | 探索・分析担当（explore1-4） | Yes |
| `code-simplifier` | コード簡素化 | No |
| `verify-app` | ビルド・テスト検証 | Yes |
| `workflow-orchestrator` | ワークフロー自動化 | Yes |

---

## MCP（Model Context Protocol）

Claude Codeが外部ツールと連携するためのプロトコル。

| MCP Server | 用途 |
|------------|------|
| `serena` | コード解析・メモリ管理 |
| `context7` | ライブラリドキュメント取得 |
| `jira` | Jira連携 |
| `confluence` | Confluence連携 |
| `codex` | OpenAI Codex連携 |

---

## Hook（フック）

特定のイベント発生時に自動実行されるスクリプト。

| フック | トリガー | 用途 |
|--------|----------|------|
| `session-start` | セッション開始 | Serena接続確認 |
| `user-prompt-submit` | プロンプト送信 | 技術スタック検出 |
| `pre-tool-use` | ツール実行前 | 自動処理禁止チェック |
| `post-tool-use` | ツール実行後 | 自動フォーマット |
| `pre-compact` | コンパクション前 | バックアップ |
| `stop` | 停止時 | 統計保存 |
| `session-end` | セッション終了 | 完了通知 |

---

## Skill（スキル）

特定の技術領域に関する専門知識セット。`/skill-name` で呼び出し可能。

**カテゴリ:**
- **レビュー系**: code-quality-review, security-error-review, docs-test-review, uiux-review, ui-skills
- **開発系**: go-backend, typescript-backend, react-best-practices, api-design, clean-architecture-ddd
- **インフラ系**: dockerfile-best-practices, kubernetes, terraform, docker-troubleshoot

---

## Command（コマンド）

ユーザーが `/command` 形式で呼び出すショートカット。

| コマンド | 説明 |
|---------|------|
| `/flow` | タスク自動判定→最適ワークフロー実行 |
| `/dev` | 実装モード |
| `/review` | コードレビュー |
| `/plan` | 設計・計画モード |
| `/commit` | コミット支援 |

---

## Guideline（ガイドライン）

言語・フレームワーク固有のベストプラクティス集。

**構成:**
- `summaries/` - 要約版（トークン節約用、優先読み込み）
- `languages/` - 言語固有（Go, TypeScript, React等）
- `common/` - 共通ルール
- `design/` - 設計パターン
- `infrastructure/` - インフラ関連

---

## protection-mode（Protection Mode（操作保護モード））

操作の安全性を3層で分類する思考フレームワーク。

| 層 | 分類 | 例 |
|----|------|-----|
| Safe射 | 即実行可 | Read, Glob, git status |
| Boundary射 | 要確認 | Edit, Write, git commit |
| Forbidden射 | 拒否 | rm -rf /, secrets漏洩 |

---

## Worktree

Gitの機能で、同一リポジトリから複数の作業ディレクトリを作成する。並列開発に使用。

```bash
# 作成
git worktree add -b feature/new wt-feat-new main

# 削除
git worktree remove wt-feat-new
```

---

## additionalContext

フックからモデルに追加情報を提供する仕組み（v2.1.9+）。JSON形式で返却。

```json
{
  "systemMessage": "表示メッセージ",
  "additionalContext": "モデルへの追加コンテキスト"
}
```
