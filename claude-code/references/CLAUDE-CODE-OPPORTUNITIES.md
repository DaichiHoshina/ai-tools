# Claude Code Unadopted Features Tracking

`/claude-update-fix` accumulates detected features with adoption potential.

## Format

```markdown
## <version> (detected YYYY-MM-DD, <channel>)
- [ ] **<feature>**: <summary> — candidate: <file/agent>
```

`<channel>` = `stable` / `latest` (finalized in `/claude-update-fix` Phase 1). Allows tracking scope across channel switches.

On adoption: check the box. On obsolescence: strikethrough (`~~feature~~ (obsolete YYYY-MM-DD): <1-line reason>`). Reason is required (avoids re-investigation cost 3 months later).

**Lifecycle**: Checked entries are auto-deleted on the next `/claude-update-fix` run. Obsolete entries are auto-deleted one version later. Unchecked entries remain tracked.

---

## Channel switch back: latest → stable (2026-06-23)

User 明示判断で channel を `latest` (2026-06-14 切替) から `stable` に戻した。local CLI = 2.1.177 = `dist-tags.stable` に揃え、VERSION も 2.1.177 へ downgrade。

**deferred entries (stable 範囲外、latest 復帰時に再評価)**: 後述の 2.1.182–2.1.185 section は latest channel 時の調査結果。stable channel では fetch range 対象外のため新規 adopt は行わない。section 自体は再評価用に保持する (latest 復帰時に該当 entry のみ再活性化)。2.1.181 entry は本 run で stable section へ昇格 (`dist-tags.stable` が 2.1.181 に到達)。

## 2.1.188–2.1.191 (detected 2026-07-03, stable)

Range 2.1.188–2.1.191 が新 stable tag として確定 (2.1.191 = `dist-tags.stable`)。CLI 既に 2.1.191 一致、VERSION のみ 2.1.187 → 2.1.191 bump。2.1.188 / 2.1.189 は npm 未公開の skipped release、2.1.190 は bugfix-only。2.1.191 の主要変更を評価した結果、config 必須変更なし。

- **`/rewind` が `/clear` 越えの resume 対応** [2.1.191]: built-in `/rewind` が `/clear` 前の会話まで遡って resume 可能に。repo の `commands/rewind.md` は独自 skill (CLAUDE.md + auto-memory reload) で built-in と用途別、影響なし。CLAUDE.md § Rewind / Context Management の記述 (「Esc ×2 or `/rewind`: restore to checkpoint」) は `references/checkpoint-rewind.md` 側の詳細更新が候補だが、参照先が既に built-in checkpoint 動作を汎用的に説明していれば追記不要。Track only。
- **hooks comma-separated matcher fix** [2.1.191]: `"Bash,PowerShell"` 型 matcher が silently fire しなかった bug の fix。現 `templates/settings.json.template` は matcher を全て `*` / `""` / 単一 pattern (`mcp__serena__*`) で記述、comma-separated 未使用のため影響なし。将来 tool 別 hook を分岐する余地が生まれた (例: `"Bash,mcp__serena__execute_shell_command"` で shell 系のみ block)。Opportunity 候補、現状は tool 別 matcher 分割の必要性なし。Track only。
- **`forceRemoteSettingsRefresh` の MDM/file policy 反映 fix** [2.1.191]: managed settings 用 fix、個人 CLI 環境 (MDM 非適用) で対象外。Info。
- **sandbox network permission 記憶** [2.1.191]: 「Yes」で許可した host を session 中は再質問しない改善。harness 内蔵動作で config 変更不要。恩恵のみ受ける。Info。
- **MCP server / OAuth 再試行強化** [2.1.191]: capability discovery と OAuth token 取得が transient error で 1 回 retry するように。harness 内蔵、config 変更不要。Info。
- **MCP HTTP 404 error message 改善 / vim `/` history hint** [2.1.191]: UX 改善のみ。Info。
- **streaming CPU ~37% 削減 / long-session memory 削減** [2.1.191]: perf 改善、config 変更不要。Info。
- 残余 (2.1.191 の各種 UI bugfix: `/voice` policy message / `/login` URL wrap / Cmd+click Ghostty / `claude agents` builtin slash / image placeholder / `/permissions` denial persist / agent panel row jump / welcome splash overflow / scroll jump / background agent resurrect fix): UI・harness 内部 bugfix、config 変更不要。Info。

