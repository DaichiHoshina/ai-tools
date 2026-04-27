---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-review 11観点 + 公式plugin/codex/coderabbit/pr-review-toolkit 統合）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで11観点統合（architecture/quality/readability/security/docs/test-coverage/root-cause/logging/writing/silent-failure/type-design）。`--deep`/`--multi` で外部レビュアーと並列。

## Step 0: モード自動推定（`--xxx` フラグ無し時）

ユーザーが `--xxx` フラグを明示せず `/review` または自然言語（"レビューして"等）で起動した場合、状況から推奨モードを推定し**ユーザー確認後に実行**（無確認で重いモード起動禁止）。

| 状況 | 推奨モード | 自動実行 |
|------|----------|---------|
| 1-15ファイル変更（local diff） | default | ✅ 即実行 |
| 16-30ファイル または diff に `interface`/`type `/`class ` 等の宣言含む | `--deep` 提案 | ⚠️ 確認後 |
| 30+ファイル | `--deep` 提案 | ⚠️ 確認後 |
| PR引数あり + `gh pr view <PR> --json baseRefName --jq .baseRefName` が `main`/`master` | `--multi` 提案 | ⚠️ 確認後 |
| 引数文字列に `設計`/`アーキテクチャ`/`トレードオフ`/`設計判断` のいずれか含む | `--adversarial` 提案 | ⚠️ 確認後 |

**判定材料**:

- ファイル数・行数: `git diff --shortstat` または `gh pr diff <PR> | diffstat`
- 変更タイプ: `git diff` 本文の正規表現マッチ（`^\+.*\b(interface|type|class)\s`）
- PR ベース: `gh pr view <PR> --json baseRefName --jq .baseRefName`
- 引数キーワード: 大文字小文字無視で `$ARGUMENTS` を grep

**確認 UX**: モード推奨を1行で表示 →「このモードで進める？ y / 別モード指定」。デフォルト y。

## 引数・オプション

| 引数 | 動作 |
|------|------|
| なし | `git diff` のローカル差分をレビュー |
| URL（http...）/ 番号 | `gh pr diff` / `glab mr diff` で差分取得 |
| `--focus=<観点>` | 11観点のいずれかに絞る |
| `--no-difit` | difit 起動抑制（local時のみ） |

## モード一覧

| モード | 委譲先 | PR要否 | 用途 | コスト |
|--------|--------|--------|------|--------|
| (default) | `comprehensive-review` skill | 任意 | 日常レビュー、信頼度80フィルタ | 中 |
| `--codex` | comprehensive + codex plugin runtime 並列 | 任意 | セカンドオピニオン、両者共通指摘を Critical | 中 |
| `--adversarial` | codex plugin の adversarial-review 委譲 | 任意 | 設計判断・トレードオフ・障害モード問い詰め | 中 |
| `--deep` | pr-review-toolkit 6専門agent並列 | 任意 | 観点深掘り（5-10分かかる、コスト大） | 大 |
| `--multi` | comprehensive + codex + code-review plugin + coderabbit 並列 → PR コメント自動投稿 | **必須** | リリース前最終確認、false negative 最小化 | 最大 |

cloud 大規模レビューは `/ultrareview` を直接使用（別コマンド、本コマンドの委譲先ではない）。

**実行分岐**:

```text
--multi        → 後述 Multi フロー
--deep         → 後述 Deep フロー
--adversarial  → 後述 Adversarial フロー
--codex        → comprehensive-review skill + codex plugin runtime 並列
default        → Skill("comprehensive-review")
```

**`--codex` の codex 呼び出し**: plugin runtime（`node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --wait`）経由で実行。`${CODEX_PLUGIN_ROOT}` は `~/.claude/plugins/cache/openai-codex/codex/<version>` を解決（`ls -1d ~/.claude/plugins/cache/openai-codex/codex/* | tail -1` で最新版選択）。plugin 未導入時は `codex review` 直叩きにフォールバック。

## Deep フロー（--deep）

`pr-review-toolkit` の6 agent を **1 message 内 6 Agent tool 同時呼び出し** で並列起動。

| subagent_type | 観点 |
|---------------|------|
| `pr-review-toolkit:code-reviewer` | CLAUDE.md準拠・ベストプラクティス |
| `pr-review-toolkit:silent-failure-hunter` | エラー握りつぶし・空catch |
| `pr-review-toolkit:type-design-analyzer` | 型による不変条件表現 |
| `pr-review-toolkit:comment-analyzer` | コメント正確性・comment rot |
| `pr-review-toolkit:pr-test-analyzer` | テストカバレッジ・edge case |
| `pr-review-toolkit:code-simplifier` | コード簡素化・可読性 |

