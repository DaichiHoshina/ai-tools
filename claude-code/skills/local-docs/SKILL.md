---
allowed-tools: Bash, Read, Edit
name: local-docs
description: local-docs 配下に HTML doc を作成・更新し、type 別 (postmortem / report / rca 等) の本文品質ルールを適用する。「postmortem」「報告資料」「検証レポート」「RCA」「調査ログ」等で起動する。Use when creating or updating HTML docs in the local-docs knowledge base.
---

# local-docs

`~/ghq/<repo>/local-docs/` 配下に HTML 形式の doc を作成 / 更新する専用 skill。**template compliance 必須**、type 別に本文品質 rule を強制する。canonical (type enum / 集約呼称 / placement) は local-docs 側の `CLAUDE.md` と `STRUCTURE.md` を毎回 Read する (No Derived Literals、cache 禁止)。

---

## ⛔ 禁止事項 (rule 違反 = 即 abort)

| Rule | 理由 |
|---|---|
| skill 起動なしで `local-docs/` 配下に HTML を書く | 過去 incident: inline `<style>` で共有 CSS 破壊 |
| `Write` で HTML 直書き | skeleton / `<style>` / `<script>` を上書きして壊す |
| `.md` で新規 doc 作成 | 全 doc は `_templates/{type}.html` から `cp` する |
| `<style id="local-docs-style">` / `<script id="local-docs-script">` の変更 | 共有 infrastructure、decorate v4.2 / TOC / hero / num badge が破綻 |
| skill file (本 file) 自体に社名 / product 名を書く | public repo 制約。proprietary 情報は local-docs 側 `CLAUDE.md` に置く |

---

## 起動 trigger

skill は **明示 invoke なしでも auto activate** する。以下いずれかを満たすと起動する。

| 種別 | trigger |
|---|---|
| user 発話 | 「local-docs」「ナレッジ」「runbook」「RCA」「postmortem」「報告資料」「検証レポート」「spec」「調査ログ」「監視結果」「post-release」「dashboard 確認」「5xx 分析」「インシデント記録」「試験結果」「session 跨ぎ」「試行錯誤メモ」 |
| 出力先 path | `local-docs/{projects,domain-specs,tool-guides,operations}/` 配下 |
| 拡張子 | 上記 path 下の `.html` |

---

## Subcommand

| Command | 用途 |
|---|---|
| `/local-docs new {type} {topic}` | 新規作成 |
| `/local-docs update {path}` | 既存 doc の追記 / 書き直し |
| `/local-docs update {path} --reformat` | skeleton を最新 template に整合 |
| (省略) | 文脈から `new` / `update` を推定 |

---

## Prerequisites (毎回 Read、cache 禁止)

1. `cd` target or argument path から local-docs repo root を特定する
2. `CLAUDE.md` §Templates を Read する
3. `STRUCTURE.md` §html-format / §type-enum / §placement-flow を Read する
4. canonical type / aggregation mapping は上記 file から取得する (skill 内 cache 使わない)

---

## Flow: `new {type} {topic}`

### Step 1. Type / Placement 決定

| 手順 | 内容 | 確認 |
|---|---|---|
| 1-1 | topic から type を判定、variant は `CLAUDE.md` mapping で canonical 化する | canonical type enum に含まれているか |
| 1-2 | `STRUCTURE.md` placement flow に従って出力 dir を決定する | dir が存在するか、なければ mkdir |

### Step 2. Template 起点で file 作成 (Write 直書き禁止)

```bash
cp _templates/{type}.html {dir}/{name}.html
```

> ✅ **必須**: `cp` で起こしてから `Edit` のみで埋める。`Write` を使うと skeleton / style / script を破壊する。

### Step 3. 本文 guideline Read (必須、書き出し前)

`guidelines/writing/long-form-doc.md` を Read する (canonical: `guidelines/writing/README.md`)。未読で書き出すと readability 崩壊 → retry を招く。

### Step 4. 本文を埋める (Edit only)

| 対象 | 操作 |
|---|---|
| `{...}` placeholder | `Edit` で置換 |
| skeleton h2 / `<style>` / `<script>` | 保持 (触らない) |

書き出し時点で守る: 1 文 100 字以内 / 結論先行 (PREP) / 段落 3〜4 行 / 指示語は具体名 / NG 語回避 (`guidelines/writing/NG-DICTIONARY.md`)。

### Step 5. Metadata 設定

| Field | 値 |
|---|---|
| `<!-- type: ... -->` | canonical type |
| `<!-- status: ... -->` | canonical status |
| `<!-- last-updated: ... -->` | **書かない** (deprecated) |
| title (`<h1>`) | 短く、親 context の repeat 禁止 (`STRUCTURE.md` Title Rules) |