## 2.1.186–2.1.187 (detected 2026-07-02, stable)

Range 2.1.186–2.1.187 が新 stable tag として確定 (2.1.187 = `dist-tags.stable`)。CLI 既に 2.1.187 一致、VERSION のみ 2.1.185 → 2.1.187 bump。2.1.187 は CHANGELOG 未掲載の bugfix-only release。2.1.186 の主要変更を評価した結果、config 必須変更なし。

- **`respondToBashCommands` setting** [2.1.186]: `!` bash 出力に Claude が自動応答する挙動が default ON になった。従来の context-only 挙動へ戻す opt-out setting (`"respondToBashCommands": false`)。CLAUDE.md session guidance の「`! <command>` 出力が会話に入る」前提と整合し、default ON のまま追従して問題ない。`templates/settings.json.template` 変更不要。Track only。
- **`teammateMode: "iterm2"` setting** [2.1.186]: agent team を iTerm2 pane で起動する opt-in setting (`it2` CLI 不在時 warning)。現運用は tmux/pane backend 不使用のため adoption value 低い。Track only。
- **`Agent(type)` deny / `Agent(x,y)` allowed-types 修正** [2.1.186]: named subagent spawn でも `Agent(type)` deny rule と allowed-types restriction が enforce されるよう修正 (従来 named spawn で未適用の bug fix)。`general-purpose` 絶対禁止方針 (CLAUDE.md § Discovery Routing) を hook block に加え permission rule (`Agent(type:general-purpose)` deny) で二重化する余地がある。現状は `pre-tool-use.sh` の bundle-violation hook + CLAUDE.md 明文で対応済み。検討 candidate: `templates/settings.json.template` permissions.deny。Opportunity。
- **background subagent permission prompt を main session に surface** [2.1.186]: 従来 auto-deny だった background subagent の permission prompt が main session に表示されるよう変更 (Esc で当該 tool のみ deny)。ただし本変更は **background subagent 限定**であり、通常 Task 経由 subagent の auto-deny 挙動 (`agents/developer-agent.md:107` "Permission-prompt ops silent-fail — auto-denied") は CHANGELOG から陳腐化を確定できない。記述変更は保留し、次 range で通常 subagent への波及が確認できたら developer-agent.md silent-fail guard を再評価する。Track only。
- **skill frontmatter multi-case 許容 / malformed YAML handling** [2.1.186]: `display-name` / `default-enabled` / `fallback` / `metadata.*` が kebab/snake/camelCase を受理、malformed YAML は空 metadata で body load。現 SKILL.md 群は kebab-case 統一のため影響なし。Info。
- **`CLAUDE_CODE_MAX_RETRIES` cap 15 / `CLAUDE_CODE_RETRY_WATCHDOG`** [2.1.186]: max retries が 15 上限に、unattended session は watchdog env 推奨。両 env 未設定のため変更不要。Info。
- **MEMORY.md compact reminder** [2.1.186]: MEMORY.md が size 上限に近づくと agent に compact を促す。memory 運用 (`~/ai-tools/memory/`) と整合、config 不要。Info。
- **`/review <pr>` → `/code-review medium` engine 統一** [2.1.186]: built-in `/review` の engine 変更。repo の `commands/review.md` は独自 `comprehensive-review` skill 実装で built-in と別物、影響なし。Info。
- 残余 (`claude mcp login/logout` CLI / `/workflows` status filter / `/plugin` Skills section / Workflow schema-retry abort / 多数 UI・streaming bugfix): CLI 機能・UI・harness 内部・bugfix、config 変更不要。Info。