各 agent prompt に対象 diff（`git diff` or `gh pr diff <N>`）を埋め込む。**コスト警告**: agent起動コストが大きい（数十秒〜数分×6並列）。日常は `/review` で十分。

**集約**: 信頼度80未満は Warning 降格、同一ファイル:行で観点違いはマージ。

## Adversarial フロー（--adversarial）

codex plugin の `adversarial-review` を委譲先とする。**実装欠陥より「設計判断の正しさ」「依存する前提」「実環境で壊れる箇所」を問い詰める** モード。**codex plugin 必須**（`adversarial-review` は plugin 専用機能、CLI 単体には存在しない）。

```bash
CODEX_PLUGIN_ROOT="$(ls -1d ~/.claude/plugins/cache/openai-codex/codex/* 2>/dev/null | tail -1)"
if [ -z "$CODEX_PLUGIN_ROOT" ]; then
  echo "Error: codex plugin 未導入。/codex:setup または 'claude plugin install openai-codex@claude-plugins-official' で導入してください" >&2
  exit 1
fi
node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" adversarial-review --wait $ARGUMENTS
```

`$ARGUMENTS` で `--base <ref>`、`--scope auto|working-tree|branch`、focus テキスト追加可。長時間想定なら `--background` で非同期実行 → `/codex:status` で進捗、`/codex:result <job-id>` で結果取得。

**用途**: 設計レビュー、アーキテクチャ判断の妥当性確認、トレードオフ顕在化、PR 前の自己批判。`/review`（実装欠陥）と相補。

## Multi フロー（--multi）

PR必須。**フロー先頭で PR を local 化** してから4手段を並列実行する。

```text
0. PR fetch:
   - 引数=URL/番号 → `gh pr diff <PR> > /tmp/review-multi-<PR>.diff`
   - PR ベースブランチ取得 → `PR_BASE=$(gh pr view <PR> --json baseRefName --jq .baseRefName)`
   - comprehensive-review には `--diff-source=/tmp/review-multi-<PR>.diff` を渡す
1. 並列起動（独立4プロセス、Agent or Bash）:
   a. Skill("comprehensive-review")（local 11観点、信頼度80フィルタ）
   b. Bash: codex plugin runtime（`node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" review --wait --base "${PR_BASE}"`）。plugin 未導入時は `codex review --pr <PR>` 直叩きにフォールバック
   c. /code-review:code-review <PR>（公式plugin）
   d. coderabbit:code-review skill
2. 4出力をマージ・重複除去
3. **PR コメント自動投稿**: 集約結果を `gh pr comment <PR> --body-file -` で PR にコメント投稿。Critical/Warning 件数サマリと findings リスト（ファイル:行 + ソース手段）を含む。
```

**集約方針**:

| 状態 | 扱い |
|------|------|
| 3手段以上で指摘 | Critical 確定 |
| 2手段で指摘 | Critical |
| 1手段のみ | Warning |
| 信頼度80未満（comprehensive側） | Warning 降格 |

**重複除去**: 同一ファイル:行±3行で同種指摘は1件にマージ、ソース手段を `[plugin][codex]` 等で併記。

**用途**: マージ直前PR、リリースクリティカル変更、セキュリティパッチ。日常使いではない。**`/review --plugin` の単独投稿機能は本モードに統合済み**（plugin だけ使いたい場合は `/code-review:code-review <PR>` 直接呼び出し）。

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

## レビュー方針

- **厳しめ**: 見逃しより過検出を優先
- **差分のみ**: 既存コードへの指摘は行わない
- **大量の差分**: 1ファイルずつ
- **優先度**: Critical → Warning
- **具体的な修正案**: 指摘+改善方法
- **並列実行**: 11観点を並列

## レビュー対象

含める: 変更ファイル（git diff）、新規追加
除外: auto-generated、vendor/node_modules、lockファイル

## difit統合

local時（引数なし）のみ、レビュー後に difit を background 起動。`--no-difit` で抑制。要 `npm i -g difit`。

### コメントJSON形式

```json
{
  "type": "thread",
  "filePath": "src/domain/user.ts",
  "position": { "side": "new", "line": 45 },
  "body": "🔴 Critical: [設計] ...\n\n修正案: ..."
}
```

- body prefix: Critical → `🔴 Critical:` / Warning → `🟡 Warning:`
- 行番号不明時は `line: 1`
- 全findingを1つの `--comment '<JSON配列>'` で `difit staged` or `difit .` に渡す

詳細な Skill / Agent マッピングは `references/command-resource-map.md` を参照。
