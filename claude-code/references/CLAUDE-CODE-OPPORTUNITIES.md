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

## 2.1.117 (2026-04-22 検出)

- [ ] **Agent frontmatter `mcpServers:` (main-thread 経由)**: `--agent` で main-thread 実行時にも agent 側 mcpServers が読み込まれる。2.1.116 の `hooks:` と同系統 — 検討箇所: `claude-code/agents/*.md`
- [ ] **Native build の Glob/Grep → Bash 統合 (bfs/ugrep)**: macOS/Linux native ビルドで Glob/Grep tool が Bash 経由の組込 bfs/ugrep に置換。ラウンドトリップ削減で高速化。npm build は影響なし — 検討箇所: `agents/*.md` の `allowed-tools` から Glob/Grep 削除可否（native 前提時のみ）

## 2.1.116 (2026-04-21 検出)

- [ ] **Agent frontmatter `hooks:` (main-thread 経由)**: `--agent` で main-thread 実行時にも agent 側 hooks が発火可能に — 検討箇所: `claude-code/agents/*.md`
- ~~**Bash tool の gh rate-limit ヒント**~~ (obsolete 2026-04-21): リポジトリ内に gh リトライロジックを持つ hooks/scripts が存在せず恩恵不要
