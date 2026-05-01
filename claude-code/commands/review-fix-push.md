---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Skill, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: レビュー→修正→regression check→プッシュを1コマンドで実行。/review + /dev 全修正 + 再レビュー + /git-push --pr。
---

## /review-fix-push - レビュー・修正・regression・プッシュ

レビューで見つけた問題を修正→**再レビューで regression なし確認**→push→PR作成。修正で新たな Critical を作らない保証付き。

## フロー

### Step 1: 初回レビュー

```text
Skill("comprehensive-review")
```

11観点 + 信頼度80フィルタ。Critical/Warning 別に分類。完了後 difit でブラウザ表示（`--no-difit` で抑制）。

### Step 2: 判断

| 状態 | 動作 |
|------|------|
| Critical 0件 & Warning 0件 | Step 5 へ（push のみ） |
| 指摘あり | Step 3 へ |

### Step 3: 修正

| 種別 | 方針 |
|------|------|
| Critical | 全件修正（必須） |
| Warning | 全件修正（`--critical-only` 指定時はスキップ） |

`/dev` 同等（ガイドライン読込・静的解析確認含む）。

### Step 4: regression check（ループ）

修正で新規問題を作っていないか **再レビュー**。

```text
loop iteration = 1..max_iterations:
    Skill("comprehensive-review") on (修正後 diff)
    if 新規 Critical 0件:
        if 既存 Warning ≤ 初回の件数:
            break  # 収束、Step 5 へ
        else:
            warn ユーザー、Step 5 へ（無限修正回避）
    else:
        Step 3 を再実行（新規 Critical のみ修正）
```

**ループ脱出条件**:

| 条件 | 動作 |
|------|------|
| 新規 Critical 0件 | 収束、push へ進む |
| iteration >= max_iterations（デフォルト3） | ユーザーに状況提示→続行確認 |
| 同一指摘が連続2回出現（修正できてない） | ループ中断、ユーザーに手動修正要請 |

### Step 5: プッシュ

```text
/git-push --pr
```

修正コミット→ブランチ push→PR 作成。

## オプション

| 引数 | 説明 |
|------|------|
| (なし) | 全工程実行（regression loop 含む） |
| `--critical-only` | Critical のみ修正 |
| `--dry-run` | レビューのみ（修正・push しない） |
| `--no-difit` | difit 起動抑制 |
| `--no-regression` | Step 4 を skip（旧来挙動） |
| `--max-iterations <N>` | regression ループ上限（デフォルト3） |
| `--from-pr <N>` | PR セッション復元してレビュー |

`--from-pr` 指定時は Step 0 で `claude --from-pr <N>` 相当のコンテキスト復元、そのPR差分に対してレビュー。

## 出力フォーマット

ループ進捗:

```
Iteration 1/3: Critical 3 → 0 / Warning 5 → 2 (収束)
Iteration 2/3: skip (収束済み)

Result: PASS → push 進行
```

ループ未収束:

```
Iteration 3/3: Critical 1 残存 (同一指摘 2 回連続)
> [WARN] 自動修正できない指摘あり、ユーザー介入要請
push 中断、Critical 一覧:
  - {ファイル:行} - {指摘内容}
```

## 注意

- 修正前にレビュー結果をユーザーに表示し確認を得る
- force push 禁止
- 修正後に lint/type check 自動実行
- regression ループは **修正で新たな問題を作らない保証** が目的。止まらない場合は手動介入

ARGUMENTS: $ARGUMENTS
