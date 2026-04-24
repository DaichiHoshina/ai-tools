# Claude Code 未採用機能トラッキング

`/claude-update-fix` が検出した、リポジトリ側で採用余地のある機能を蓄積する。

## 書式

```markdown
## <バージョン> (YYYY-MM-DD 検出)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/エージェント>
```

採用時はチェック、陳腐化時は打ち消し（`~~機能名~~ (obsolete YYYY-MM-DD)`）。

**ライフサイクル**: 採用済み（チェック済み）エントリは、次回 `/claude-update-fix` 実行時に自動削除。陳腐化エントリは1バージョン後に自動削除。未採用のまま残るエントリは継続追跡。

---

## 2.1.119 (2026-04-24 検出)

- [ ] **`PostToolUse` / `PostToolUseFailure` hook に `duration_ms`**: hook 入力 JSON に実行時間が入る。`lib/analytics-writer.sh` の `tool_events.duration_ms` カラム（既存・未充填）を埋められる — 検討箇所: `claude-code/hooks/post-tool-use.sh` / `post-tool-use-failure.sh` で `jq` 抽出、`analytics_insert_tool_event` のシグネチャ拡張
- [ ] **Statusline stdin に `effort.level` / `thinking.enabled`**: 現在 Opus/Sonnet 名のみ表示。高 effort や thinking ON を視覚化できる — 検討箇所: `claude-code/statusline.js` の `displayStatusLine`
- [ ] **`prUrlTemplate` 設定**: `owner/repo#N` 等の展開先を github.com 以外（GHE/GitLab self-hosted）へ差し替え可能 — 検討箇所: `templates/settings.json.template`（社内 GitLab 環境利用時のみ有効）
- [ ] **`CLAUDE_CODE_HIDE_CWD` env var**: startup logo で cwd を隠す。機密ディレクトリや録画時に有用 — 検討箇所: `templates/settings.json.template` の `env` セクション（常時ONはtoo much、opt-in）
- [ ] **`--from-pr` GitLab/Bitbucket/GHE 対応**: `/review --from-pr <gitlab-mr-url>` 等が動くようになった — 検討箇所: `claude-code/commands/review.md`（現状 GitHub PR 前提の記述があれば汎化）

## 2.1.118 (2026-04-23 検出)

- [ ] **Hooks から MCP tool 直接呼出 (`type: "mcp_tool"`)**: shellスクリプト経由でなくhook定義から MCP tool を直接起動可能 — 検討箇所: `claude-code/hooks/*.sh`（session-end/task-completed 等で Notion/Slack を直接叩く余地）、`templates/settings.json.template` の `hooks` セクション
- [ ] **`DISABLE_UPDATES` env var**: `claude update` 手動実行も含めて完全ブロック（`DISABLE_AUTOUPDATER` より厳格）— 検討箇所: `templates/settings.json.template` / `templates/settings-ghq.json.template`。現状 `DISABLE_AUTOUPDATER` のみ。Enterprise Policy で更新完全固定したい場合のみ切替
- [ ] **`/usage` コマンド統合**: `/cost` と `/stats` が `/usage` にマージ（旧名もshortcutとして残存）— 検討箇所: `claude-code/commands/dashboard.md`, `commands/analytics.md` 等で `/cost`/`/stats` 参照していないか再確認（現状検出なし、参照形式のみ監視）
- [ ] **名前付きカスタムテーマ (`/theme` + `~/.claude/themes/`)**: JSON直接編集 or plugins `themes/` ディレクトリ配布可能 — 検討箇所: `claude-code/templates/` 配下にテーマ追加可否（現 `ui-themes/` は Tailwind トークン用で別物）

## 2.1.117 (2026-04-22 検出)

- [ ] **Agent frontmatter `mcpServers:` (main-thread 経由)**: `--agent` で main-thread 実行時にも agent 側 mcpServers が読み込まれる。2.1.116 の `hooks:` と同系統 — 検討箇所: `claude-code/agents/*.md`
- [ ] **Native build の Glob/Grep → Bash 統合 (bfs/ugrep)**: macOS/Linux native ビルドで Glob/Grep tool が Bash 経由の組込 bfs/ugrep に置換。ラウンドトリップ削減で高速化。npm build は影響なし — 検討箇所: `agents/*.md` の `allowed-tools` から Glob/Grep 削除可否（native 前提時のみ）

## 2.1.116 (2026-04-21 検出)

- [ ] **Agent frontmatter `hooks:` (main-thread 経由)**: `--agent` で main-thread 実行時にも agent 側 hooks が発火可能に — 検討箇所: `claude-code/agents/*.md`
