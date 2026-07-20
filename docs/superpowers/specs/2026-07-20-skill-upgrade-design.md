# Skill 上位互換棚卸し・置換方針 spec

**Goal:** ai-tools repo 内 self-made skill (32 本) と外部 plugin skill (21 本、5 marketplace) を突き合わせ、置換 / 併存 / 新設の判定を確定する。

**Scope:** 判定と方針までを本 spec で確定する。実装 plan は別 file (下記「実装 phase 分割」)。

**Non-goals:** 全 skill の実装差替えを本 spec で一括計画しない (分割せずに書くと巨大化するため)。

---

## 前提の再確認 (前 turn 報告からの訂正)

前 turn 報告で「upstream 置換で解決」と書いた 2 件は、実物確認で前提が変わった:

1. **mino-\* / react-best-practices の upstream plugin は Claude marketplace に存在しない**。cache dir (`~/.claude/plugins/cache/`) に該当 marketplace が無い。GitHub repo (`my-take-dev/inspired-mino-design-skills` / `vercel-labs/agent-skills`) は存在するが、plugin 化されていない → **単純 install での置換は不可**
2. **frontend-design の plugin 版と ai-tools 版は別物**。plugin 版 (`claude-plugins-official:frontend-design/frontend-design`) は「BOLD aesthetic direction」重視、ai-tools 版は「distinctive point of view」で近いが文面別。**同一物ではない**

## 棚卸し結果 (再掲、確定版)

### 素材

| dir | skill 数 | 主要 skill |
|---|---|---|
| `~/ai-tools/claude-code/skills/` | 32 | jp-fix / code-comment / local-docs / mino-\* 6 / react-best-practices / frontend-design / root-cause / comprehensive-review 等 |
| `~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.1.1/skills/` | 13 | brainstorming / writing-plans / executing-plans / systematic-debugging / verification-before-completion 等 |
| `claude-plugins-official/` | 少数 | claude-md-improver / frontend-design / coderabbit code-review + autofix |
| `natural-japanese/` / `genshijin/` / `openai-codex/` | 各 1-3 | natural-japanese (AI 臭除去) / genshijin (超圧縮) / codex 内部連携 |

### 判定 table

| ai-tools 側 skill | 候補 | 判定 | 根拠 |
|---|---|---|---|
| **mino-\* 6 本** | upstream `my-take-dev/inspired-mino-design-skills` | **保留** (upstream 追従体制を後日検討) | plugin 化されていないため即置換不可。GitHub 直取り込み体制が要る |
| **react-best-practices** | upstream `vercel-labs/agent-skills` | **保留** (同上) | 同じ理由 |
| **frontend-design** (ai-tools) | `claude-plugins-official:frontend-design` | **併存 (現状維持)** | 文面別、思想差あり (BOLD vs distinctive)。統合には diff 比較 + user 選好確認が必要 |
| **context7** (ai-tools) | context7 公式 MCP / plugin | **保留** (存在確認未実施) | 公式 plugin の marketplace 登録状況を別途確認する |
| **root-cause** (ai-tools) | `superpowers:systematic-debugging` | **併存** | ai-tools 側は 5 Why + Serena 連携で repo 固有、superpowers 側は trigger 設計が汎用。役割違いで両立可 |
| **comprehensive-review / uiux-review / baseline-ui** | `coderabbit:code-review` + `autofix` | **併存** | ai-tools 側は 12 観点独自、CodeRabbit は外部 AI 連携。差別化明確 |
| **jp-fix** (ai-tools) | `natural-japanese:natural-japanese` | **併存 + 参考取り込み検討** | ai-tools 側は PRINCIPLES / NG-DICTIONARY と密結合。完全置換不可、trigger 語彙は参考にできる |

### 外部にあって ai-tools にない skill (新設候補)

