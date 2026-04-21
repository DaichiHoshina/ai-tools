---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, mcp__context7__*, WebSearch, WebFetch
description: ガイドライン陳腐化チェック&自動修正 - バージョン/廃止機能/冗長性/AI可読性を3軸検査
---

# /update-guidelines - ガイドライン総合レビュー&自動修正

`guidelines/` 配下を**3軸で検査**し、安全な修正は自動適用する。

| 軸 | 対象 |
|----|------|
| 🕰 陳腐化 | バージョン番号・リリース日・廃止API・非推奨パターン |
| 🗜 冗長性 | ファイル内/ファイル間の重複記述、冗長な前置き、余剰な例 |
| 🤖 AI可読性 | 表形式優先・短文化・判定ロジック明示・冒頭1行要約 |

## 使用方法

```
/update-guidelines                      # 全guideline 3軸検査→自動修正
/update-guidelines <path>               # 特定ファイルのみ
/update-guidelines --dry                # 検出のみ、修正なし
/update-guidelines --check-only         # --dry エイリアス（後方互換）
/update-guidelines --only=staleness     # 陳腐化のみ
/update-guidelines --only=redundancy    # 冗長性のみ
/update-guidelines --only=readability   # AI可読性のみ
```

`--only` 値（1文字略記も可）: `staleness|s` / `redundancy|r` / `readability|a`

## フロー

| Step | 動作 |
|------|------|
| 1. 対象特定 | 引数あり→該当ファイル / なし→`claude-code/guidelines/**/*.md` 全走査 |
| 2. 並列検査 | 3軸を並列で検査（各軸ごとに抽出→判定） |
| 3. 最新情報取得 | Context7 → 失敗時 WebSearch（陳腐化軸のみ） |
| 4. 自動修正 | 「安全」判定の修正のみ適用（判定表参照） |
| 5. 要レビュー集約 | 自動修正できない項目を列挙 |
| 6. 完了報告 | 3軸別 Critical/Warning/Info 集計 + 修正サマリー |

## 軸1: 陳腐化検査

| 種別 | 検出パターン | 重要度 | 自動修正 |
|------|-------------|--------|---------|
| 廃止API/機能 | 公式廃止アナウンス済（Firebase Dynamic Links等） | 🔴 Critical | 打ち消し+代替言及（削除しない） |
| メジャーVer乖離 | 記載 Go 1.20、最新 1.26 | 🟡 Warning | ✅ バージョン+日付更新 |
| マイナーVer乖離 | TS 5.7、最新 5.9.x | 🟢 Info | ✅ バージョン更新 |
| 非推奨パターン | Next.js pages/ router中心 | 🟡 Warning | 要レビュー（パターン変更は意味変化あり） |

**抽出パターン**:
- 言語/FW: `(TypeScript|Go|Python|Rust|Next\.js|React)\s*[\d.]+(対応|\+|時点)`
- リリース日: `\d{4}年\d{1,2}月(時点|リリース)`

## 軸2: 冗長性検査

| 種別 | 検出方法 | 重要度 | 自動修正 |
|------|---------|--------|---------|
| ファイル内重複 | 同一見出し2回、同じ表の再掲 | 🟡 Warning | ✅ 後者削除、前者へ統合 |
| ファイル間重複 | 2ファイル以上で同内容3行以上一致 | 🟡 Warning | 要レビュー（どちらが一次情報か判定必要） |
| 冗長な前置き | 「このガイドラインは〜について説明します」等 | 🟢 Info | ✅ 削除 |
| 余剰な例 | 同じ原則に3例以上 | 🟢 Info | 2例に縮約提案（要レビュー） |
| 長文説明 | 1段落 200字超 | 🟢 Info | 表形式への分解提案（要レビュー） |

## 軸3: AI可読性検査

| 種別 | チェック | 重要度 | 自動修正 |
|------|---------|--------|---------|
| 冒頭1行要約 | H1直後にファイル目的の1行があるか | 🟡 Warning | ✅ frontmatter description or 先頭1行追加 |
| 判定ロジック明示 | if/when系は表か箇条書きか | 🟡 Warning | 要レビュー（文章→表変換は意味精査必要） |
| 冗長な接続詞 | 「〜なので」「〜ですから」等敬語連発 | 🟢 Info | ✅ 体言止めに変換 |
| コード例過剰 | 同一原則に5行超の例 | 🟢 Info | 5行以内に短縮提案（要レビュー） |
| 絵文字過剰 | 1ファイルに絵文字10個超 | 🟢 Info | 必須マーカー（✅❌⚠️）以外を削減提案 |
| 英数字周りスペース | 日本語中の半角英数字前後の全/半スペース混入（例: 「Go 1.26 対応」の半角スペース、まれに全角も） | 🟢 Info | ✅ rules/markdown.md 準拠で削除（全/半両対応） |

## 修正の安全策

- **意味を変えない修正のみ自動化**: バージョン数字、冗長前置き削除、体言止め変換、全角スペース削除
- **構造変更は要レビュー**: 表形式への変換、パターン変更、ファイル間統合
- **Critical は --dry 強制**: 廃止API削除は必ずユーザー確認
- **diff 出力**: 修正後に `git diff --stat` で変更行数報告

## 出力形式

```
## ガイドライン3軸レビュー結果

### 🕰 陳腐化
Critical: N件 / Warning: N件 / Info: N件

### 🗜 冗長性
Warning: N件 / Info: N件

### 🤖 AI可読性
Warning: N件 / Info: N件

### 修正サマリー
- ✅ 自動修正: N件（Nファイル）
- ⚠️ 要レビュー: N件（列挙）
- ⏭ スキップ: N件

### 変更ファイル
- path (+X -Y)

### 次アクション
- sync.sh to-local → commit 提案
```

## スコープ外

- 新規ガイドライン作成（`/design-doc` or 手動）
- rules/references/skills の検査（guidelines に限定）
- コード本体（`/dev` の仕事）

## 実行後

```
./claude-code/sync.sh to-local
/git-push
```

ARGUMENTS: $ARGUMENTS
