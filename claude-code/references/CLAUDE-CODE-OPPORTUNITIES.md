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

## 2.1.143 (2026-05-16 検出)

新規 Opportunity なし。全エントリ bugfix/Info（`worktree.bgIsolation: "none"` setting [worktree impractical 環境向け、当方 `/flow --parallel` で wt 活用中ゆえ N/A]、`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` env [stop.sh/stop-failure.sh/subagent-stop.sh は通知のみで非 block、N/A]、`claude agents` dashboard への `--permission-mode`/`--model`/`--effort`/`--dangerously-skip-permissions` 適用拡大 [2.1.142 で記録済み、運用変更不要]、plugin dependency enforcement、`/plugin` marketplace 推定 token cost、Shift+Tab auto mode cycle、`/loop` Esc キャンセル fix、markdown table 描画 fix、その他 50+ bugfix）。Windows/PowerShell/Bedrock/Vertex/Foundry 系は環境的に N/A。リポジトリ影響 grep 確認済み（`bgIsolation` 不在、stop hook 全て exit 0）。

## 2.1.142 (2026-05-15 検出)

新規 Opportunity なし。全エントリ bugfix/Info（Fast mode default Opus 4.7 化 + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` pin env、`claude agents` 起動フラグ拡張 `--add-dir`/`--settings`/`--mcp-config`/`--plugin-dir`/`--permission-mode`/`--model`/`--effort`/`--dangerously-skip-permissions`、plugin root-level `SKILL.md` 単独サポート、`MCP_TOOL_TIMEOUT` 60s cap fix、background sessions worktree/sleep-wake/upgrade 周り fix、reactive compaction 改善、SessionStart/Setup/SubagentStart に prompt/agent type hook 指定時のエラーメッセージ改善 等）。リポジトリ影響 grep 確認済み（`/fast` 不使用 / 旧 sonnet ID 不在 / 既存 hook 全 type=command / `MCP_TOOL_TIMEOUT` 不使用）。

## 2.1.141 (2026-05-14 検出)

その他 (Info/bugfix のみ): `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` (SSH 鍵なし環境、当方 SSH 鍵あり影響なし)、`ANTHROPIC_WORKSPACE_ID` (workload identity federation、未使用)、`claude agents --cwd`、`/feedback` recent sessions、Rewind "Summarize up to here"、spinner amber、plugin menu 改善。`terminalSequence` 採用済 (stop/stop-failure)。

## 2.1.140 (2026-05-13 検出)

新規 Opportunity なし。全エントリ bugfix/Info（`subagent_type` case-insensitive 化、`/goal` hang fix、settings hot-reload、`Read` offset whitespace 許容、Plugins folder 無視警告 等）。リポジトリ側影響箇所 grep 確認済み（`plugin.json` 不在、whitespace-offset 利用なし）。

## 2.1.139 (2026-05-12 検出)

- [ ] **hook `args: string[]` (exec form)**: shell を介さず直接 spawn、path 引数の quoting 不要 — 検討箇所: `claude-code/templates/settings.json.template` の hooks セクション。**技術的障壁** (2026-05-15 再検証): 公式 docs (`code.claude.com/docs/en/hooks`) で exec form では `~` / `$HOME` **展開不可**と明言、user-scope global hook 用の placeholder (`${CLAUDE_USER_HOME}` 等) は未提供。利用可能 placeholder は `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}` の3つのみ。現状 user-scope hook 12 個全て `~/.claude/hooks/*.sh` 起動のため exec form 化は絶対パスハードコード必須 = template 移植性破壊。Claude Code 側に user-global placeholder 追加されるまで保留 (再検証は次マイナー更新時)
