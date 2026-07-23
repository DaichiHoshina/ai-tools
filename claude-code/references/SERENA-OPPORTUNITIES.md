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

## v1.6.1 (released 2026-07-21, tracked 2026-07-23)

v1.6.0 → v1.6.1 は LSP / tool 内部 fix と Java/PHP の opt-in ls_specific_settings 追加が中心で、config 必須変更・auto-apply 対象 (tool rename / template arg / user-scope 再登録) はいずれもなし。activated project の `ls_specific_settings: {}` (empty) と整合し、恩恵のみ受ける。`main` の Unreleased 群 (`languages` → `language_servers` rename / Grok context / `python_basedpyright`) は auto-migration 明示のため即対応不要、次 tag で正式対応する。

- [ ] **`ls_specific_settings.java.runtimes`** (v1.6.1, #1478): JDT-LS に追加 JRE/JDK entry (`name` / `path` / optional `default`/`sources`/`javadoc`) を渡し、bundled JDK 21 を超える source/target level の project で `java.lang.Object` 等が resolve できない silent breakage を修正する opt-in key — review at: activated project に Java project なし、trigger 発生時 (Java project activate + JDT-LS `cannot be resolved` 発生) に該当 `.serena/project.yml` へ設定
- [ ] **`ls_specific_settings["php"].file_filter`** (v1.6.1, #1710): Drupal 等の `.module` / `.install` / `.inc` / `.theme` を PHP source として index させる opt-in、`.phtml` は default 追加済 — review at: PHP project なし、trigger 待ち
- **LSP file change notifier** (v1.6.1): external file system 変更を language server に通知する明示的 sync 機構を追加。`find_referencing_symbols` 等の stale info bug を修正。activated project 全て自動恩恵、config 変更不要 — Info
- **rust-analyzer `ContentModified` retry** (v1.6.1, #1724): LSP `-32801` を hard fail せず capability 宣言 method (`textDocument/hover` 等) で retry。windows-latest の flaky test 修正、config 変更不要 — Info
- **gopls `replace_symbol_body` type/var/const 修正** (v1.6.1): `type Foo` → `type type Foo` になる corruption 修正。Go project で `replace_symbol_body` 使用時の破壊 fix、activated project の Go 系 (`~/ghq/github.com/DaichiHoshina/*`) で自動恩恵、config 変更不要 — Info
- **`typescript` / `typescript_vts` coverage dir 無視撤廃** (v1.6.1, #1523): 底の `coverage` dirname 一致で `src/routes/coverage/` 等の legitimate source が hide されていた bug 修正。TypeScript activated project (`snkrdunk-*` 等) で symbol tool が対象 dir を見えるように、config 変更不要 — Info
- **`FileUtils.read_file` LF normalization fallback** (v1.6.1): `charset_normalizer` fallback path が universal-newline を skip して CR を in-memory に持ち込んでいた bug 修正。config 変更不要 — Info
- **`SymbolBody.get_text` EOF off-by-one fix** (v1.6.1, #1498): LSP range が EOF+1 line, col 0 で終わる whole-line convention の 1 case を正規化。他の out-of-range end は明示 `InvalidTextLocationError` へ、config 変更不要 — Info
- **`search_for_pattern` end-line fix + overflow snippet stage** (v1.6.1, #1640): match end index を line 変換する時の off-by-one 修正 (`context_lines_after` 整列)、overflow 時に各 match の 1 行目 (full / truncated `...`) を先に emit して bare line number fallback 前に agent が match 特定できる改善。config 変更不要 — Info
- **`safe_delete` 削除後空行 cleanup** (v1.6.1): 削除後の余剰空行を heuristic で除去。config 変更不要 — Info
- **`uv tool run` へ切替** (v1.6.1, #1721): uv-based LSP launch を `uv x` (新 CLI) から `uv tool run` に置換し互換性向上。config 変更不要 — Info
- **Dashboard version staleness indicator** (v1.6.1): 新 Serena version 利用可否を dashboard 上に表示。dashboard 未使用のため恩恵限定、config 変更不要 — Info
- **Dashboard "Last Execution" empty-state fix** (v1.6.1, #1713): fresh server で "Loading..." 固定する bug 修正。dashboard 未使用、Info
- **Dependencies bump** (v1.6.1): `mcp` 1.27.0 → 1.28.1、`anthropic` 0.59.0 → 0.117.0。Serena 側依存で config 変更不要、Info

## v1.6.0 (released 2026-07-16, tracked 2026-07-18)

v1.5.3 → v1.6.0 で、下記の pre-release / post-v1.5.3 として先取り評価済みの項目が正式リリースされた。schema breaking な CONFIG 変更・auto-apply 対象 (tool rename / template arg / user-scope 再登録) はいずれも無く、判定を据え置く。`replace_in_files` は wildcard `mcp__serena__*` 採用の 4 agent (explore / manager / developer / po) で自動有効、新 key (`trusted_project_path_patterns` / `activation_command`) は global config・project.yml に Serena 側 template 生成で反映済みかつ `ls_specific_settings: {}` empty のため影響ゼロ。`main` 冒頭の Unreleased 群 (search_for_pattern / safe_delete 等の bugfix) は次 tag で拾う pre-release、config 影響なし。

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
