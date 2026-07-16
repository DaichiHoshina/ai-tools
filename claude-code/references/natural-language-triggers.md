# Natural Language Triggers

Only high-frequency patterns are interpreted from natural language. For others, use explicit commands (`/commandname`).

## Trigger list

| User input | Command executed |
|------------|----------------|
| "pushして", "push" | `/git-push --pr` (create branch → PR) |
| "main push", "mainにpush" | `/git-push --main` (push directly to main) |
| "sync push", "push sync" | `/git-push` → `sync.sh to-local` (ai-tools repo only) |
| "syncして", "sync して", "同期して" | `sync-to-local` skill (`sync.sh to-local` 実行、ai-tools repo only) |
| "issueベースで開発", "issue 起点で", "issue 駆動で" | `issue-dev-flow` skill (issue → SoT 確認 → 影響分析 → PR 分割 → 順次 merge) |
| "影響分析して", "影響範囲を調べて" | `impact-analysis` skill (fan-in → 層判定 → DB 4 経路 → 影響表) |
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
| "設計して", "設計相談", "設計から入りたい" | `mino-problem-framing` skill 起点で mino design suite を選択 (問題整理 → 必要な設計 skill へ)。「設計検討」「設計レビュー」「API 設計」はより具体的な既存 trigger が優先 |
| "問題整理して", "前提整理して", "問題を定義して" | `mino-problem-framing` skill (観測・解釈・問題・候補手段の分離 → Problem Framing Package) |
| "モデル監査して", "モデル漏れ確認" | `mino-domain-model-completeness` skill (概念・状態・制約・失敗の欠落監査) |
| "契約に落として", "契約テスト仕様にして" | `mino-design-by-contract` skill (事前/事後/不変条件・失敗保証・契約テスト) |
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
| "ループで回して", "回し続けて", "通るまで回して" | `/loop` (gate 明示あり → init→run、なし → 4 条件 pre-check から。≤5 iter 見込みの短期は `/goal` を優先) |
| "定期実行して", "毎朝回して", "cron にして" | `/loop cron` (manual run の Status: done 実績が必須、なければ先に `/loop run`) |
| "夜通しで回して", "無人で回して" | `/loop run --bg` (external headless loop を background 起動) |
| "Slack に投げて", "Slack に送って" | `mcp__claude_ai_Slack__slack_send_message` (confirm channel/DM first) |
| "Notion に書いて", "Notion メモして" | `mcp__claude_ai_Notion__notion-create-pages` (confirm parent page first) |
| "PR コメント残して", "レビューコメント残して" | `/post-comment` (PR number/URL required) |
| "local-docs cleanup", "archive に送って", "不要な doc を整理", "released プロジェクトの cleanup" | `/local-docs-cleanup` (scan released projects, propose archive list, move to ../local-docs-archive/) |
| "Cursor 設定見直し", "cursor 監査", "cursor review" | `/cursor-review` (settings/rules/memories 3-axis audit) |
| "Cursor メンテ", "cursor ブラッシュアップ" | `/cursor-review` or read `cursor/MAINTENANCE.md` |

## Not interpreted

Inputs not listed above (`修正してpush`, `元に戻して`, `codexで{task}` etc.) are not interpreted from natural language. Use explicit commands (e.g., `/undo`). Avoids misinterpretation and token waste.