## 2.1.182–2.1.185 (detected 2026-07-01, stable)

Range 2.1.182–2.1.185 が新 stable tag として確定 (2.1.185 = `dist-tags.stable`)。CLI 既に 2.1.185 一致、VERSION のみ 2.1.181 → 2.1.185 bump。latest channel 時 (2026-06-21) に評価済で config 変更不要判定を維持、stable 昇格に伴い正式 track 化する。

- **`attribution.sessionUrl` setting** [2.1.183]: web / Remote Control session の commit・PR から claude.ai session link を省く opt-in setting。ローカル CLI 主体運用で web session 未使用のため adoption value 低い。`templates/settings.json.template` 変更不要。Track only。
- **auto-mode destructive git block** [2.1.183]: `git reset --hard` / `git checkout -- .` / `git clean -fd` / `git stash drop` を auto-mode で block (discard 明示なき場合)、`git commit --amend` を agent 非作成 commit で block、`terraform/pulumi/cdk destroy` を stack 未指定時 block。harness 内蔵動作で config 変更不要。既存 deny-rule no-escalation 方針 + memory `ai-cannot-run-git-stash-drop` と整合。
- **deprecated model warning が agent frontmatter もカバー** [2.1.183]: deprecated / auto-updated model を stderr 警告 (`-p` mode + agent frontmatter)。現 agent frontmatter の model ID (opus-4-7 / sonnet-4-6) は全て valid のため警告対象外。opus-4-7 は Opus 4.8 regression 回避の意図的 pin (`[[work-context-20260616-opus-4-8-regression-and-full-audit]]`)、変更しない。
- **stream-stall hint 文言・timing 変更** [2.1.185]: "No response from API · Retrying in …" → "Waiting for API response · will retry in …"、trigger 閾値 10s → 20s。UI 文言のみで config 変更不要。Info。
- 残余 (`/config --help` / `/config` toggle 挙動 / setup-issues 行削除 / thinking.disabled 400 fix / WebSearch subagent fix / vim cursor / Windows TUI / 2.1.182・2.1.184 内部 release): UI・harness 内部・bugfix、config 変更不要。

## ~~2.1.182–2.1.185 (detected 2026-06-21, latest)~~ (obsolete 2026-07-01): 上位 stable section 2.1.182–2.1.185 へ昇格・統合済み

## 2.1.180–2.1.181 (detected 2026-06-29, stable)

Range 2.1.180–2.1.181 が新 stable tag として確定 (2.1.181 = `dist-tags.stable`)。CLI 既に 2.1.181 一致、VERSION のみ 2.1.179 → 2.1.181 bump。2.1.180 は bugfix only。2.1.181 内容は後述の latest 時 (2026-06-19) 調査と同一だが、stable 昇格に伴い正式 track 化。

- **`/config key=value` 構文** [2.1.181]: プロンプトから任意 setting を設定可能な構文。harness 内蔵で `templates/settings.json.template` 変更不要。Track only。
- **`sandbox.allowAppleEvents`** [2.1.181]: macOS サンドボックス中の Apple Events 送信を opt-in 許可する新 setting。現在 Apple Events を必要とするユースケースなし。Track only。
- **`CLAUDE_CLIENT_PRESENCE_FILE`** [2.1.181]: 指定 file が存在する間 mobile push を抑制する env var。採用はユーザ好みに依存。Track only。
- 残余 (Bun 1.4 / line-by-line streaming / connection-drop auto-retry / subagent panel UI / MCP OAuth UI / bug fixes 各種): 内部・UI 改善、config 変更不要。Info。

## 2.1.178–2.1.179 (detected 2026-06-25, stable)

Range 2.1.178–2.1.179 が新 stable tag として確定 (2.1.179 = `dist-tags.stable`)。CLI 既に 2.1.179 一致、VERSION のみ 2.1.177 → 2.1.179 bump。

