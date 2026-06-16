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

- [ ] **hook `args: string[]` (exec form)**: spawn directly without shell, no path argument quoting needed — candidate: `claude-code/templates/settings.json.template` hooks section. **Technical blocker** (re-verified 2026-05-22): official docs (`code.claude.com/docs/en/hooks`) explicitly state `~` / `$HOME` **cannot be expanded** in exec form, and no user-scope global hook placeholder (`${CLAUDE_USER_HOME}` etc.) is provided. Available placeholders are only `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`. All 12 user-scope hooks invoke `~/.claude/hooks/*.sh`, so exec form requires hardcoded absolute paths = breaks template portability. Hold until Claude Code adds user-global placeholder (re-verify at next minor update)
