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

## 2.1.122 (2026-04-29 検出)

- [x] **`/resume` 検索で PR URL 受付** (採用 2026-04-29): `references/session-management.md` に追記済（運用 tips、コード変更不要）
- ~~**`ANTHROPIC_BEDROCK_SERVICE_TIER` env var**~~ (obsolete 2026-04-29): Anthropic 直接 API 利用、Bedrock 未使用
- ~~**OpenTelemetry `claude_code.at_mention` log event**~~ (obsolete 2026-04-29): OTel 集計基盤未実装、計測項目追加の前段階が無い
- ~~**malformed `hooks` entry が settings.json 全体を無効化しなくなった**~~ (obsolete 2026-04-29): Info、防御的改善のみで採用判断不要

## 2.1.121 (2026-04-28 検出)

- [x] **MCP server `alwaysLoad: true` オプション** (採用 2026-04-29): `templates/.mcp.json.template`、`templates/settings-ghq.json.template`、`settings/mcp-servers/serena.json.template` の serena に適用済
- [ ] **PostToolUse `hookSpecificOutput.updatedToolOutput` 全tool拡張** (旧 MCP-only): hook が tool 出力を書き換え可能。秘密情報マスク、長文要約等に応用余地 — 検討箇所: `claude-code/hooks/post-tool-use.sh`（`enterprise-security.md` の出力サニタイズ実装基盤）。**重量実装、別タスク化**
- ~~**`claude plugin prune` / `plugin uninstall --prune`**~~ (obsolete 2026-04-29): Info、ドキュメント参照のみで採用なし

## 2.1.120 (2026-04-26 検出)

- [x] **`claude ultrareview [target]` 非対話 subcommand** (採用 2026-04-29): `commands/review.md` に CI 連携記述追加済
- [x] **Skills 内 `${CLAUDE_EFFORT}` 変数展開** (採用 2026-04-29): `skills/comprehensive-review/skill.md` に effort 連動モード追加済（dev skill は不在のため対象外）

## 2.1.119 (2026-04-24 検出)

- [x] **Statusline stdin に `effort.level` / `thinking.enabled`** (採用 2026-04-29): `claude-code/statusline.js` に effort `high`/`low` バッジ + thinking 💭 表示追加済
- ~~**`prUrlTemplate` 設定**~~ (obsolete 2026-04-29): 社内 GitLab self-hosted 未使用、github.com のみ
- ~~**`CLAUDE_CODE_HIDE_CWD` env var**~~ (obsolete 2026-04-29): opt-in 用途で常時 ON 不要、必要時のみ手動

## 2.1.118 (2026-04-23 検出)

- [ ] **Hooks から MCP tool 直接呼出 (`type: "mcp_tool"`)**: shellスクリプト経由でなくhook定義から MCP tool を直接起動可能 — 検討箇所: `claude-code/hooks/*.sh`（session-end/task-completed 等で Notion/Slack を直接叩く余地）、`templates/settings.json.template` の `hooks` セクション。**重量実装、別タスク化**
- ~~**`DISABLE_UPDATES` env var**~~ (obsolete 2026-04-29): `DISABLE_AUTOUPDATER` で十分、Enterprise Policy 用途は不要
- ~~**`/usage` コマンド統合**~~ (obsolete 2026-04-29): 監視のみ、リポジトリ内に `/cost` / `/stats` 参照なし
- ~~**名前付きカスタムテーマ (`/theme` + `~/.claude/themes/`)**~~ (obsolete 2026-04-29): 適用余地小、`ui-themes/` は Tailwind トークン用で別物

## 2.1.117 (2026-04-22 検出)

- ~~**Agent frontmatter `mcpServers:` (main-thread 経由)**~~ (obsolete 2026-04-29): リポジトリ内で `--agent` 経由 main-thread 実行を使用していない
- ~~**Native build の Glob/Grep → Bash 統合 (bfs/ugrep)**~~ (obsolete 2026-04-29): native ビルド使用中だが、agent の `allowed-tools` 削除はパフォーマンス改善のみで現状で問題なし

## 2.1.116 (2026-04-21 検出)

- ~~**Agent frontmatter `hooks:` (main-thread 経由)**~~ (obsolete 2026-04-29): リポジトリ内で `--agent` 経由 main-thread 実行を使用していない