### Step 6. Self-check (生成直後)

先頭 2 行が `<!-- type: -->` `<!-- status: -->` / `<style id="local-docs-style">` 存在 / `<script id="local-docs-script">` 存在。1 つでも欠けたら template 再 `cp` からやり直す。

### Step 7. Polish & Verify (skip 禁止)

| 手順 | 内容 |
|---|---|
| 7-1 | §Type-specific authoring の type 別品質 check を本文に適用する |
| 7-2 | **`jp-writing` skill を実行** (自己判断で済ませない、skill 本体を起動) |
| 7-3 | 書き直し loop: Critical 1+ or Warning 4+ で `Edit` 書き直し (最大 2 loop、3 loop 残存はユーザー報告) |
| 7-4 | body text に対して textlint を実行する |
| 7-5 | `node _index/build.mjs` を実行、exit 0 を確認する (非 0 なら fix してから進む) |
| 7-6 | ユーザーに browser で開いて layout 破壊なしを確認するよう依頼する |

> 📎 合格ライン canonical: `guidelines/writing/long-form-doc.md` §品質検証タイミング

---

## Flow: `update {path}`

### Mode 判定

| 条件 | Mode |
|---|---|
| `--reformat` 明示 | **reformat** |
| legacy 構造検出 (manual toc / tldr / `local-docs-decorate` 欠落 / 旧 inline style) | **reformat** (user 提案) |
| 上記なし | **default (content-update)** |

### Default mode (content-update)

既存 doc を Read → body を追記 / 書き直し (skeleton / style / script は触らない) → **Step 7 Polish & Verify を必ず通す**。

### Reformat mode

skeleton h2 / `<style>` / `<script>` を最新 `_templates/{type}.html` に整合 → legacy 構造を削除 → body content は保持 → metadata (`type` / `status`) 修正 → `last-updated` があれば削除 → Step 7 で Verify。

---

## Type-specific authoring (本文品質)

template は骨格 h2 を与える。各 h2 を**何の粒度で埋めるか**が doc の価値を決める。type enum / 集約呼称 / h2 列挙の canonical は local-docs `CLAUDE.md` / `_templates/{type}.html` (No Derived Literals)。本節は**埋め方の質**のみ規定する。

### 共通ルール

- 冒頭 lead を結論先行 1〜3 文で書く
- 段落 3〜4 行に抑える
- 指示語は具体名に置換する
- 読者が「何が起きたか / 何が分かったか」を最初の段落で把握できる状態にする

### Type 別品質要件

| Type | 主要ルール | 必須 metadata |
|---|---|---|
| **postmortem / rca** | 時系列 = 絶対時刻 HH:MM + 主語 + 観測事実 (「しばらくして」「その後」等の相対表現禁止)。影響範囲は定量化 (ユーザ数 / 期間 / 失敗率 / 金額)。symptom と root cause を分離。rca は 5 Why で構造要因まで掘る (`/root-cause` 連携)。再発防止は検証可能な action (担当 / 期限 / 完了条件)。「注意する」「気をつける」不可 | `event-date` (障害発生日) |
| **report** | 結論を §1 か冒頭 lead に先出し、根拠を後続 § で支える (PREP)。数値は必ず出典 + 計測条件を添える (clickable link / query / 期間)。解釈 (§4) と事実 (§3) を混ぜない。推測には「推定」「仮説」と明示。次アクション (§5) は誰が何を判断できるかを 1 行で書く | `data-window` |
| **plan** | 作業フェーズは依存順 + 完了条件付き。リスクは発生確率 + 影響 + 回避策をセットで書く | — |
| **decision** | 比較軸 (§3) は選択肢間で同一軸に揃える。採用 / 不採用は trade-off を明示し「何を捨てたか」を残す | — |

外向き共有前提の doc (postmortem / report) は `guidelines/writing/` canonical の文体規範 (1 文 100 字 / NG 語回避 / 指示語禁止) を本文にも適用する。

---

## Related

| Reference | 役割 |
|---|---|
| local-docs `CLAUDE.md` | canonical type / aggregation mapping (primary source) |
| local-docs `STRUCTURE.md` | placement flow / type enum / Title Rules |
| local-docs `_templates/README.html` | template list と usage |
| `guidelines/writing/long-form-doc.md` | 本文書き出し前の必須 guideline |
| `guidelines/writing/README.md` | 文体規範 canonical (1 文 100 字 / NG 語 / 指示語禁止) |
| `guidelines/writing/NG-DICTIONARY.md` | NG 語辞書 (hook block 対象) |
| `/root-cause` skill | postmortem / rca の 5 Why 支援 |
| `jp-writing` skill | Polish & Verify Step 7-2 で必須起動 |
