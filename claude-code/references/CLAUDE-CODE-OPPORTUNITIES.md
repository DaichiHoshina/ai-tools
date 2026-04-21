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

## 2.1.116 (2026-04-21 検出)

- [ ] **Agent frontmatter `hooks:` (main-thread 経由)**: `--agent` で main-thread 実行時にも agent 側 hooks が発火可能に — 検討箇所: `claude-code/agents/*.md`
- [ ] **Bash tool の gh rate-limit ヒント**: `gh` コマンドで GitHub API rate limit に達した際に backoff ヒントを surface — 検討箇所: リトライロジックを持つ hooks/scripts
