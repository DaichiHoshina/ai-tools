---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, mcp__context7__*, WebSearch, WebFetch
description: ガイドライン陳腐化チェック＆自動修正 - バージョン/廃止機能/非推奨パターン検出
---

# /update-guidelines - ガイドライン陳腐化チェック＆自動修正

`guidelines/` 配下の陳腐化（古いバージョン・廃止API・非推奨パターン）を検出し、最新情報に**自動修正**する。

## 使用方法

```
/update-guidelines              # 全guideline自動修正（デフォルト）
/update-guidelines <path>       # 特定ファイルのみ
/update-guidelines --dry        # 検出のみ、修正なし
/update-guidelines --check-only # --dry と同じ
```

## フロー

| Step | 動作 |
|------|------|
| 1. 対象特定 | 引数あり→該当ファイル / なし→`claude-code/guidelines/**/*.md` 全走査 |
| 2. 抽出 | 各ファイルから **バージョン番号 / ライブラリ名 / FW名 / 廃止予定API** を正規表現で抽出 |
| 3. 最新情報取得 | Context7 (`mcp__context7__*`) → 失敗時 WebSearch でフォールバック |
| 4. 差分判定 | 下記「判定表」参照 |
| 5. 自動修正 | `--dry` 以外はEditで直接書換 |
| 6. 検証 | 修正後diff要約、書換箇所のファイル:行を報告 |
| 7. 完了報告 | Critical/Warning/Info 集計 |

## 判定表

| 種別 | 検出パターン | 重要度 | 自動修正 |
|------|-------------|--------|---------|
| 廃止API/機能 | Firebase Dynamic Links等（公式廃止アナウンス済） | 🔴 Critical | 削除 + 代替言及 |
| メジャーバージョン乖離 | 記載 Go 1.20、最新 1.26 | 🟡 Warning | バージョン番号+日付更新 |
| マイナーバージョン乖離 | TS 5.7、最新 5.9.x | 🟢 Info | バージョン番号更新 |
| 非推奨パターン | Next.js pages/ router中心の記述 | 🟡 Warning | app/ router前提に修正、旧記述は互換メモ化 |
| リリース日古い | 「2024年12月リリース」等 | 🟢 Info | 最新リリース日に更新 |

## 抽出パターン（正規表現サンプル）

| 対象 | パターン |
|------|---------|
| 言語バージョン | `(TypeScript|Go|Python|Rust)\s*[\d.]+対応` |
| FW バージョン | `(Next\.js|React|Vue|Svelte)\s*[\d.]+` |
| リリース日 | `\d{4}年\d{1,2}月(時点|リリース)` |
| 廃止機能 | 要ホワイトリスト（`rules/deprecated-apis.md` 等に列挙、なければスキップ） |

## Context7 の使い方

```
resolve-library-id(libraryName="next")
→ library_id 取得
get-library-docs(library_id, topic="version")
→ 最新版・リリース情報
```

失敗時は `WebSearch("<library> latest version 2026")` にフォールバック。

## 修正の安全策

- **意味を変えない**: バージョン数字の置換のみ。設計原則・パターン解説は変更しない
- **確認必要な修正は Warning コメント**: 「2026-04-21: X→Y候補、要レビュー」形式で追記し、自動書換しない
- **廃止機能**: 自動削除せず `> **DEPRECATED (YYYY-MM)**: ~~~~` と打ち消し + 代替言及
- **Critical時は --dry 強制**: 廃止API削除は diff を必ずユーザーに見せる

## 出力形式

```
## ガイドライン陳腐化チェック結果

### 🔴 Critical
- path:line: 内容 → 対応

### 🟡 Warning
- path:line: 内容 → 修正（自動 or 要レビュー）

### 🟢 Info
- path:line: 内容 → 修正

### 修正サマリー
- 自動修正: N件（Nファイル）
- 要レビュー: N件
- スキップ: N件

### 次アクション
- 自動修正済み → `sync.sh to-local` + commit 提案
- 要レビュー → ユーザー判断待ち項目列挙
```

## スコープ外

- 新規ガイドライン作成（手動で追加）
- guidelines 以外の rules/references/skills のバージョン更新（別コマンド対応）
- コード本体の更新（これは `/dev` の仕事）

## 実行後

```
/sync                        # （手動で）./claude-code/sync.sh to-local
/git-push                    # 変更をcommit+push
```

ARGUMENTS: $ARGUMENTS
