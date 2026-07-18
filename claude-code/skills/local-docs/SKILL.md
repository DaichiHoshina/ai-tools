---
allowed-tools: Bash, Read, Edit
name: local-docs
description: local-docs 配下 HTML doc 作成・更新 skill。「postmortem」「報告資料」「検証レポート」「RCA」「調査ログ」で起動。
---

# local-docs

`~/ghq/<repo>/local-docs/` 配下に HTML doc を作成 / 更新する専用 skill。type enum / 集約呼称 / placement は local-docs の `CLAUDE.md` と `STRUCTURE.md` から section 単位で毎回 Read する (session 跨ぎの記憶を使わない、詳細は Prerequisites)。

## 禁止 rule (違反 = 即 abort)

以下は過去 incident 起因の hard rule。1 つでも踏むと共有 CSS / index build / decorate が破綻する。

| Rule | 理由 |
|---|---|
| skill 起動なしで `local-docs/` 配下に HTML を書く | 過去 incident: inline `<style>` で共有 CSS 破壊 |
| `Write` で HTML 直書き | skeleton / `<style>` / `<script>` を上書きして壊す |
| `.md` で新規 doc 作成 | 全 doc は `_templates/{type}.html` から `cp` する |
| `<style id="local-docs-style">` / `<script id="local-docs-script">` の変更 | 共有 infrastructure、decorate / TOC / hero / num badge が破綻 |
| skill file (本 file) 自体に社名 / product 名を書く | public repo 制約。proprietary 情報は local-docs 側 `CLAUDE.md` に置く |

## auto activation trigger

skill は明示 invoke なしでも auto activate する (以下 3 分類のいずれかで起動)。

| 種別 | trigger |
|---|---|
| user 発話 | 「local-docs」「ナレッジ」「runbook」「RCA」「postmortem」「報告資料」「検証レポート」「spec」「調査ログ」「監視結果」「post-release」「dashboard 確認」「5xx 分析」「インシデント記録」「試験結果」「session 跨ぎ」「試行錯誤メモ」 |
| 出力先 path | `local-docs/{projects,domain-specs,tool-guides,operations}/` 配下 |
| 拡張子 | 上記 path 下の `.html` |

## Subcommand

- `/local-docs new {type} {topic}`: 新規作成
- `/local-docs update {path}`: 既存 doc の追記 / 書き直し
- `/local-docs update {path} --reformat`: skeleton を最新 template に整合
- (省略時): 文脈から `new` / `update` を推定する

## Prerequisites (毎回 section 単位 Read、全文 Read 禁止)

local-docs repo root を特定し、`grep -n '^##' CLAUDE.md STRUCTURE.md` で見出し行番号を取得してから、下表の section のみ Read offset/limit で読む。見出しが grep で見つからない場合のみその file を全文 Read に fallback する。session 跨ぎの記憶で section 読みを skip しない (毎回 grep + Read する)。`STRUCTURE.md` の type enum / status enum / タイトル規約 section は `CLAUDE.md` 再掲なので読まない。

| File | 読む section (見出し文字列) | 用途 |
|---|---|---|
| `CLAUDE.md` | `## Templates` | type enum + canonical mapping (正本) |
| `CLAUDE.md` | `## Title Rules` | title 規約 |
| `CLAUDE.md` | `## Metadata` | status enum / updated / type 別日付 |
| `STRUCTURE.md` | `## 置き場判断フロー` | 出力 dir 決定 (`new` 時のみ) |
| `STRUCTURE.md` | `## html 形式` | metadata コメント形式 (`new` 時のみ) |
| `CLAUDE.md` | `## コンポーネント活用マップ` | 本文組立時のみ (任意) |

## Flow: `new {type} {topic}`

### Step 1. Type / Placement 決定

topic から type を判定し、variant は `CLAUDE.md` mapping で canonical 化する (canonical type enum 内か確認)。`STRUCTURE.md` placement flow に従い出力 dir を決定する (無ければ `mkdir`)。

### Step 2. Template 起点で file 作成 (Write 禁止)

```bash
cp _templates/{type}.html {dir}/{name}.html
```

`cp` で起こしてから `Edit` のみで埋める。

### Step 3. 本文 guideline Read (section 単位)

`guidelines/writing/long-form-doc.md` の冒頭 (plain JP 規範) と §品質検証タイミング のみ Read する。postmortem / report 作成時のみ §報告書・振り返り構造 を追加で読む。ADR / PRD / EARS 節は local-docs では読まない。

### Step 4. 本文を埋める (Edit only)

`{...}` placeholder を Edit で置換する。skeleton h2 / `<style>` / `<script>` は保持する。書き出し規範: 1 文 100 字 / PREP / 段落 3〜4 行 / 指示語具体化 / NG 語回避。

