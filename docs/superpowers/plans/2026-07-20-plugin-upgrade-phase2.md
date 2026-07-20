# Plan: plugin upgrade phase 2 (brainstorm U1-U5 実施)

前段 brainstorm: `docs/superpowers/specs/2026-07-20-skill-upgrade-design.md` の後続。本 plan は 2026-07-20 brainstorm で採用判定した U1-U5 の 5 件を実装する。P1-P4 (条件付き併用) は本 plan 外 (別 plan で個別検証)、R1-R5 (却下) は再検討しない。

## Requirements

- [ ] U1: context7 skill の trigger 文言は harness MCP instruction に寄せる (skill file は `keep: on-demand` で残す)
- [ ] U2: `/promote` の CLAUDE.md 監査部分だけ claude-md-improver plugin に委譲する (org/project memory 階層解決は維持)
- [ ] U3: Stop event hook 系 3 本 (stop.sh / stop-verify.sh / stop-failure.sh) の header 共通部を `hooks/lib/stop-common.sh` に括り出す (dispatcher 統合はしない)
- [ ] U4: LSP 系 plugin 5 本の template 側に「対応言語 project では true 化推奨」の comment 節を 1 行追加する (一括 true 化はしない)
- [ ] U5: `~/ai-tools/memory/pending-improvements.md` 冒頭に「session 内 TODO は built-in TaskCreate、cross-session index は本 file」の routing 節を 1 行追加する

## Architecture

- Pattern: 単純置換ではなく **併用 / 括り出し / 文言追加**。phase 5 (frontend-design) で証明された「単純置換で repo 固有規範が飛ぶ」罠を避ける
- 変更対象: 6 file (context7/SKILL.md 64 行 / promote.md 114 行 / stop.sh 144 行 / stop-verify.sh 273 行 / stop-failure.sh 23 行 / settings.json.template 494 行) + 新規 1 file (hooks/lib/stop-common.sh) + memory 1 file (pending-improvements.md)
- 各 phase の変更行 5-30 行を目安に留める。overshoot したら phase を分割する
- 効果測定 baseline は本 plan 完了時に取得し、2026-07-27 の phase 1 / phase 4 効果測定と同 turn で読む

## Implementation plan

### Phase 1 (U1): context7 skill の trigger 文言スリム化

- `skills/context7/SKILL.md` 冒頭の trigger 節を「library method 直書き前の gate 判定のみ」に絞り、harness MCP instruction (session 起動時に system-reminder として注入される「Use this server whenever...」) と重複する説明を削る
- frontmatter `keep: on-demand` は維持
- gate 文言 (「library method 直書き / 新 library 採用 / API spec 6 か月超」) は harness 側にないため残す
- 変更目安: -10 行 / +2 行

### Phase 2 (U2): /promote の CLAUDE.md 監査を plugin 委譲

- `commands/promote.md` 内 CLAUDE.md 昇格 step で `claude-md-management` plugin の `claude-md-improver` skill を呼び出す fork を追加する
- 前提: `references-private/memory-promotion-flow.md` の org/project memory 階層解決 (`memory-save-helper.sh resolve-dir`) と、社内固有名詞辞書 filter は残す
- plugin 呼び出し失敗時は現行の手動監査 flow に fallback する
- 変更目安: promote.md に +15 行 (plugin 呼び出し節)、`memory-promotion-flow.md` は変更しない

### Phase 3 (U3): Stop hook header 共通化

- 新規: `hooks/lib/stop-common.sh` (shebang / `set -euo pipefail` / lib source 共通部を関数化)
- `hooks/stop.sh` / `stop-verify.sh` / `stop-failure.sh` の 3-8 行目付近を `source stop-common.sh` に置換する
- **regression 防止 rule**: dispatcher 化はしない (skeptic 9 で「Stop event 7 hook chain の順序依存」が明示された)。settings.json.template の hook 配列順は変更しない
- `hooks/tests/` に既存 test があるか確認し、無ければ smoke test 1 本追加する (stop.sh を空 stdin で走らせて exit 0 を確認する)
- 変更目安: 新規 20 行 / 各 stop hook -5 +1 行

