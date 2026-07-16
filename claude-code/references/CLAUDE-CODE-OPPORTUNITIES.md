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

## Channel switch: stable → latest (2026-07-13)

User が `/claude-update-fix latest` を明示指定。local CLI = 2.1.207 = `dist-tags.latest` に一致するため channel を `stable` (2026-06-23 切替) から `latest` に戻し、fetch range を latest tag 基準へ変更。VERSION も 2.1.197 → 2.1.207 へ bump。下記 2.1.198–2.1.207 section は latest channel での正式 track。

## 2.1.211 (detected 2026-07-16, latest)

Range 2.1.211 を latest channel で評価 (2.1.211 = `dist-tags.latest`)。local CLI 既に 2.1.211 一致、VERSION のみ 2.1.210 → 2.1.211 bump。主要変更を評価した結果、config 必須変更・auto-apply 対象 (model ID replace / template 変更 / deprecated 削除) はいずれもなし。

- **`--forward-subagent-text` flag + `CLAUDE_CODE_FORWARD_SUBAGENT_TEXT` env** [2.1.211]: subagent text と thinking を stream-json 出力に含める opt-in。個人 interactive CLI 運用で stream-json 未使用、対象外。将来 SDK / headless 経由で subagent の中間出力を parent tool 側に流したい時に有用。Track only。
- **PreToolUse hook `ask` decision を auto mode が上書きしない fix** [2.1.211]: unsandboxed Bash に対し hook が `ask` を返した時、auto mode が silently allow に格上げしていた regression の修正。repo hook (`hooks/pre-tool-use.sh`) は `ask` decision を出さず deny/allow 二分 + block message 経由の運用で影響なし。将来 `ask` を導入する時の安全性が確保された。Info。
- **nested `.claude/rules/*.md` file が `settingSources` project 除外設定で load されない fix** [2.1.211]: repo は `~/.claude/rules/` (user global) 配下運用が canonical、`settingSources` で project settings を除外する運用未実施。恩恵のみ受ける。Info。
- **`always allow` permission rule を repo root に保存** [2.1.211]: `git worktree` 内で承認した rule が worktree / session 跨ぎで持続する挙動変更。repo は `/flow --parallel` 等で worktree 運用あり、承認 rule の永続化は運用改善。config 変更不要で恩恵のみ受ける。Info。
- **subagent が explicit model override 指定時、resume / follow-up でも override を保持する fix** [2.1.211]: developer-agent / po-agent 等 model 明示指定 agent の resume path bug 修正。repo で頻用、恩恵大。config 変更不要。Info。
- **integer env variable が scientific notation / digit separator (`1e6` / `64_000`) を受理** [2.1.211]: 2.1.208 の `1e6` parse fix (`CLAUDE_CODE_MAX_OUTPUT_TOKENS` 等) の続編で receipt 拡張。現 `templates/settings.json.template` は `"32000"` (integer) 指定で影響なし、将来可読性向上で `64_000` 表記に置換できる余地あり。Track only。
- **`/clear` が session cost counter を reset する fix** [2.1.211]: statusline の cost 表示 bug 修正。個人 CLI 恩恵、config 変更不要。Info。
- **memory index over-limit warning が frontmatter / HTML コメントを除外して測る改善** [2.1.211]: 現 memory 運用 (`~/ai-tools/memory/MEMORY.md`) の実 index size 判定が正確化。config 変更不要で恩恵のみ受ける。Info。
- **background agent 完了報告改善 (still-running agent の状態を fabricate せず待つ)** [2.1.211]: `Workflow` / `Agent` (background=true) 運用時の hallucination 抑制。repo の `/flow` `/workflow` 運用で恩恵大、config 変更不要。Info。
- **`/loop` が single-use 後 `/resume` から見えなくなる bug fix** [2.1.211]: `/loop` (cadence / 無人 iteration) 運用時の resume path 修正。CLAUDE.md `## Golden workflow` に `/loop` 記載あり、恩恵のみ受ける。config 変更不要。Info。
- 残余 (parallel session logout / plugin MCP idle reconnect / Vertex/Bedrock spurious fallback notice / permission preview neutralization / file upload validation / Chrome extension / 300ms async delay / background session revive / screen reader / LLM gateway auth / worktree undeletable / Windows print-mode / prompt caching regression on Bedrock/Vertex/Mantle/Foundry / Vim substitute / VSCode Remote Control banner / 各種 UI・harness 内部 fix): config 変更不要。Info。