### Step 5. Metadata 設定

共通: `<!-- type: -->` / `<!-- status: -->` / `<!-- created: YYYY-MM-DD -->` (全 type 必須) / title (h1、`CLAUDE.md` §Title Rules 準拠、親 context repeat 禁止)。既存 doc の本文を実質編集したら `<!-- updated: YYYY-MM-DD -->` を必ず今日の日付にする (無ければ挿入、build.mjs が updated を優先ソートに使う)。

| type | 追加 metadata | 意味 |
|---|---|---|
| `investigation` / `postmortem` | `<!-- event-date: YYYY-MM-DD -->` | 障害発生日 (調査は対象日) |
| `report` | `<!-- data-window: YYYY-MM-DD/YYYY-MM-DD -->` | 計測期間 (単日なら同日) |
| `log` | `<!-- observed-at: YYYY-MM-DD -->` | 観測日 (継続なら最新) |
| `spec` / `runbook` / `guide` / `plan` | (なし、`created` のみ) | — |

**禁止**: `<meta name="last-updated">` / frontmatter `last-updated:` / `<!-- last-updated: -->` (deprecated)。title への日付埋込のみで metadata 省略も NG。

### Step 6. Self-check (生成直後)

先頭 2 行が `<!-- type: -->` / `<!-- status: -->` かつ `<style id="local-docs-style">` 存在かつ `<script id="local-docs-script">` 存在。1 つでも欠けたら template 再 `cp` からやり直す。

### Step 7. Polish & Verify (skip 禁止)

| 手順 | 内容 |
|---|---|
| 7-1 | type 別品質 check を本文に適用 |
| 7-2 | `jp-fix` skill を実行 (skill 本体を起動) |
| 7-3 | Critical 1+ or Warning 4+ で書き直し (最大 2 loop、3 loop 残存は user 報告) |
| 7-4 | body に `textlint` を実行 |
| 7-5 | `node _index/build.mjs` を実行、exit 0 確認 |
| 7-6 | user に browser で layout 確認を依頼 |

合格ライン: `guidelines/writing/long-form-doc.md` §品質検証タイミング

## Flow: `update {path}`

| 条件 | Mode |
|---|---|
| `--reformat` 明示 | reformat |
| legacy 構造検出 (manual toc / tldr / decorate 欠落 / 旧 inline style) | reformat (user 提案) |
| 上記なし | default (content-update) |

default: 既存 doc を Read → body 追記 / 書き直し (skeleton / style / script 触らない) → Step 7 通す。
reformat: skeleton を最新 template に整合 → legacy 削除 → body 保持 → metadata 修正 → Step 7 通す。

## Type-specific authoring (本文品質)

共通の文体規範は `guidelines/writing/long-form-doc.md` に従う。type enum / h2 列挙は local-docs `CLAUDE.md` / `_templates/{type}.html` canonical。本節は type 別差分のみ。開いた文章 (plain JP) 必須: 箇条書き・表 cell 外の本文は「〜する / 〜した」で文として閉じる。体言止め羅列・助詞省略を body 全体で禁止する (canonical: `rules/plain-jp.md`)。template の h2 は上限であって必須構成ではなく、該当しない section は見出しごと削除し空 section・「特になし」を残さない。

| Type | type 別差分ルール | 必須 metadata |
|---|---|---|
| postmortem / investigation | 時系列は絶対時刻 HH:MM + 主語 + 観測事実 (相対表現禁止)。影響範囲は定量化 (ユーザ数 / 期間 / 失敗率 / 金額)。symptom と root cause を分離。障害調査は 5 Why で構造要因まで掘る (`/root-cause` 連携)。再発防止は検証可能 action (担当 / 期限 / 完了条件)、「注意する」不可 | `event-date` |
| report | 数値は出典 + 計測条件を添える (link / query / 期間)。事実 § と解釈 § を混ぜない。推測は「推定」「仮説」と明示。次アクションは誰が何を判断できるかを 1 行で書く | `data-window` |
| plan | 作業フェーズは依存順 + 完了条件付き。リスクは発生確率 + 影響 + 回避策セット | — |
| decision | 比較軸は選択肢間で同一軸に揃える。採用 / 不採用は trade-off を明示し「何を捨てたか」を残す | — |

## Related

- local-docs `CLAUDE.md` / `STRUCTURE.md`: canonical type / aggregation mapping / Title Rules / Metadata / placement flow / html 形式 (primary source)。`guidelines/writing/long-form-doc.md`: 本文書き出し前の必須 guideline + 文体規範。`local-docs-cleanup` skill: released project の archive 移動は委譲する
