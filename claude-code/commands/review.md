---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-review 11観点 + 公式plugin/codex/coderabbit/pr-review-toolkit 統合）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで11観点統合（architecture/quality/readability/security/docs/test-coverage/root-cause/logging/writing/silent-failure/type-design）。`--deep`/`--multi` で外部レビュアーと並列。

## 共通レビュー制約

- 実 diff/code/docs に根拠ある指摘のみ。推測は「仮説:」明記
- スタイル・好み・一般論・スコープ外設計議論は出さない
- 指摘は action item として修正可能なものに限定
- 未依頼の issue/ticket/task/TODO 自動生成禁止
- 「念のため」「要確認」止まりの項目を実行タスクに昇格しない
- TODO は今回作業の blocker のみ

## Step 0: モード自動推定（フラグ無し時）

`--xxx` 無しで起動した場合、状況から推奨モードを推定し**ユーザー確認後に実行**（無確認で重いモード起動禁止）。

| 状況 | 推奨 |
|------|------|
| 1-15 ファイル | default 即実行 |
| 16+ または diff に `interface`/`type `/`class ` 含む | `--deep` 提案（要確認） |
| PR 引数あり + base が main/master | `--multi` 提案（要確認） |
| 引数に `設計`/`アーキテクチャ`/`トレードオフ` | `--adversarial` 提案 |

判定材料: `git diff --shortstat` / `gh pr diff <PR>` / `gh pr view <PR> --json baseRefName --jq .baseRefName` / `$ARGUMENTS` grep。

## 引数・モード

| 引数 | 動作 |
|------|------|
| なし | local diff レビュー |
| URL/番号 | `gh pr diff` / `glab mr diff` |
| `--focus=<観点>` | 11観点絞り込み |
| `--no-difit` | difit 抑制（local時） |

| モード | 委譲先 | PR | コスト |
|--------|--------|----|--------|
| (default) | `comprehensive-review` skill | 任意 | 中 |
| `--codex` | comprehensive + codex plugin 並列、共通指摘 Critical | 任意 | 中 |
| `--adversarial` | codex plugin `adversarial-review`（plugin 必須） | 任意 | 中 |
| `--deep` | pr-review-toolkit 6 agent 並列（5-10分） | 任意 | 大 |
| `--multi` | comprehensive + codex + code-review plugin + coderabbit 並列 → PR コメント自動投稿 | **必須** | 最大 |

cloud 大規模は `/ultrareview`（別コマンド）。

### CI 連携

非対話 `claude ultrareview <PR_or_path> --json` で機械可読出力、exit code でゲート化。slash 版（対話）と subcommand 版（CI）を使い分け。

## codex 呼び出し（--codex / --adversarial）

plugin runtime 経由: `node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" <review|adversarial-review> --wait`。`${CODEX_PLUGIN_ROOT}` は `ls -1d ~/.claude/plugins/cache/openai-codex/codex/* | tail -1`。plugin 未導入時は `--codex` のみ `codex review` 直叩きにフォールバック（`adversarial-review` は plugin 専用）。

## Adversarial フロー

**設計判断の正しさ・前提・実環境破綻箇所を問い詰める** モード。`$ARGUMENTS` で `--base <ref>`、`--scope auto|working-tree|branch`、focus テキスト追加可。長時間想定なら `--background` → `/codex:status`/`/codex:result <id>`。

用途: 設計レビュー、トレードオフ顕在化、PR 前自己批判。`/review`（実装欠陥）と相補。

## Deep フロー

`pr-review-toolkit` の 6 agent を 1 message 同時起動。詳細・集約方針: [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)。**コスト警告**: 数十秒〜数分×6並列。日常は default。

## Multi フロー

PR必須。**先頭で PR を local 化**してから4手段並列。

```text
0. PR fetch:
   - gh pr diff <PR> > /tmp/review-multi-<PR>.diff
   - PR_BASE=$(gh pr view <PR> --json baseRefName --jq .baseRefName)
1. 並列起動:
   a. Skill("comprehensive-review") with --diff-source=/tmp/review-multi-<PR>.diff
   b. codex plugin runtime --base "${PR_BASE}"（未導入時 codex review --pr <PR>）
   c. /code-review:code-review <PR>
   d. coderabbit:code-review skill
2. 4出力マージ・重複除去
3. gh pr comment <PR> --body-file - で自動投稿
```

集約方針（3手段以上=Critical 確定 等）: [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)。

用途: マージ直前 PR、リリースクリティカル、セキュリティパッチ。日常使いではない。

## 出力形式

```markdown
## 包括的レビュー結果
### 実行した観点
✅ architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### 🔴 Critical（修正必須・信頼度80以上）
- [security] SQLi（src/api/user.ts:120）信頼度95

### 🟡 Warning（要改善・信頼度25-79）
- [quality] 古いパターン（pkg/sort.go:15）信頼度65

Total: Critical N件 / Warning N件
```

縮退: ゼロ件 → `Critical/Warning 0件、Total 指摘なし (対象 N ファイル)` / Multi/Deep 一部失敗 → 末尾に `> [WARN] N 手段失敗` + `### 縮退要因`。

## Critical/Warning ↔ P0/P1

`/review` 単独 = `Critical→P0` / `Warning→P1` / その他 `P2/P3`（Team 経路では報告のみ）。詳細: [`reviewer-agent.md`](../agents/reviewer-agent.md)。

## レビュー方針・対象・difit

- **方針**: 厳しめ（見逃しより過検出優先）、差分のみ、Critical → Warning、11観点並列
- **対象**: 変更ファイル（git diff）、新規追加。除外: auto-generated、vendor/node_modules、lock
- **difit**: local 時のみレビュー後 background 起動（要 `npm i -g difit`、`--no-difit` で抑制）

詳細マッピング: [`references/command-resource-map.md`](../references/command-resource-map.md) / [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)。
