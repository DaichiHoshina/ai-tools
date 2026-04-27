---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-review 11観点 + 公式plugin/codex/coderabbit/pr-review-toolkit 統合）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで11観点統合（architecture/quality/readability/security/docs/test-coverage/root-cause/logging/writing/silent-failure/type-design）。`--deep`/`--multi` で外部レビュアーと並列。

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
| `--codex` | comprehensive + `codex review` 並列 | 任意 | セカンドオピニオン、両者共通指摘を Critical | 中 |
| `--ultra` | built-in `/ultrareview` 委譲 | 任意 | cloud並列、**localトークン消費なし** | cloud側 |
| `--plugin` | `/code-review:code-review` 委譲 | **必須** | 5並列Sonnet+Haiku信頼度80フィルタ→PR comment 投稿 | 中 |
| `--deep` | pr-review-toolkit 6専門agent並列 | 任意 | 観点深掘り（5-10分かかる、コスト大） | 大 |
| `--multi` | comprehensive + codex + plugin + coderabbit 並列 | **必須** | 4手段並列で false negative 最小化、リリース前用 | 最大 |

**実行分岐**:

```text
--ultra  → /ultrareview <引数> で終了
--plugin → /code-review:code-review <PR> で終了
--multi  → 後述 Multi フロー
--deep   → 後述 Deep フロー
--codex  → comprehensive-review skill + Bash(codex review) 並列
default  → Skill("comprehensive-review")
```

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

## Multi フロー（--multi）

PR必須。**フロー先頭で PR を local 化** してから4手段を並列実行する。

```text
0. PR fetch:
   - 引数=URL/番号 → `gh pr diff <PR> > /tmp/review-multi-<PR>.diff`
   - comprehensive-review には `--diff-source=/tmp/review-multi-<PR>.diff` を渡す
1. 並列起動（独立4プロセス、Agent or Bash）:
   a. Skill("comprehensive-review")（local 11観点、信頼度80フィルタ）
   b. Bash: `codex review --pr <PR>`（未インストール時 skip）
   c. /code-review:code-review <PR>（公式plugin）
   d. coderabbit:code-review skill
2. 4出力をマージ・重複除去
```

**集約方針**:

| 状態 | 扱い |
|------|------|
| 3手段以上で指摘 | Critical 確定 |
| 2手段で指摘 | Critical |
| 1手段のみ | Warning |
| 信頼度80未満（comprehensive側） | Warning 降格 |

**重複除去**: 同一ファイル:行±3行で同種指摘は1件にマージ、ソース手段を `[plugin][codex]` 等で併記。

**用途**: マージ直前PR、リリースクリティカル変更、セキュリティパッチ。日常使いではない。

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