## 2.1.208–2.1.210 (detected 2026-07-15, latest)

Range 2.1.208–2.1.210 を latest channel で評価 (2.1.210 = `dist-tags.latest`)。local CLI 既に 2.1.210 一致、VERSION のみ 2.1.207 → 2.1.210 bump。主要変更を評価した結果、config 必須変更・auto-apply 対象 (model ID replace / template 変更 / deprecated 削除) はいずれもなし。

- **`Write(path)` / `NotebookEdit(path)` / `Glob(path)` permission rule に startup warning** [2.1.210]: 起動時 warning のみで既存動作は破壊しない。当初「Read/Edit へ置換すると意味 (書き込み禁止 → 読み取り禁止) が変わる」として現状維持と判定したが、Anthropic 側 warning 文が明言する通り `Edit(path)` rule は Write を含む全 file 編集 tool を cover するため、`Edit(.env)` 等が既に併記済の環境では `Write(.env)` 群は完全な no-op dead rule。`templates/settings.json.template` から 9 件 (`Write(.env)` / `Write(.env.*)` / `Write(**/.env)` / `Write(**/.env.*)` / `Write(**/*.pem)` / `Write(**/*secret*)` / `Write(**/*credential*)` / `Write(**/*password*)` / `Write(**/*.token)`) を削除して起動時 warning を解消済。Fixed 2026-07-15。
- **`isolation: 'worktree'` subagent が main repo に git 変更を出す bug fix** [2.1.210]: repo は `/flow --parallel` / `/dev --parallel` / `references/workflow-templates.md` (migrate) 等で worktree isolation を使用。CLI 側 fix の恩恵をそのまま受ける、config 変更不要。Info。
- **`ultracode` keyword が webhook / 中継 PR comment などで発火しない** [2.1.210]: 非人間 input 経由の誤発火を防止。repo の `ultracode` 参照は `references/model-selection.md` の説明文のみで dynamic workflow trigger 未運用、影響なし。Info。
- **auto mode の permission classifier が external session で Sonnet 5 default** [2.1.210]: 個人 CLI (Anthropic 直) で `sonnet-5` を agent frontmatter 5 file に採用済み、harness 内蔵動作で config 変更不要。恩恵のみ受ける。Info。
- **hook callback timeout を user rejection に誤変換する bug fix** [2.1.210]: unattended session が hook timeout で停止する bug の fix。repo hook (`hooks/*.sh`) は tight timeout ではなく正常 exit path で運用、config 変更不要で恩恵のみ受ける。Info。
- **Agent tool が subagent 経由 indirect prompt injection に対して硬化** [2.1.210]: harness 側 security hardening、config 変更不要で恩恵のみ受ける。Info。
- **`$1` / `$2` positional placeholder が skill / command 内で保存される** [2.1.210]: 従来 silently strip されていた挙動が保持へ。repo の skill / command 群 (`grep -rn '\$1\|\$2'` 実測) では awk field ref のみ、placeholder 用途未使用で影響なし。将来 named skill/command で positional 引数を受ける余地が生まれた。Info。
- **`vimInsertModeRemaps` setting** [2.1.208]: vim mode で `jj` → Escape 等の 2-key insert-mode remap を定義可能。vim mode 未使用のため対象外。Info。
- **`axScreenReader` setting / `--ax-screen-reader` / `CLAUDE_AX_SCREEN_READER=1`** [2.1.208]: screen reader 用 plain-text rendering の opt-in。個人 CLI で対象外。Info。
- **`CLAUDE_CODE_PROCESS_WRAPPER` env** [2.1.208]: 企業 launcher 経由で Claude Code の self-spawn を wrap する用途。個人 CLI で対象外。Info。
- **`Edit` tool が read 後 modified された file でも unique match すれば通す** [2.1.208]: 従来失敗していた edge case の緩和。repo hook / 運用に影響なし、恩恵のみ受ける。Info。
- **rule matcher の compile cache** [2.1.208]: 大量 permission deny / ask rule を持つ session での多秒 slowdown 修正。`templates/settings.json.template` は deny rule 大量所持のため恩恵大、config 変更不要。Info。
- **memory / stream 系 leak fix 多数** [2.1.208]: MCP stdio server stderr 64MB accumulation / LSP LRU cap 50 / edit cache 16MB 上限 / transcript prune (edit-heavy session で最大 79x 削減) / checkpoint disk 制限。長 session 運用 (developer-agent / po-agent 等) で恩恵大、config 変更不要。Info。
- **catastrophic `rm -rf` in `$(...)` / backtick / `<(...)` が `--dangerously-skip-permissions` / auto mode でも prompt** [2.1.208]: plain form と挙動が揃った security hardening。repo の deny rule (`Bash(rm -rf ~/*)` 等) は literal string match で覆えない command substitution 経路を CLI 側で塞ぐ。恩恵のみ受ける。Info。
- **`CLAUDE_CODE_MAX_OUTPUT_TOKENS` 等 env の scientific notation parse fix** [2.1.208]: 従来 `1e6` が `1` として解釈された bug。現 template は `"32000"` (integer) 指定で影響なし。Info。
- **agent view から returning 時に task tracker を落とさない fix / agents footer に waiting count 表示** [2.1.210]: UI 改善、config 変更不要。Info。
- **background session が older daemon で silently restart しない fix** [2.1.208]: CLI update 後の resurrect 経路の safety fix。個人 CLI で恩恵のみ受ける。Info。
- **screen reader mode で permission mode change を音声通知** [2.1.210]: accessibility 改善、対象外。Info。
- **`memory writes` が MEMORY.md index を read limit 超で silent truncation → explicit error** [2.1.210]: 現 memory 運用 (`~/ai-tools/memory/MEMORY.md`) で index size 逼迫は未確認、恩恵のみ受ける。Info。
- 残余 (dataviz skill 色検証改善 / bash cd background 挙動明示 / Bedrock/Vertex/Foundry auto mode `/doctor` skip / Grep pagination fix / apiKeyHelper error surface / SDK MCP `initialize` connect / Ghost frame fix / worktree lock sweep / plugin cache tempfile 掃除 ほか多数の bugfix / UI 改善): config 変更不要。Info。

