# 自然言語トリガー

頻用パターンのみ自然語解釈する。その他は明示コマンド（`/commandname`）を使用。

## トリガー一覧

| ユーザー入力 | 実行コマンド |
|-------------|-------------|
| "pushして", "push" | `/git-push --pr`（ブランチ作成→PR） |
| "main push", "mainにpush" | `/git-push --main`（mainブランチ直接push） |
| "sync push", "push sync" | `/git-push` → `sync.sh to-local`（ai-toolsリポジトリ時のみ） |
| "全自動で", "autoで", "おまかせ" | `/flow-auto` |
| "横並びで", "同じ修正を" | 複数リポジトリ横並び作業（multi-repo-workflow.md参照） |
| "codexでレビュー", "セカンドオピニオン" | `/review --codex` |
| "ブレスト", "設計検討", "アイデア出し" | `/brainstorm`（対話的設計精緻化） |
| "strict mode", "厳格モード" | `/session-mode strict`（本番作業向け） |
| "fast mode", "高速モード", "プロトタイプモード" | `/session-mode fast` |
| "normal mode", "通常モード" | `/session-mode normal` |

## 解釈しない例

上記以外（`修正してpush`、`grooveで`、`元に戻して`、`codexで{タスク}` 等）は自然語解釈しない。明示コマンド（例: `/groove`, `/undo`）を使う。誤判定・トークン消費を避けるため。
