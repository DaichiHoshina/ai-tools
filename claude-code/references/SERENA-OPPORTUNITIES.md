# Serena Unadopted Feature Tracking

Accumulates Serena new features detected by `/serena-update-fix` that have adoption potential in this repo.

## Format

```markdown
## <version> (detected YYYY-MM-DD)
- [ ] **<feature>**: <summary> — review at: <file/project>
```

Check when adopted; strikethrough when obsolete (`~~feature~~ (obsolete YYYY-MM-DD): <1-line reason>`). Reason is required (avoids re-investigation cost 3 months later).

**Lifecycle**: Adopted (checked) entries auto-deleted on next `/serena-update-fix` run. Obsolete entries auto-deleted one version later. Unadopted entries remain tracked.

---

## main pre-release (detected 2026-06-08, re-confirmed 2026-06-30, still pre-release on next tag)

- [ ] **`replace_in_files` 新 tool** (added 2026-06-10, `4dc0cd14`): 複数 file 横断の literal/regex 置換 tool 新設、`src/serena/tools/file_tools.py` で実装 — review at: wildcard `mcp__serena__*` 採用済 agent (explore / manager / developer / po / commands) は自動有効。explicit list の reviewer / root-cause-analyzer / verify-app は read-only 用途のため追加不要。実装で `replace_content` 既存使い方と比較推奨
- [ ] **`get_symbols_overview depth=-1` default** (added 2026-06-12, `75410c78`): overview tools の `depth` default が language-specific になり `-1` 指定で有効化 — review at: repo 内で `depth=` 明示指定なし (grep ゼロ) のため影響なし、新規 caller で `depth=-1` を使う場面で活用
- [ ] **`benchmark` mode** (added 2026-06-29, `3d9b953a`): one-shot 自律完遂用 mode、memory tool 全 disable、auto-approval 前提 — review at: claude-code repo は serena mode 未使用 (CLI / IDE 専用)、track-only
- [ ] **`trusted_project_path_patterns` global setting** (added post-v1.5.3): `.serena/project.yml` の `ls_specific_settings` を trusted project path でのみ適用 — review at: activated 全 10 project の `ls_specific_settings: {}` (empty)、impact 実質ゼロ。将来 ls_specific_settings に値を入れる際に trusted list へ project root 追加要
- [ ] **structured tool output per-context (claude-code: disable)** (added post-v1.5.3, #1042): structured output を per-context で disable 化、claude-code は unpack 不可のため自動 disable — review at: harness fix の恩恵のみ受ける、config 変更不要 (Info)
- `activate_project FileNotFoundError fix` (added post-v1.5.3): registered project root 削除済 case で `RegisteredProject.matches_root_path` が FileNotFoundError raise していた bug fix。harness 内蔵 fix、no action
- LaTeX (texlab) / PHPantom (PHP alt) / pyrefly (Python alt) / Arduino `.ino`→C++ / Unreal Engine 5 (clangd) 強化 / C# Omnisharp Windows startup fix / Java JDTLS workspace cache invalidation (#1576) / CodeBuddy agent integration (added post-v1.5.3): 該当言語 / 環境 unused または harness 内蔵、out of scope
- [ ] **`typescript_vts` `initialization_options`**: Pass initializationOptions dict under `ls_specific_settings.typescript_vts`. Required for Yarn PnP + `typescript.tsdk` TS projects — review at: only when activating a Yarn PnP TS project (none currently)
- [ ] **`jetbrains_launch_command`**: Auto-launch IDE on project activate — review at: JetBrains IDE not used, out of scope
- [ ] **Dashboard `trusted_hosts` configurable**: Relax host validation from v1.5.2, allow remote connections — review at: only if connecting dashboard remotely (currently local default)
- `find_project_root` worktree fix [pre-release]: Fixes bug where worktree hijacks parent project's `.serena/project.yml`. No action needed (benefits CLI agent launched inside worktree, no config change)
- CLI flag persistence bug fix [pre-release]: `start-mcp-server` transient flag saved to config. Bug fix, no action needed
- `SvelteLanguageServer` TS/JS routing fix [pre-release]: Svelte project bug fix. Svelte not used, out of scope
- `name_path` alias for `name_path_pattern` in `find_symbol` [pre-release]: backward-compatible param alias. No action needed (existing `find_symbol` calls keep working, repo docs use neither literal)
- context/mode path-detection guard [pre-release]: `--context <name>` no longer mis-reads a local file of the same name. Bug fix, no config impact
- `query_project` read-only tool relaxation [pre-release]: allows read-only tools even if excluded by current context. Behavior improvement, no config change
- `oslex` shell-arg quoting [pre-release]: Windows arg escaping. macOS unaffected, out of scope
- `tool_names` mapping in prompt generation [pre-release]: prompts use language-backend-matched tool names directly, removing extra name-difference prompts — review at: only if using cc-system-prompt-override; regenerate `~/.claude/serena-cc-prompt.txt` when this reaches a tag-release (Phase 5 step 5)
- MCP-level explicit error surfacing [pre-release]: tool call errors now raised as MCP protocol errors. Behavior improvement, no config change
- `JuliaLanguageServer` stdio fix [pre-release]: Julia LS exiting after initialize. Julia not used, out of scope

## v1.5.2–v1.5.3 (detected 2026-05-28)

No new opportunities. v1.5.3 is tag-only (core changes completed in v1.5.2).

- `serena-agent` CLI entrypoint (`uvx serena-agent`) [v1.5.2]: Keeping `serena start-mcp-server`, alternative entrypoint not a rename, no switch needed
- Fortls / pyright on-the-fly install [v1.5.2]: Internal LSP impl, no project.yml impact. Fortran unused; Python managed via claude-plugins-official `pyright-lsp`
- Not-existing path returns `False` on ignored checks [v1.5.2]: Bug fix, no action needed
- Hooks code-file extension list expanded [v1.5.2]: Internal to reminder hook counter, no config impact

## v1.5.0–v1.5.1 (detected 2026-05-19)

- [x] **`search_for_pattern` `multiline=False` opt-out** (v1.5.0): Default is `multiline=True` with `re.DOTALL|MULTILINE`. Opt out for single-line searches to suppress `.*` greedy over-match — review at: explicitly specify for searches with clear single-line scope to prevent recurrence of 2026-05-18 dotall incident. `replace_content` not yet exposed (Tool API hardcodes dotall). (adopted 2026-06-08: references/serena-usage-guidelines.md)
- [x] **`replace_content` ambiguity guard** (v1.5.0): `ContentReplacer.replace()` returns `ValueError("Match is ambiguous: ...")` when the match contains the same pattern. Structurally prevents some cases like the 2026-05-18 `.*\n` greedy fire across 5 files — be ready to switch to literal mode or explicit end anchor on error. (adopted 2026-06-08: references/serena-usage-guidelines.md)
- [ ] **`mem:<name>` inter-memory references** (v1.5.0): Reference other memories from body with `mem:<name>`, auto-propagates on rename. Option to align from handwritten `[[name]]` notation in `~/.claude/projects/.../memory/MEMORY.md` to official Serena notation — review at: 20+ existing user-assist memories are in `~/.claude/` direct, outside Serena `write_memory` path and not propagation targets. Value only if migrating to Serena-managed memories
- [ ] **`memory_maintenance` onboarding seed** (v1.5.0): Place seed memory for memory style rules at onboarding, shareable across all projects via `global/memory_maintenance` — review at: currently substituted by `~/.claude/CLAUDE.md` + `rules/genshijin.md`. Consider integrating when migrating to Serena-managed memories
- ~~**`serena memories` CLI command group** (v1.5.0)~~ (obsolete 2026-06-08): CLI scope targets only `.serena/memories/`. Our `~/.claude/projects/.../memory/` is outside Serena management; `serena memories list` does not cover it. CLI migration for `/memory-save` consistency checks is a scope mismatch
- [ ] **CUE LSP** (v1.5.1): CUE language support via `cue lsp` — review at: only when activating a CUE project (none currently)
- [ ] **GDScript LSP** (v1.5.0): TCP connection to Godot editor's built-in LSP — review at: only when activating a Godot project (none currently)

## v1.3.0 (detected 2026-05-12)

- [ ] **`additional_workspace_folders`**: Cross-package reference support (TypeScript only as of v1.3.0). Enables symbol resolution for sibling packages in monorepos — review at: when activating a TypeScript monorepo or on extension to other languages. Current activated projects are go/bash/dart/terraform/python, out of scope
- [ ] **`added_modes`**: Cannot override `base_modes` in project.yml; add-only via `added_modes`. All projects currently have `added_modes:` empty, no impact — review at: each project's `.serena/project.yml` when adding custom modes
- ~~**`base_modes` default change** (`interactive`/`editing` moved from default_modes → base_modes)~~ (obsolete 2026-05-12): Global default behavior change only, no project-side awareness needed

## v1.0.0 (detected 2026-05-12, retroactive)

- [ ] **`project.local.yml` local override**: Separate personal/local settings from project.yml without git tracking — review at: when personal-specific settings (absolute paths in `ls_specific_settings` etc.) are needed per project
- [ ] **`ls_specific_settings` utilization**: Per-language-server settings (JDK path, custom binary, etc.) — review at: when activating Java/Scala/MATLAB etc. Currently only go/bash/dart/terraform/python, out of scope
- [ ] **monorepo / multi-language `project.yml`**: Define multiple languages in one project — review at: when a repo mixes go + typescript

## Conditional triggers (wait for felt pain, no preemptive action)

Adoption candidates but ROI unclear / existing custom impl working — **hold until trigger condition met**.

- [ ] **`cc-system-prompt-override` adoption** (Opus 4.7 bias mitigation): System prompt override to guide bias away from Claude Code built-in tools (Read/Edit/Grep) toward Serena tools. Details in `serena/docs/02-usage/030_clients.md`, setup example `references/serena-cc-prompt-setup.md` — **trigger**: when user feels the bias of Read-spamming in contexts where Serena should be used (symbol search / symbol-level edit). Preemptive action is major surgery (CC launch alias change or full CLAUDE.md rewrite), ROI unclear (judged 2026-05-15)
- [ ] **Serena reminder hooks integration** (`serena-hooks remind/activate/cleanup/auto-approve`): Integrate Serena official hooks into PreToolUse / SessionStart / Stop, consider replacing current custom sh system. Details in `serena/docs/02-usage/030_clients.md` — **trigger**: when repeatedly troubled by Serena MCP issues (reconnection needed / state inconsistency / project activate failure). Currently working with custom hooks; replacement has regression risk, no preemptive action (judged 2026-05-15)