## 2.1.198–2.1.207 (detected 2026-07-13, latest)

Range 2.1.198–2.1.207 を latest channel で評価 (2.1.207 = `dist-tags.latest`)。CLI 既に 2.1.207 一致、VERSION のみ 2.1.197 → 2.1.207 bump。主要変更を評価した結果、config 必須変更・auto-apply 対象 (model ID replace / template 変更 / deprecated 削除) はいずれもなし。

- **`AskUserQuestion` auto-continue OFF 化** [2.1.200]: AskUserQuestion dialog が default で自動継続しなくなり、idle timeout は `/config` で opt-in。repo 方針は `rules/minimize-questions.md` で「AskUserQuestion をそもそも出さない (推奨即決)」であり、質問を出した後の継続挙動には実質晒されない。`awaySummaryEnabled: false` 既設定で away 系無効運用のため timeout setting 追加も不要。Info。
- **permission mode "default" → "Manual" rename** [2.1.200]: CLI / `--help` / VS Code / JetBrains で "default" mode 表記が "Manual" に。`--permission-mode manual` / `"defaultMode": "manual"` を新受理、`default` も後方互換で accepted。現 `templates/settings.json.template` は `defaultMode: "auto"` を使用しており "default" 未使用、影響なし。Info。
- **auto mode が settings.local.json / project settings.json を読まない** [2.1.205/2.1.207]: auto mode が `.claude/settings.local.json` (2.1.207) と project 側 plugin option (2.1.207) を読まなくなり、transcript file 改竄を block する rule 追加 (2.1.205)。security hardening、harness 内蔵で config 変更不要。恩恵のみ受ける。Info。
- **非 Anthropic provider で Opus 4.8 default 化 + auto mode opt-in 不要化** [2.1.207]: Bedrock / Vertex / AWS の default model / auto mode 挙動変更。個人 CLI は Anthropic 直、`availableModels` (opus-4-7 / fable-5 / sonnet-5) も管理済みで対象外。Info。
- **skill 再 load の重複注入 fix** [2.1.202]: 既 load 済 skill を再呼び出しした際に instruction が context に重複追加される bug の fix。repo hook (`hooks/lib/context-injectors.sh`) は skill 注入に非関与のため CLI 側 fix と独立、恩恵のみ受ける。Info。
- **`EnterWorktree` が project 外 worktree で確認要求** [2.1.206]: `.claude/worktrees/` 外の worktree に入る時 confirmation を出す。repo の worktree 運用 (`/flow --parallel` 等) は project 配下 worktree 前提で影響軽微、harness 内蔵動作で config 変更不要。Track only。
- **`/commit-push-pr` が push remote を auto-allow** [2.1.206]: built-in command の push 自動許可。repo の `/git-push` は独自実装で built-in と別物、影響なし。Info。
- **`SessionStart` / `Setup` / `SubagentStart` hook の exit code 2 stderr 表示** [2.1.199]: これら hook が code 2 で exit した際 stderr を silently 隠していた bug の fix。repo の `hooks/session-start.sh` / `subagent-start.sh` は正常 exit path のため影響なし、error 可視化の恩恵のみ受ける。Info。
- **`CLAUDE_CODE_RETRY_WATCHDOG` default retry 300 / cap 15 撤廃** [2.1.199]: non-capacity transient error の default retry 回数引き上げ。既 track (2.1.193 section) と同一方針で env 未設定・変更不要を維持。Info。
- **Stacked slash-skill が先頭 5 個まで load** [2.1.199]: `/skill-a /skill-b` で先頭 5 skill を load。既 track (2.1.193 section) と同一、harness 内蔵で config 変更不要。Info。
- **`.claude/rules/` symlink 経由 conditional rule load fix** [2.1.198]: symlink path 経由で target file に到達する時 conditional rule が load されなかった bug の fix。`~/.claude/rules/` に symlink rule は現状なし (実 file 配置) のため影響なし、将来 symlink 配置時の恩恵。Info。
- **`/dataviz` skill 追加** [2.1.198]: chart / dashboard 設計 guidance の built-in skill 新設。repo は独自 skill 群で運用、採用は個別用途発生時に検討。Track only。
- **subagent が default background 実行 + `agent_needs_input` / `agent_completed` Notification hook** [2.1.198]: subagent が default で background 化、完了・入力待ちで `Notification` hook 発火 (`agent_needs_input` / `agent_completed` event)。repo の `preferredNotifChannel: "none"` 運用と整合、Notification hook 未使用で config 変更不要。将来 subagent 完了通知を hook 化する余地あり。Track only。
- **`/agents` wizard 削除** [2.1.198]: subagent 管理 wizard を廃止、`.claude/agents/` 直接編集 or Claude 依頼へ。repo に `/agents` wizard 参照なし (grep ゼロ)、影響なし。Info。
- **"Dynamic workflow size" setting + workflow OTel 属性** [2.1.202]: `/config` で dynamic workflow の agent 数目安を設定可能に、`workflow.run_id` / `workflow.name` を OTel 出力。repo の `/workflow` 運用に advisory 影響のみ、config 変更不要。Track only。
- 残余 (background session / agent view / Remote Control / voice dictation / MCP OAuth / Deep research label / terminal streaming freeze ほか多数の UI・harness 内部・bugfix): config 変更不要。Info。

