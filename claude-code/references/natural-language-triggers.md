# Natural Language Triggers

Only high-frequency patterns are interpreted from natural language. For others, use explicit commands (`/commandname`).

## Trigger list

| User input | Command executed |
|------------|----------------|
| "pushして", "push" | `/git-push --pr` (create branch → PR) |
| "main push", "mainにpush" | `/git-push --main` (push directly to main) |
| "sync push", "push sync" | `/git-push` → `sync.sh to-local` (ai-tools repo only) |
| "全自動で", "autoで", "おまかせ" | `/flow --auto` |
| "横並びで", "同じ修正を" | Multi-repo parallel work (see `references/_archive/multi-repo-workflow.md`) |
| "レビュー", "レビューして", "コードレビュー" | `/review` (default, mode auto-detected internally) |
| "PR<番号>レビュー", "<PR-URL>レビュー" | `/review <PR>` |
| "codexでレビュー", "セカンドオピニオン" | `/review --codex` |
| "設計レビュー", "敵対レビュー", "設計問い詰め", "アーキテクチャレビュー" | `/review --adversarial` (codex adversarial-review delegation) |
| "深掘りレビュー", "厳しめレビュー", "徹底レビュー", "詳細レビュー" | `/review --deep` (pr-review-toolkit 6 agents parallel) |
| "リリース前レビュー", "PR最終レビュー", "全部入りレビュー", "全力レビュー" | `/review --multi <PR>` (4 methods parallel, max cost) |
| "クラウドでレビュー", "ultrareview" | `/ultrareview` (cloud parallel, separate billing) |
| "ブレスト", "設計検討", "アイデア出し" | `/brainstorm` (interactive design refinement) |
| "API 設計", "API 設計して" | `/api-design` (API endpoint design / OpenAPI spec) |
| "バックエンド", "バックエンド実装" | `/backend-dev` (backend implementation / API development) |
| "strict mode", "厳格モード" | `/session-mode strict` (for production work) |
| "fast mode", "高速モード", "プロトタイプモード" | `/session-mode fast` |
| "normal mode", "通常モード" | `/session-mode normal` |
| "並列実行で" | `/flow --parallel` (worktree proposal, PO confirmation required) |
| "Developer 並列で" | `/flow --parallel` (same) |
| "worktree 分けて" | `/flow --parallel` (same) |
| "wt 分けて" | `/flow --parallel` (same) |
| "team で", "agent team で" | `/flow` (force PO/Manager/Dev hierarchy) |
| "分担で", "本格的に" | `/flow` (same, skip lightweight task pre-check) |
| "workflow で", "pipeline で", "多数決で" | `/workflow` (deterministic fan-out via Workflow tool; 5 templates: review / migrate / research / understand / judge-panel) |
| "Slack に投げて", "Slack に送って" | `mcp__claude_ai_Slack__slack_send_message` (confirm channel/DM first) |
| "Notion に書いて", "Notion メモして" | `mcp__claude_ai_Notion__notion-create-pages` (confirm parent page first) |
| "PR コメント残して", "レビューコメント残して" | `/post-comment` (PR number/URL required) |
| "local-docs cleanup", "archive に送って", "不要な doc を整理", "released プロジェクトの cleanup" | `/local-docs-cleanup` (scan released projects, propose archive list, move to ../local-docs-archive/) |
| "Cursor 設定見直し", "cursor 監査", "cursor review" | `/cursor-review` (settings/rules/memories 3-axis audit) |
| "Cursor メンテ", "cursor ブラッシュアップ" | `/cursor-review` or read `cursor/MAINTENANCE.md` |

## Not interpreted

Inputs not listed above (`修正してpush`, `元に戻して`, `codexで{task}` etc.) are not interpreted from natural language. Use explicit commands (e.g., `/undo`). Avoids misinterpretation and token waste.