| plugin:skill | 埋める穴 | 優先度 |
|---|---|---|
| `superpowers:verification-before-completion` | 「証拠なき完了断定禁止」の hard gate。jp-quality log で「完了」141 件 block 中で相性◎ | **高** |
| `superpowers:brainstorming` | 実装前の要件掘り下げ hard gate。`/plan` command と同居可 | 中 |
| `superpowers:writing-skills` | skill 作成の規範化。`/skill-add` command の下敷き | 中 |
| `superpowers:dispatching-parallel-agents` | 並列 fan-out 判断を skill 化。CLAUDE.md rule と併走 | 低 (rule で機能中) |
| `superpowers:using-git-worktrees` | worktree 発火 skill。on-demand-rule と併走 | 低 (rule で機能中) |
| `superpowers:test-driven-development` / `writing-plans` / `executing-plans` / `subagent-driven-development` | 対応 skill 無し。command 側で近似 | 中 (superpowers 使用時に自然発火するので既に得られている) |

## 実装 phase 分割

本 spec 承認後、以下の順で個別 plan を書く (1 phase = 1 plan file、書く時期は user 判断):

- **phase 1 (2026-07-20 実施済)**: verification-before-completion 発火徹底 → `docs/superpowers/plans/2026-07-20-verification-gate-adoption.md`。CLAUDE.md に節追加 + `lib/jp-quality/block-checks.sh` の「完了」文末 block message に skill 発火指示を織り込み
- **phase 2 (2026-07-20 rejected)**: brainstorming / writing-skills の skill 化検討 → **skip**。理由: superpowers 側で既に稼働中 (skill list に登録済、prompt 冒頭でも参照可能)。ai-tools 側に再実装する追加コストが実効果を上回る
- **phase 3 (2026-07-20 rejected)**: mino-\* / react-best-practices の upstream 追従体制 → **現状維持**。理由: upstream (GitHub) が plugin 化されておらず submodule / subtree / 定期 fetch のいずれも手動追従コストが残る。ai-tools 側 skill が「非公式再構成」と自己申告済であり、使用頻度が upstream 更新の手動追従コストを正当化するかは未確定。将来 upstream が plugin 化された時点で phase 4 (context7) と同じ手順で再検討する
- **phase 4 (2026-07-20 実施済)**: context7 公式 plugin 存在確認 & 移行判定 → **MCP 化で置換**。`@upstash/context7-mcp` (v3.2.4) を `claude mcp add --scope user context7` で登録、skill file を curl 手組みから MCP tool 呼び出しに書き換え。Failure Behavior は skill 使用者向け指示として温存。plan: `docs/superpowers/plans/2026-07-20-context7-mcp-migration.md`
- **phase 5 (2026-07-20 実施済)**: frontend-design の diff 精査と統合判定 → **ai-tools 版に一本化**。plugin 版 (`frontend-design@claude-plugins-official`) を `settings.json:442` で `false` に flip した。理由: 両版が同名 skill として active になっており衝突していた。ai-tools 側は既に tool 制限 / review 除外 / writing 章を customize 済

phase 1 を先行した理由: (a) plugin install だけで完結、リスク最小 (b) 効果測定指標 (`~/.claude/logs/jp-quality-block.log` の「完了」件数) が既にある (c) 可逆

## 未確定事項 (2026-07-20 時点)

1. **phase 1 効果測定**: 2026-07-27 に `wc -l ~/.claude/logs/jp-quality-block.log; grep -c "完了" ~/.claude/logs/jp-quality-block.log` で after 値を計測する
2. **phase 4 効果測定**: 2026-07-27 に `claude mcp list | grep context7` で Connected 継続と、skill 発火時の MCP tool call 成功状態を確認する
3. **phase 5 副作用**: frontend-design 発火時にどちらの skill が呼ばれるか、次 session 起動時に skill list 側で確認する

## 参照

- inventory 素材: 前 turn の explore-agent 2 本の報告 (会話 log)
- jp-quality 効果指標: `~/.claude/logs/jp-quality-block.log`
- ai-tools skill 実物: `~/ai-tools/claude-code/skills/`
- superpowers 実物: `~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.1.1/skills/`
