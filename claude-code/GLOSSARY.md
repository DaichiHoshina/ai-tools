# 用語集（GLOSSARY）

Claude Code 設定で使用される主要用語の single source。各概念の詳細は表内のリンク先を参照。

## Agent（エージェント）

特定の役割を持つタスク実行者。`Task` tool で起動、専門分野を担当。詳細・コスト・コマンド対応: [agents/README.md](./agents/README.md)。

| エージェント | 役割 |
|-------------|------|
| `po-agent` | 戦略決定・Worktree 管理 |
| `manager-agent` | タスク分割・配分計画 |
| `developer-agent` | 実装担当（dev1-4 並列） |
| `explore-agent` | 探索・分析（explore1-4） |
| `reviewer-agent` | レビュー担当 |
| `verify-app` | ビルド・テスト検証 |
| `root-cause-analyzer` | 根本原因分析 |

## MCP（Model Context Protocol）

Claude Code が外部ツールと連携するためのプロトコル。

| MCP Server | 用途 |
|-----------|------|
| `serena` | コード解析・メモリ管理 |
| `context7` | ライブラリドキュメント取得 |
| `codex` | OpenAI Codex 連携 |

## Hook（フック）

特定イベント発生時に自動実行されるスクリプト。全 18 件・性能実測値: [hooks/README.md](./hooks/README.md) / [references/performance-insights.md](./references/performance-insights.md)。

主要 Hook（抜粋）:

| Hook | トリガー | 用途 |
|------|---------|------|
| `session-start` | セッション開始 | Serena 接続確認 |
| `user-prompt-submit` | プロンプト送信 | 技術スタック検出 |
| `pre-tool-use` | ツール実行前 | secret 検出・自動処理禁止チェック |
| `post-tool-use` | ツール実行後 | 出力 sanitize・自動フォーマット |
| `pre-compact` / `post-compact-reload` | コンパクション前後 | バックアップ・context 再注入 |
| `stop` / `session-end` | 停止・終了時 | 統計保存・完了通知 |

## Skill（スキル）

特定技術領域の専門知識セット。`/skill-name` で呼び出し可能。一覧・依存関係: [SKILLS-MAP.md](./SKILLS-MAP.md)。

## Command（コマンド）

`/command` 形式で呼び出すショートカット。一覧: [COMMANDS-GUIDE.md](./COMMANDS-GUIDE.md)。

## Guideline（ガイドライン）

言語・フレームワーク固有のベストプラクティス集（on-demand load）。

- `languages/` - 言語固有（Go, TypeScript, React 等）
- `common/` - 共通ルール
- `design/` - 設計パターン
- `infrastructure/` - インフラ関連
- `backend/` - バックエンド設計
- `operations/` - 運用
- `writing/` - 人間向け文章執筆原則

## protection-mode（操作保護モード）

操作の安全性を3層で分類する思考フレームワーク。

| 層 | 例 |
|----|-----|
| 安全操作（即実行） | Read, Glob, git status |
| 要確認操作 | Edit, Write, git commit |
| 禁止操作（拒否） | rm -rf /, secrets 漏洩 |

## Worktree

Git 機能、同一リポジトリから複数の作業ディレクトリを作成。並列開発に使用。

```bash
git worktree add -b feature/new wt-feat-new main
git worktree remove wt-feat-new
```

## additionalContext

Hook からモデルに追加情報を提供する仕組み（v2.1.9+）。JSON 形式で返却。

```json
{
  "systemMessage": "表示メッセージ",
  "additionalContext": "モデルへの追加コンテキスト"
}
```