### Phase 4 (U4): LSP plugin 5 本の有効化基準を doc に明記

- template file は pure json (comment 不可) 確定済のため、`docs/plugin-adoption-note.md` (新規) に有効化基準を書く
- 内容: LSP plugin 5 件 (gopls / typescript / python / rust-analyzer / pyright) は「対応言語を主に触る project の live settings.json 側で true 化推奨。template 側は false 維持 (全 project 一律 true にすると未使用 project で MCP 起動 cost が乗る)」
- `templates/settings.json.template:404-415` は変更しない
- 変更目安: 新規 20 行

### Phase 5 (U5): pending-improvements routing 節追加

- `~/ai-tools/memory/pending-improvements.md` 冒頭 frontmatter 直下に routing 節を追加する
- 内容: 「session 内 TODO は built-in TaskCreate / TaskList / TaskUpdate で管理する。本 file は cross-session 追跡 (retrospective 採否 / 効果測定 baseline / 日付付き完了 log) 専用」
- 既存 Completed / Pending 節構造は変更しない
- 変更目安: +4 行

### Phase 6: 効果測定 baseline 取得

- Phase 1: context7 skill 呼び出しの system-reminder 重複行数を実測 (`grep -c "context7" ~/.claude/logs/*.log` の before / after)
- Phase 3: stop hook 3 本の合計行数 (before: 440 行、after: 目標 <420 行 + 共通 lib 20 行)
- Phase 4/5: 定量指標なし、実運用で 2026-07-27 の効果測定と同時に「有効化基準の comment に従って LSP 有効化したか」「Task tool が session 内 TODO で使われたか」を確認する

## Execution mode

- Mode: **`/dev` sequential (phase 1 → 2 → 3 → 4 → 5 → 6)**
- Basis: 6 file 変更だが phase 独立性は高い一方、phase 2 (promote plugin 併用) は claude-md-improver の実挙動確認が phase 内で必要 / phase 3 (hook 共通化) は smoke test の実測 gate が要る / phase 4 (jsonc 判定分岐) が実 file 確認まで決まらない、と各 phase に「実測次第で分岐」が入る。`/flow` の PO/Manager/Dev 分業より 1 developer-agent の sequential 実施が overhead 回収的に有利
- LPT_makespan: 各 phase 5-15 分 = 合計 30-60 分。並列化して稼げる時間 < agent 起動 overhead (60s × N)
- 想定 diff: 全 phase 合計で <100 行、`/workflow` の 500 行 cap 内だが scripted fan-out する構造ではないため不採用

## Worktree

- Needed: **Yes** (ai-tools repo の Worktree-first 方針に従う)
- Branch name: `feat/plugin-upgrade-phase2`
- flow: `wt add` → 各 phase で commit → 全 phase 完了後に verify → main へ ff-merge → wt 削除 (`references/on-demand-rules/ai-tools-worktree-flow.md` canonical)

## Rejected / Deferred (蒸し返し防止)

以下は brainstorm で判定済のため本 plan では扱わない。再検討したい場合は根拠を更新してから別 plan を立てる。

- **R1** jp-fix skill を natural-japanese に完全置換 (skeptic 1: jp-quality-block gate 消失)
- **R2** explore-agent を built-in Explore に一本化 (skeptic 2: bundle 検証と trailer schema 消失)
- **R3** mino-* 7 skill の 1 skill 統合 (skeptic 10: 信頼度低く撤去議論が筋)
- **R4** `/dev` `/flow` `/workflow` `/goal` `/loop` の統廃合 (skeptic 8: maker-checker / fresh-context loop 独自)
- **R5** brainstorm command の superpowers 完全委譲 (skeptic 5: --debate Gate と trailer 独自)
- **P1-P4** 条件付き併用 4 件 (natural-japanese quick 併用 / pr-review-toolkit Stage A 併用 / superpowers finishing-branch checklist 参照 / TDD skill 参照) は本 plan の U1-U5 完了後に別 plan で個別検証する

## Next command

/dev --plan /Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools/docs/superpowers/plans/2026-07-20-plugin-upgrade-phase2.md