## 2.1.194–2.1.197 (detected 2026-07-10, stable)

Range 2.1.194–2.1.197 が新 stable tag として確定 (2.1.197 = `dist-tags.stable`)。CLI 既に 2.1.197 一致、VERSION のみ 2.1.193 → 2.1.197 bump。2.1.194 は CHANGELOG 欠番 (skipped release)。主要変更を評価した結果、config 必須変更なし。

- **Claude Sonnet 5 default model 化** [2.1.197]: Sonnet 5 が Claude Code の default model に昇格、native 1M-token context、$2/$10 per Mtok promo (~08/31)。sonnet-4-6 → sonnet-5 の一括切替は 2026-07-10 judge-panel (34 対 27) で品質確認し、agent frontmatter ×5 へ採用済み。`claude-opus-4-7` × 4 files と `templates/settings.json.template` の `fallbackModel` は opus-4-7 pin (opus-4-8 regression 回避) を維持。CLAUDE.md § Auto-Delegation の `/model sonnet` alias 記述は最新 sonnet を指すため影響なし。採用済。
- **Org default models 表示** [2.1.196]: 組織 console で admin 設定した default model を `/model` 内に "Org default" / "Role default" として表示。個人 CLI 環境では対象外。Info。
- **`CLAUDE_ENABLE_STREAM_WATCHDOG` default ON** [2.1.196]: 5 分間 stream event 無応答で abort + retry。全 provider で default ON、opt-out は env `CLAUDE_ENABLE_STREAM_WATCHDOG=0`。長時間 subagent (developer-agent, po-agent 等) で誤 abort 懸念あるが、default ON の恩恵 (真の hang 検出) が上回るため様子見。Info。
- **Remote Control disabled on non-Anthropic BASE_URL** [2.1.196]: `ANTHROPIC_BASE_URL` が Anthropic 以外を指す時 Remote Control 自動無効化 (Bedrock/Vertex/Foundry と同挙動)。個人 CLI 環境で `ANTHROPIC_BASE_URL` 未設定、影響なし。Info。
- **Agents view 移動 1 押しに短縮** [2.1.196]: foreground session から agents view を開く操作が `←` 1 回に (従来 2 回)。UI 改善のみ。Info。
- **`/code-review` finder 統合** [2.1.196]: 5 個の cleanup finder を 1 個に merge、token 使用量 25% 削減。built-in `/code-review` の内部改善。repo の `/review` は独自 `comprehensive-review` skill 実装のため影響なし。Info。
- **`.mcp.json` self-approval 経路の security fix** [2.1.196]: `claude mcp list` / `get` が repo 側 `.claude/settings.json` で self-approve された未信頼 workspace の MCP server を spawn しない挙動に変更。個人 CLI で影響なし、恩恵のみ受ける。Info。
- **`CLAUDE_CODE_DISABLE_MOUSE_CLICKS` env** [2.1.195]: fullscreen mode 中の mouse click/drag/hover を無効化 (wheel scroll は保持)。opt-in、現運用で未使用。Track only。
- **Hook matcher hyphenated exact-match** [2.1.195]: hyphen 含む matcher (`code-reviewer` / `mcp__brave-search` 等) が従来 substring match → exact match に変更。`mcp__brave-search__.*` 型で従来動作を維持可能。**現 `templates/settings.json.template` の matcher は全て `*` / `""` / `mcp__serena__*` の 3 型のみで hyphen 含む pattern 未使用、影響なし**。将来 tool 別 hook を分岐する時は exact-match 前提で書く。Info。
- **Voice dictation 日中泰語 auto-submit fix** [2.1.195]: space 無し表記 (JP/ZH/TH) で auto-submit が発火しない bug の fix。voice mode 未使用のため影響なし、恩恵のみ受ける。Info。
- 残余 (background session Windows 対応 / background job resurrect / mid-stream connection drop recover / rate-limit telemetry over-count / `/context` Bedrock 0 表示 / `/deep-research` verifier 誤報 / plugin dep pin / voice mode Linux / `claude agents` session status / PowerShell git 挙動整合 / MCP OAuth GitLab 対応 / Esc Esc rewind regression / plugin validate / `/plugin` Enable/Disable / 各種 UI bugfix): harness 内部 fix・UI 改善、config 変更不要。Info。

