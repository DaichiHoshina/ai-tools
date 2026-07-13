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

## main pre-release (detected 2026-06-08, re-confirmed 2026-07-02, still pre-release on next tag)

- [ ] **`replace_in_files` 新 tool** (added 2026-06-10, `4dc0cd14`): 複数 file 横断の literal/regex 置換 tool 新設、`src/serena/tools/file_tools.py` で実装 — review at: wildcard `mcp__serena__*` 採用済 agent (explore / manager / developer / po / commands) は自動有効。explicit list の reviewer / root-cause-analyzer / verify-app は read-only 用途のため追加不要。実装で `replace_content` 既存使い方と比較推奨
- [ ] **`get_symbols_overview depth=-1` default** (added 2026-06-12, `75410c78`): overview tools の `depth` default が language-specific になり `-1` 指定で有効化 — review at: repo 内で `depth=` 明示指定なし (grep ゼロ) のため影響なし、新規 caller で `depth=-1` を使う場面で活用
- [ ] **`benchmark` mode** (added 2026-06-29, `3d9b953a`): one-shot 自律完遂用 mode、memory tool 全 disable、auto-approval 前提 — review at: claude-code repo は serena mode 未使用 (CLI / IDE 専用)、track-only
- [ ] **`trusted_project_path_patterns` global setting** (added post-v1.5.3): `.serena/project.yml` の `ls_specific_settings` を trusted project path でのみ適用 — review at: activated 全 10 project の `ls_specific_settings: {}` (empty)、impact 実質ゼロ。将来 ls_specific_settings に値を入れる際に trusted list へ project root 追加要
- [ ] **`activation_command` / `activation_command_timeout` project config** (added post-v1.5.3, `dcbd8ce0` #1623): `.serena/project.yml` に置いた shell command を language backend 初期化前に project root で実行する新 key (LSP index に必要な source file 生成等の用途)。`trusted_project_path_patterns` に含まれる trusted project でのみ実行され、default timeout 180s、失敗・timeout は log のみで activation を中断しない — review at: activated 全 project で現状 codegen 前提の事前生成 need なし。将来 codegen 前提の project (protobuf / terraform gen 等) を activate する際に trusted list 登録 + 本 key 併用を検討
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
- `tool_names` mapping in prompt generation [pre-release]: prompts use language-backend-matched tool names directly, removing extra name-difference prompts. Out of scope (2026-07-13: cc-system-prompt-override 一式を撤去したため関係なくなった)
- MCP-level explicit error surfacing [pre-release]: tool call errors now raised as MCP protocol errors. Behavior improvement, no config change
- `JuliaLanguageServer` stdio fix [pre-release]: Julia LS exiting after initialize. Julia not used, out of scope

判定確定済み・trigger 待ち dormant の旧 section (v1.0.0 / v1.3.0 / v1.5.0–v1.5.1 / v1.5.2–v1.5.3) は `_archive/SERENA-OPPORTUNITIES-2026Q2.md` へ移した (再評価対象外、trigger 発生時に active へ戻す)。

## Conditional triggers (wait for felt pain, no preemptive action)

Adoption candidates but ROI unclear / existing custom impl working — **hold until trigger condition met**.

- ~~**`cc-system-prompt-override` adoption**~~ 棄却 (2026-07-13): Opus 4.7 bias mitigation の system prompt override 案。2026-05-15 に「ROI 不明、trigger 待ち dormant」判定で保留、以後 trigger 発火なく `ccs` shell function / prompt file / setup 手順を撤去した。再検討する場合は `serena/docs/02-usage/030_clients.md` から起こし直す
- [ ] **Serena reminder hooks integration** (`serena-hooks remind/activate/cleanup/auto-approve`): Integrate Serena official hooks into PreToolUse / SessionStart / Stop, consider replacing current custom sh system. Details in `serena/docs/02-usage/030_clients.md` — **trigger**: when repeatedly troubled by Serena MCP issues (reconnection needed / state inconsistency / project activate failure). Currently working with custom hooks; replacement has regression risk, no preemptive action (judged 2026-05-15)
