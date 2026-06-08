# Claude Code 未採用機能トラッキング

`/claude-update-fix` が検出した、リポジトリ側で採用余地のある機能を蓄積する。

## 書式

```markdown
## <バージョン> (YYYY-MM-DD 検出, <channel>)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/エージェント>
```

`<channel>` = `stable` / `latest` (`/claude-update-fix` Phase 1 で確定)。後の channel switch 時に履歴スコープが追える。

採用時はチェック、陳腐化時は打ち消し（`~~機能名~~ (obsolete YYYY-MM-DD): <1文の理由>`）。理由欄は必須（3か月後の検証コスト回避のため）。

**ライフサイクル**: 採用済み（チェック済み）エントリは、次回 `/claude-update-fix` 実行時に自動削除。陳腐化エントリは1バージョン後に自動削除。未採用のまま残るエントリは継続追跡。

---

## 2.1.153 (2026-06-05 検出, stable)

新規 Opportunity なし。2.1.153 単一バージョン範囲、リポジトリ影響 grep 確認済み（`modelPicker:setAsDefault` keybinding 不在 / `--strict-mcp-config` 利用なし / `skipLfs` は marketplace LFS opt-in で現 source 影響なし）。

- `modelPicker:setAsDefault` → `modelPicker:thisSessionOnly` rename [2.1.153]: custom keybindings.json 不在のため影響なし、skip
- `/model` 既定保存挙動 (selection を新 session default 化、`s` で session-only) [2.1.153]: harness 既定挙動変更、設定不要
- `skipLfs` plugin marketplace option [2.1.153]: LFS 未使用 marketplace source のため採用余地なし、skip
- 残りは bugfix（MCP reconnect-loop / API gateway credential / subagent MCP `--strict-mcp-config` 尊重 / Windows installer / background session 多数 / VSCode shutdown 等）— 設定変更不要

## 2.1.152 (2026-06-04 検出, stable)

- [x] **`MessageDisplay` hook event**: defer (hook 増殖回避)。新規 hook ファイル追加を避ける方針のため採用しない。jp-quality の出力側 block が必要になった場合に再評価する。
- [x] **`SessionStart` hook `hookSpecificOutput.sessionTitle`**: 採用済み。`hooks/session-start.sh` に `hookSpecificOutput.sessionTitle` 出力を追加。値: `<repo名> @ <branch名>` 形式 (git repo でない場合は repo 名のみ)。settings.json root key ではなく hook output フィールドが正しい採用先であることを 2.1.152 バイナリのソースから確認済み。
- [x] **skill/slash command frontmatter `disallowed-tools`**: 採用済み。`skills/jp-writing/skill.md` に `disallowed-tools: [Bash, Edit, Write]` を追加。writing チェック専用 skill でコード編集 tool を除外することで誤操作を防ぐ。settings.json root key ではなく skill/command frontmatter フィールドが正しい採用先であることを 2.1.152 バイナリのソースから確認済み。

その他は track only (採用余地小): `/reload-skills` (動的 skill 追加運用なし) / `SessionStart` `reloadSkills: true` (同左) / `pluginSuggestionMarketplaces` (admin allowlist 用途、個人環境不要) / `marketplace remove --scope` (marketplace 操作なし) / `OTEL_METRICS_INCLUDE_ENTRYPOINT` (OTEL 未使用) / `fallback-model` 自動切替 / Auto mode no-consent / Vim `/` reverse search / `/usage` session-files / 多数 UI/bugfix。`/simplify` 復活 (`/code-review --fix` 化) は 2.1.148 時点で「不採用、参照削除済」決定済、現状維持。

## 2.1.150 (2026-06-01 検出, stable)

新規 Opportunity なし。2.1.149〜2.1.150 範囲、CHANGELOG は internal infrastructure improvements のみ (user-facing changes なし)。設定変更不要。

## 2.1.148 (2026-05-30 検出, stable)

新規 Opportunity なし。2.1.146〜2.1.148 範囲、リポジトリ影響 grep 確認済み。

