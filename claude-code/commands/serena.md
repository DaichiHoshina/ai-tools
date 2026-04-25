---
allowed-tools: Read, Glob, Grep, mcp__serena__*
description: 旧コマンド。/dev または /diagnose を使用（Serena MCP は両者で利用可能）
---

# /serena（deprecated）

このコマンドは廃止予定。後続コマンドへの最小リダイレクト。

> ユーザーが `/serena` を起動した場合、Claude は下記移行表に従って引数（`-q`/`-d`/`-c`/`-s`/`-r`/`--lang`）を変換し、対応する新コマンドを自動実行する。表にない引数は最も近い意図のコマンドを推定して呼ぶ。

## 移行先

| 旧オプション | 新コマンド |
|------------|---------|
| `/serena "..." -q` | `/dev --quick "..."` |
| `/serena "..." -d` | `/diagnose "..."` または `/refactor "..."`（深い分析） |
| `/serena "..." -c` | `/dev "..."`（コード操作はデフォルトで Serena MCP 経由） |
| `/serena "..." -s` | `/plan "..."` → `/dev "..."`（Phase 分割） |
| `/serena "..." -r` | `/dev "..." --research`（Context7 連携） |
| `/serena "..." --lang=go` | `/dev "..." --lang=go`（言語ガイドライン自動読込） |
| `/serena オンボーディング` | `Skill(load-guidelines)` + `mcp__serena__list_memories` |

## なぜ廃止か

Serena MCP は `/dev` `/diagnose` `/refactor` `/plan` `/explore` の **全実装系コマンドで既定利用**。`/serena` 独自の付加価値はオンボーディング memory 連携のみだったが、これは `Skill(load-guidelines)` で代替可能。

ARGUMENTS: $ARGUMENTS
