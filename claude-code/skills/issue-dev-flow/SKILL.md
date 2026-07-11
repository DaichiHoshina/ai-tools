---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview
name: issue-dev-flow
description: GitHub issue 起点の開発 flow skill。PRD / DesignDoc を SoT に、モノリス影響分析 → PR 分割 → フロント非影響先行 merge で進める。「issueベースで開発」「issue 起点で」で起動。— DD 生成は /design-doc、実装は /dev・/flow を使う
requires-guidelines:
  - common
---

# issue-dev-flow

GitHub issue を起点に「SoT 確認 → 影響分析 → PR 分割 → 実装 → 順次 merge → 進捗報告」の工程をつなぐ司令塔 skill。各工程の詳細は既存 canonical を参照し、本 file には再掲しない。

## When to Use

- 「issue ベースで開発して」「issue #NNN を起点に進めて」と言われた時
- PRD / DesignDoc がある機能開発を、分割 PR で段階 merge しながら進める時
- 巨大モノリスで変更の影響範囲が読めず、設計から入る必要がある時

## Steps

### 1. Issue 把握

`gh issue view <番号>` で要件・受入条件を取得する。issue 本文から PRD / DesignDoc への link を辿る。link が無ければ user に所在を 1 問だけ確認する。

### 2. SoT 確認

PRD / DesignDoc を SoT として Read する。実装中に設計と実装の乖離が出たら「DD を先に更新 → 実装」の順を守り、実装側で勝手に設計を変えない。DD の新規生成・大改訂は `/design-doc` へ委譲する。

### 3. モノリス影響分析 (設計の要)

変更対象 symbol ごとに `mcp__serena__find_referencing_symbols` で fan-in (呼び出し元) を洗い、影響する module / 層を列挙してから設計を確定する。層境界の妥当性確認は `clean-architecture-ddd` skill を使う。DB 変更は DoD #7 の 4 経路 (FK / long TX / replica lag / maintenance scope) を必ず見る。

### 4. PR 分割設計

`references/on-demand-rules/pr-release-order.md` を Read し、merge 順 = 本番反映順で PR を一列化する。フロント影響なし (schema / backend / 内部 API) を先行、フロント公開系を後段に置く。分割案 (PR 一覧 + merge 順) は issue comment に明記する。

### 5. 実装

`/dev` または `/flow` へ引き継ぐ。plan / DD を SoT のまま渡し、実装側で scope 再調査と mode 再判定をしない。

### 6. Chain merge 運用

`references/on-demand-rules/chain-pr-main-merge.md` に従い、上流 PR から順次 main へ伝播する (並列 main merge 禁止)。PR merge の実行は user が行う (Git Merge Prohibition)。

### 7. 進捗報告

分割案確定・各 PR 作成・merge 完了などの節目で `/post-comment gh-issue-comment` により issue へ進捗を書く。

## Guard

- project 固有規約 (実装方針 / build tags / 表記等) は memory `[[project-*-dev-conventions]]` 側を参照する。本 skill に project 名・固有値を書かない (public repo 制約)
- issue 番号は `gh issue view` で実在検証してから PR body に書く (`/git-push` と同じ規約)

## Out of Scope

- DesignDoc の生成・大改訂 (`/design-doc`)
- 実装 mode の判定 (`/mode` / `/plan`)
- PR merge の実行 (user が browser で行う)
