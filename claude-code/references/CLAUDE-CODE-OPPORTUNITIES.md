# Claude Code 未採用機能トラッキング

`/claude-update-fix` が検出した、リポジトリ側で採用余地のある機能を蓄積する。

## 書式

```markdown
## <バージョン> (YYYY-MM-DD 検出)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/エージェント>
```

採用時はチェック、陳腐化時は打ち消し（`~~機能名~~ (obsolete YYYY-MM-DD): <1文の理由>`）。理由欄は必須（3か月後の検証コスト回避のため）。

**ライフサイクル**: 採用済み（チェック済み）エントリは、次回 `/claude-update-fix` 実行時に自動削除。陳腐化エントリは1バージョン後に自動削除。未採用のまま残るエントリは継続追跡。

---

## 2.1.126 (2026-05-02 検出)

- [ ] **`claude project purge [path]` サブコマンド**: プロジェクト state（transcripts/tasks/file history/config entry）を一括削除。`--dry-run` / `-y` / `-i` / `--all` 対応 — 検討箇所: `claude-code/references/session-management.md`（トラブルシュート節）, `claude-code/SETUP.md`

## 2.1.121 (2026-04-28 検出)

- [ ] **PostToolUse `hookSpecificOutput.updatedToolOutput` 全tool拡張** (旧 MCP-only): hook が tool 出力を書き換え可能。秘密情報マスク、長文要約等に応用余地 — 検討箇所: `claude-code/hooks/post-tool-use.sh`（`enterprise-security.md` の出力サニタイズ実装基盤）。**重量実装、別タスク化**

## 2.1.118 (2026-04-23 検出)

- [ ] **Hooks から MCP tool 直接呼出 (`type: "mcp_tool"`)**: shellスクリプト経由でなくhook定義から MCP tool を直接起動可能 — 検討箇所: `claude-code/hooks/*.sh`（session-end/task-completed 等で Notion/Slack を直接叩く余地）、`templates/settings.json.template` の `hooks` セクション。**重量実装、別タスク化**
