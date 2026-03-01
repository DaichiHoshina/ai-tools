---
allowed-tools: Bash, Read, Glob
description: TAKTワークフローエンジンを使ったYAML宣言的タスク実行
---

## /takt - TAKT宣言的ワークフロー実行

> **`/flow` との使い分け**
> - `/flow`: 複雑なAgent Team（PO→Manager→Dev並列）
> - `/takt`: YAML宣言的ワークフロー（plan→impl→review自動ループ）
> - 迷ったら `/flow` を使用

## 使用方法

```bash
/takt [タスク説明]                          # default-miniで実行
/takt --piece ai-tools-workflow [タスク]     # ai-tools専用ワークフロー
/takt --piece default-test-first-mini [タスク] # TDDワークフロー
/takt --list                                # 利用可能なpieceを表示
```

## 利用可能なpiece

| piece | 用途 |
|-------|------|
| default-mini | 標準（plan→implement→review→fix） |
| default-test-first-mini | TDD（plan→test→implement→review→fix） |
| ai-tools-workflow | ai-tools専用（Serena MCP統合） |

## 実行ロジック

### `--list` の場合

`.takt/pieces/` の内容を一覧表示する。

### タスク実行の場合

1. piece未指定なら `default-mini` を使用
2. takt CLIを呼び出す:

```bash
takt -t "タスク内容" -w [piece名] --create-worktree no
```

3. TAKTが自動でplan→implement→reviewループを実行
4. 完了後、`/git-push` を提案

### 重要な注意点

- `--create-worktree no` を常に付与（Claude Codeのworktreeと干渉防止）
- TAKTはインタラクティブターミナルが必要（Bash toolで実行）
- TAKT実行中はClaude Codeの操作を待機

## オプション透過

`/takt` に渡された追加オプションはそのまま `takt` CLIに透過する:

```bash
/takt --auto-pr タスク内容        # 完了後PR自動作成
/takt --pipeline タスク内容       # パイプラインモード
/takt -c                         # 前回セッション継続
```

ARGUMENTS: $ARGUMENTS