- **`TeamCreate` / `TeamDelete` tool 削除** [2.1.178]: Agent tool の `name` parameter で直接 teammate spawn する方式に統一。`team_name` parameter は accepted but ignored (後方互換)。現 hooks (`task-completed.sh` / `teammate-idle.sh`) は `.team_name // "unknown"` で受けており既存挙動そのまま。Track only (将来 `team_name` 完全削除に備え 3 か月後に hook field 削除候補)。
- **`Tool(param:value)` permission syntax** [2.1.178]: permission rule で tool 入力 parameter を match 可能 (`*` wildcard 対応)。例 `Agent(model:opus)` で Opus subagent を block。`templates/settings.json.template` への新規追加は不要 (現状の permission rule で十分)。Track only。
- **Nested `.claude/skills` load + `<dir>:<name>` collision rule** [2.1.178]: 作業 directory に近い skill が勝つ。現 repo は root `~/.claude/skills/` 1 階層のみ、既存挙動そのまま。Info。
- **Auto-mode subagent classifier 強化** [2.1.178]: subagent spawn が classifier 評価対象に。auto-mode で blocked action 要求の subagent を pre-launch block。harness 内蔵動作で config 変更不要。Info。
- **compaction fallback-model 反映 fix** [2.1.178]: 既設定 `fallbackModel` が compaction にも適用される。`templates/settings.json.template` 既設定済、変更不要。fix の恩恵のみ受ける。Info。
- **mid-stream connection drop preserved partial response** [2.1.179]: harness 内蔵 fix、config 変更不要。Info。
- その他 bugfix (vim undo / VSCode IME / WSL2 scroll / `/bug` description require / Linux sandbox symlink 等): config 変更不要。

## ~~2.1.181 (detected 2026-06-19, latest)~~ (obsolete 2026-06-29): 上位 stable section 2.1.180-2.1.181 へ昇格・統合済み

## 2.1.179 (detected 2026-06-17, latest)

No new opportunities. Range 2.1.179 (single version); all 9 CHANGELOG entries are bugfix / perf only.

- Remainder (mid-stream connection-drop preservation / WSL2 mouse-wheel scroll / sandbox `denyRead`/`allowRead` glob Bash-description bloat / feedback-survey single-digit misread / welcome-screen promo-banner stacking / Ctrl+O subagent transcript / prompt-input focus return / remote-session stuck-task display / remote plugin-load perf) — harness internals & bugfixes, no config changes needed. The sandbox glob fix is a CLI-internal Bash-description trim, not a `denyRead`/`allowRead` schema change — `templates/settings.json.template` unaffected.

## 2.1.178 (detected 2026-06-16, latest)

- **`Tool(param:value)` permission syntax** [2.1.178]: not adopted. New permission rules can match a tool's input parameters with `*` wildcard (CHANGELOG example `Agent(model:opus)`). Candidate for declaring the `general-purpose` agent ban in `templates/settings.json.template` `permissions.deny`. Not adopted: the existing `hooks/pre-tool-use.sh` hard-block (L1333, exit 2) is strictly stronger — staged warn/critical severity, JP message with substitute-agent guidance, and a `GP_BLOCK_OFF=1` escape hatch — none expressible in a flat deny rule. Duplicating the ban in permissions would only risk desync. Hook stays canonical.
- **Nested `.claude/skills` `<dir>:<name>` clash disambiguation** [2.1.178]: no impact. Repo ships a single flat `skills/` (24 skills), no nested `.claude/skills`. Unrelated to the existing `sync.sh` double-nest bug (`skills/<skill>/<skill>`) tracked in memory `sync-local-prefix-skill-nest` — that is a sync artifact, not the CLI nested-skill feature.
- **`disallowedTools` `mcp__*` server-spec fix** [2.1.178]: no impact. Agents list `mcp__serena__*` on the `tools:` side, not in `disallowedTools` (which only carries `Write` / `Edit` / `MultiEdit`). The server-spec silent-ignore bug never applied.
- Remainder (auto-mode classifier pre-eval / `/doctor` layout / `/bug` validation / OOM & OAuth & websocket crashes / vim undo / VSCode IME Esc / background-session "Working" / compaction `--fallback-model` honoring / statusline custom URI) — harness internals & bugfixes, no config changes needed.

