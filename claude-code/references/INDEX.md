# References Index

主要トピックの索引 (CLAUDE.md からオンデマンドで参照)。

**未収録ルール** (`ls references/` で探索):
- `*-template.md` (例外: `performance-issue-template.md` は運用手順を兼ねるため掲載)
- `*-OPPORTUNITIES.md` (機能 backlog トラッカー、随時更新で目次に不向き)
- `health-snapshots/` (月次スナップショット、月別 dir 直接参照)
- `INDEX.md` (自身)

## モデル選択 / セッション管理

| トピック | ファイル |
|---------|---------|
| モデル選択・effort | `model-selection.md` |
| セッション管理 | `session-management.md` |
| Checkpoint / Rewind | `checkpoint-rewind.md` |
| claude -p Fan-out | `fanout-recipes.md` |
| Agent コスト実測 | `performance-insights.md` |

## トリガー / コマンド

| トピック | ファイル |
|---------|---------|
| 自然言語トリガー全リスト | `natural-language-triggers.md` |
| レビューコマンド使い分け | `review-commands.md` |
| レビュー mode 詳細 (deep / multi 集約) | `review-modes-advanced.md` |
| コマンド × リソース対応 | `command-resource-map.md` |
| skillOverrides 設計指針 | `skill-overrides-guide.md` |
| guideline 自動 trigger 一覧 | `guideline-triggers.md` |
| Skill tool 呼び出し pattern (forked exec) | `skill-tool-invocation.md` |

## ワークフロー

| トピック | ファイル |
|---------|---------|
| 複数リポジトリ横並び | `multi-repo-workflow.md` |
| 設計フェーズ遷移 | `design-phase-flow.md` |
| チケット→PR完成までの段階制 | `ticket-to-pr-workflow.md` |
| インシデント対応フロー | `incident-flow.md` |
| Compounding Engineering | `compounding-engineering-cycle.md` |
| 並列実行パターン (worktree 判定) | `PARALLEL-PATTERNS.md` |

## 思考フレームワーク

| トピック | ファイル |
|---------|---------|
| AI 思考の基本姿勢 | `AI-THINKING-ESSENTIALS.md` |
| 設計判断の品質チェック | `decision-quality-checklist.md` |

## ドキュメント執筆

| トピック | ファイル |
|---------|---------|
| DesignDoc 書き方・粒度 | `../guidelines/writing/design-doc-protocol.md` |
| PRD レビュー観点 | `prd-review-checkpoints.md` |
| パフォーマンス改善 issue | `performance-issue-template.md` |
| レビュー指摘パターン集 | `review-patterns-universal.md` |
| ドキュメント書き直し | `document-iteration-patterns.md` |
| 文章執筆 共通原則 | `../guidelines/writing/PRINCIPLES.md` |
| 文章執筆 補足パターン (書き直し Phase / textlint 等) | `writing-patterns.md` |

## Serena / MCP

| トピック | ファイル |
|---------|---------|
| Serena cc-system-prompt-override 設定 | `serena-cc-prompt-setup.md` |

## その他

| トピック | ファイル |
|---------|---------|
| メモリ使い分け | `memory-usage.md` |
| memory → CLAUDE.md / ai-tools 昇格 flow と振り分け基準 | `memory-promotion-flow.md` |
| UIデフォルト設定 | `ui-defaults.md` |
| Private 設定の保管規約 | `private-config-convention.md` |
| Plugin marketplace caveats (連鎖 uninstall) | `plugin-marketplace-caveats.md` |
| CodeRabbit プラグイン cheat sheet | `coderabbit-plugin.md` |
| Claude Code 公式 best practices (JA) | https://code.claude.com/docs/ja/best-practices |
