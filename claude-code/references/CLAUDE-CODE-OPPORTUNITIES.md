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
- ~~**Bash tool の gh rate-limit ヒント**~~ (obsolete 2026-04-21): リポジトリ内に gh リトライロジックを持つ hooks/scripts が存在せず恩恵不要

## 2.1.108〜2.1.113 (2026-04-21 遡及検出)

- [x] **`xhigh` effort level (Opus 4.7)**: `high` と `max` の中間。深いタスクで速度と精度をバランス — 採用: `claude-code/CLAUDE.md` effort 表に追加 (2026-04-21)
- [x] **`sandbox.network.deniedDomains`**: 広い `allowedDomains` 下で特定ドメインをブロック可能。SSRF防止補強 — 採用: `templates/settings.json.template` にクラウドメタデータIP 3件追加 (2026-04-21)
- [x] **`/ultrareview` (built-in)**: クラウドで並列マルチエージェントレビュー。PR番号指定も可 — 採用: `commands/review.md` に `--ultra` オプション追加 (2026-04-21)