## 2.1.154–2.1.177 (detected 2026-06-14, latest)

Channel switched stable→latest by explicit user choice (local CLI was 2.1.177 = latest tag). Range 2.1.154–2.1.177 reviewed.

- **`language` setting** [2.1.177 surfaced]: already correct. `templates/settings.json.template` has had `"language": "japanese"` since 2026-01-13 (ignored as unknown key then); now an official setting (response + dictation language). Value matches docs example, aligns with the JP-response policy. No change.
- **Sub-agents spawning sub-agents up to 5 levels** [2.1.172]: not adopted. Repo intentionally omits `Task` from developer/explore agent tools (sub-agent spec). The capability expansion does not change that safe-by-default design.
- **`workflow`→`ultracode` trigger rename** [2.1.160]: no impact. Repo never used `workflow` as a dynamic-workflow trigger keyword (only as a generic word / file name). `ultracode` is a built-in trigger, not repo config.
- **Stop/SubagentStop `hookSpecificOutput.additionalContext`** [2.1.163]: already applied. `hooks/subagent-stop.sh` already returns `additionalContext`.

Track only (low adoption value): `enforceAvailableModels` / `disableBundledSkills` / `footerLinksRegexes` / `wheelScrollAccelerationEnabled` / `/cd` / `/goal` / `--safe-mode` / `post-session` runner hook / plugins auto-load from `.claude/skills/` / `claude plugin init` / dynamic workflows (`ultracode`). Remainder: UI / background-session / Windows / provider (Bedrock/Vertex) / bugfix — no config changes needed.

## 2.1.153 (detected 2026-06-05, stable)

No new opportunities. Single-version range 2.1.153; repo impact grep confirmed (`modelPicker:setAsDefault` keybinding absent / `--strict-mcp-config` unused / `skipLfs` not applicable to current source).

- `modelPicker:setAsDefault` → `modelPicker:thisSessionOnly` rename [2.1.153]: no custom keybindings.json, skip
- `/model` default-save behavior [2.1.153]: harness default change, no config needed
- `skipLfs` plugin marketplace option [2.1.153]: no LFS marketplace source, skip
- Remaining: bugfix only (MCP reconnect-loop / API gateway credential / subagent MCP `--strict-mcp-config` / Windows installer / background session / VSCode shutdown) — no config changes needed

## 2.1.152 (detected 2026-06-04, stable)

Track only (low adoption value): `/reload-skills` / `SessionStart` `reloadSkills: true` / `pluginSuggestionMarketplaces` / `marketplace remove --scope` / `OTEL_METRICS_INCLUDE_ENTRYPOINT` / `fallback-model` auto-switch / Auto mode no-consent / Vim `/` reverse search / `/usage` session-files / many UI/bugfixes. `/simplify` revival (`/code-review --fix`) already decided as "not adopted, reference removed" at 2.1.148.

## 2.1.150 (detected 2026-06-01, stable)

No new opportunities. Range 2.1.149–2.1.150; CHANGELOG shows internal infrastructure improvements only (no user-facing changes). No config changes needed.

## 2.1.148 (detected 2026-05-30, stable)

No new opportunities. Range 2.1.146–2.1.148; repo impact grep confirmed.