## 2.1.192–2.1.193 (detected 2026-07-05, stable)

No new opportunities. Range 2.1.192–2.1.193 が新 stable tag として確定 (2.1.193 = `dist-tags.stable`)。CLI 既に 2.1.193 一致、VERSION のみ 2.1.191 → 2.1.193 bump。2.1.192 は CHANGELOG 欠番 (skipped release)。2.1.193 は bugfix / harness 内部改善のみで config 変更不要と判定した。

- **stacked slash-skill invocation** [2.1.193]: `/skill-a /skill-b do XYZ` で先頭 5 個まで全 skill を load する挙動改善。harness 内蔵で config 変更不要。Info。
- **`CLAUDE_CODE_RETRY_WATCHDOG` 挙動拡張** [2.1.193]: default retry 回数引き上げ + 15-retry cap 撤廃。2.1.186 section で track 済みの env と同一で、判定 (未設定・変更不要) を維持する。Info。
- **Setup / SubagentStart hook stderr 処理改善** [2.1.193]: harness 側 fix。repo の `hooks/subagent-start.sh` / Setup hook は変更不要で恩恵のみ受ける。Info。
- 残余 (429 auto-retry / streaming partial 保持 / subagent rate-limit partial 返却 / background agent daemon fixes / SendMessage retarget / config 破損 backup / PR link `#N` 表示ほか): bugfix・UI 改善、config 変更不要。

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
- **deprecated model warning が agent frontmatter もカバー** [2.1.183]: deprecated / auto-updated model を stderr 警告 (`-p` mode + agent frontmatter)。現 agent frontmatter の model ID (opus-4-7 / sonnet-5) は全て valid のため警告対象外。opus-4-7 は Opus 4.8 regression 回避の意図的 pin、変更しない。
- **stream-stall hint 文言・timing 変更** [2.1.185]: "No response from API · Retrying in …" → "Waiting for API response · will retry in …"、trigger 閾値 10s → 20s。UI 文言のみで config 変更不要。Info。
- 残余 (`/config --help` / `/config` toggle 挙動 / setup-issues 行削除 / thinking.disabled 400 fix / WebSearch subagent fix / vim cursor / Windows TUI / 2.1.182・2.1.184 内部 release): UI・harness 内部・bugfix、config 変更不要。

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

判定確定済みの旧 section (2.1.140–2.1.179 latest、2026-05-13〜06-17 検出分) は `_archive/CLAUDE-CODE-OPPORTUNITIES-2026Q2.md` へ移した (Phase 3-B 再評価対象外)。

## 2.1.139 (detected 2026-05-12)

- [ ] **hook `args: string[]` (exec form)**: spawn directly without shell, no path argument quoting needed — candidate: `claude-code/templates/settings.json.template` hooks section. **Technical blocker** (re-verified 2026-07-05, no change at CLI 2.1.193): official docs (`code.claude.com/docs/en/hooks`) explicitly state `~` / `$HOME` **cannot be expanded** in exec form, and no user-scope global hook placeholder (`${CLAUDE_USER_HOME}` etc.) is provided. Available placeholders are only `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`. All 12 user-scope hooks invoke `~/.claude/hooks/*.sh`, so exec form requires hardcoded absolute paths = breaks template portability. Hold until Claude Code adds user-global placeholder (re-verify at next minor update)