- `/simplify` → `/code-review` rename [2.1.147]: 用途変質 (post-impl bundle fast execute → diff correctness review @ effort level) のため単純 rename 不採用、`commands/flow.md` Auto-apply 表 / `references/skill-tool-invocation.md` / `references/command-resource-map.md` の `simplify` 参照を全削除 (post-impl は `/lint-test` で代替済)
- 2.1.146 Opus 4.8 thinking block fix: bugfix のみ、設定影響なし
- 2.1.148 Bash exit code 127 regression fix: bugfix のみ、設定影響なし
- 2.1.147 その他: 多数 bugfix (auto-updater retry / prompt history dedup / PowerShell 系 / Windows terminal 系 / `/help` / `/effort` / `/theme` / `/background` / MCP pagination / hook `if` PowerShell マッチ / `CLAUDE_CODE_SUBAGENT_MODEL` teammate fix 等) — 当方未使用 or 既設挙動 OK、設定変更不要

## 2.1.145 (2026-05-28 検出, stable)

新規 Opportunity なし。2.1.143〜2.1.145 範囲、リポジトリ影響 grep 確認済み。

- `/extra-usage` → `/usage-credits` rename: 当方未使用、旧名動作継続のため skip
- `worktree.bgIsolation: "none"` setting: 当方 bg session 未使用、skip
- `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY` / `CLAUDE_CODE_USE_POWERSHELL_TOOL`: Windows のみ、skip
- `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`: stop hook block ループ救済 env、当方 stop hook は block しない設計、skip
- Stop/SubagentStop hook input に `background_tasks` / `session_crons` 追加 [2.1.145]: 当方 stop/subagent-stop hook は notification 専用で field 未参照、活用余地なし。bg session/cron 利用開始時に再評価
- `claude agents --json` [2.1.145]: scripting/statusline 用途、`statusline.js` は session JSON 直接受領のため不要
- OTEL `agent_id` / `parent_agent_id` spans [2.1.145]: OTEL 未使用、skip
- Read tool PARTIAL view notice [2.1.145]: harness 自動挙動、設定不要

## 2.1.142 (2026-05-15 検出, stable)

新規 Opportunity なし。全エントリ bugfix/Info（Fast mode default Opus 4.7 化 + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` pin env、`claude agents` 起動フラグ拡張 `--add-dir`/`--settings`/`--mcp-config`/`--plugin-dir`/`--permission-mode`/`--model`/`--effort`/`--dangerously-skip-permissions`、plugin root-level `SKILL.md` 単独サポート、`MCP_TOOL_TIMEOUT` 60s cap fix、background sessions worktree/sleep-wake/upgrade 周り fix、reactive compaction 改善、SessionStart/Setup/SubagentStart に prompt/agent type hook 指定時のエラーメッセージ改善 等）。リポジトリ影響 grep 確認済み（`/fast` 不使用 / 旧 sonnet ID 不在 / 既存 hook 全 type=command / `MCP_TOOL_TIMEOUT` 不使用）。

## 2.1.141 (2026-05-14 検出)

その他 (Info/bugfix のみ): `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` (SSH 鍵なし環境、当方 SSH 鍵あり影響なし)、`ANTHROPIC_WORKSPACE_ID` (workload identity federation、未使用)、`claude agents --cwd`、`/feedback` recent sessions、Rewind "Summarize up to here"、spinner amber、plugin menu 改善。`terminalSequence` 採用済 (stop/stop-failure)。

## 2.1.140 (2026-05-13 検出)

新規 Opportunity なし。全エントリ bugfix/Info（`subagent_type` case-insensitive 化、`/goal` hang fix、settings hot-reload、`Read` offset whitespace 許容、Plugins folder 無視警告 等）。リポジトリ側影響箇所 grep 確認済み（`plugin.json` 不在、whitespace-offset 利用なし）。

## 2.1.139 (2026-05-12 検出)

- [ ] **hook `args: string[]` (exec form)**: shell を介さず直接 spawn、path 引数の quoting 不要 — 検討箇所: `claude-code/templates/settings.json.template` の hooks セクション。**技術的障壁** (2026-05-22 再検証): 公式 docs (`code.claude.com/docs/en/hooks`) で exec form では `~` / `$HOME` **展開不可**と明言、user-scope global hook 用の placeholder (`${CLAUDE_USER_HOME}` 等) は未提供。利用可能 placeholder は `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}` の3つのみ。現状 user-scope hook 12 個全て `~/.claude/hooks/*.sh` 起動のため exec form 化は絶対パスハードコード必須 = template 移植性破壊。Claude Code 側に user-global placeholder 追加されるまで保留 (再検証は次マイナー更新時)