- `/simplify` → `/code-review` rename [2.1.147]: use-case changed (post-impl bundle fast execute → diff correctness review @ effort level), plain rename not adopted. Removed all `simplify` references from `commands/flow.md` Auto-apply table / `references/skill-tool-invocation.md` / `references/command-resource-map.md` (post-impl replaced by `/lint-test`)
- 2.1.146 Opus 4.8 thinking block fix: bugfix only
- 2.1.148 Bash exit code 127 regression fix: bugfix only
- 2.1.147 others: many bugfixes (auto-updater retry / prompt history dedup / PowerShell / Windows terminal / `/help` / `/effort` / `/theme` / `/background` / MCP pagination / hook `if` PowerShell match / `CLAUDE_CODE_SUBAGENT_MODEL` teammate fix) — unused or existing behavior OK

## 2.1.145 (detected 2026-05-28, stable)

No new opportunities. Range 2.1.143–2.1.145; repo impact grep confirmed.

- `/extra-usage` → `/usage-credits` rename: unused, old name continues working, skip
- `worktree.bgIsolation: "none"` setting: bg session unused, skip
- `CLAUDE_CODE_POWERSHELL_RESPECT_EXECUTION_POLICY` / `CLAUDE_CODE_USE_POWERSHELL_TOOL`: Windows only, skip
- `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`: stop hook loop rescue env, current stop hook doesn't block, skip
- Stop/SubagentStop hook input adds `background_tasks` / `session_crons` [2.1.145]: notification-only hook, fields unused, no adoption value. Re-evaluate when bg session/cron usage starts
- `claude agents --json` [2.1.145]: statusline.js receives session JSON directly, not needed
- OTEL `agent_id` / `parent_agent_id` spans [2.1.145]: OTEL unused, skip
- Read tool PARTIAL view notice [2.1.145]: harness auto-behavior, no config needed

## 2.1.142 (detected 2026-05-15, stable)

No new opportunities. All entries bugfix/Info (Fast mode default Opus 4.7 + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` pin env, `claude agents` launch flags `--add-dir`/`--settings`/`--mcp-config`/`--plugin-dir`/`--permission-mode`/`--model`/`--effort`/`--dangerously-skip-permissions`, plugin root-level `SKILL.md` standalone support, `MCP_TOOL_TIMEOUT` 60s cap fix, background sessions worktree/sleep-wake/upgrade fixes, reactive compaction improvements, error message improvements for SessionStart/Setup/SubagentStart prompt/agent type hooks). Repo impact grep confirmed (`/fast` unused / old sonnet ID absent / existing hooks all type=command / `MCP_TOOL_TIMEOUT` unused).

## 2.1.141 (detected 2026-05-14)

Info/bugfix only: `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` (SSH key present, no impact), `ANTHROPIC_WORKSPACE_ID` (workload identity federation, unused), `claude agents --cwd`, `/feedback` recent sessions, Rewind "Summarize up to here", spinner amber, plugin menu improvements. `terminalSequence` already adopted (stop/stop-failure).

## 2.1.140 (detected 2026-05-13)

No new opportunities. All entries bugfix/Info (`subagent_type` case-insensitive, `/goal` hang fix, settings hot-reload, `Read` offset whitespace, Plugins folder ignore warning). Repo impact grep confirmed (`plugin.json` absent, whitespace-offset not used).

## 2.1.139 (detected 2026-05-12)

- [ ] **hook `args: string[]` (exec form)**: spawn directly without shell, no path argument quoting needed — candidate: `claude-code/templates/settings.json.template` hooks section. **Technical blocker** (re-verified 2026-06-15, no change at CLI 2.1.177): official docs (`code.claude.com/docs/en/hooks`) explicitly state `~` / `$HOME` **cannot be expanded** in exec form, and no user-scope global hook placeholder (`${CLAUDE_USER_HOME}` etc.) is provided. Available placeholders are only `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`. All 12 user-scope hooks invoke `~/.claude/hooks/*.sh`, so exec form requires hardcoded absolute paths = breaks template portability. Hold until Claude Code adds user-global placeholder (re-verify at next minor update)
