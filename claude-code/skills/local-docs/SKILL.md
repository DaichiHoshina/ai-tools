---
name: local-docs
description: local-docs リポジトリの doc をテンプレ準拠で新規作成・更新する。「local-docs に doc 作って」「ナレッジ書いて」「runbook/RCA を local-docs に」等の指示時に使用。Use when creating or updating HTML docs in the local-docs knowledge base.
---

# local-docs

local-docs (AI 支援作業のローカルナレッジベース) に doc を作る / 更新する。**テンプレ準拠が必須**。固有の規約 (正規 type / 集約マッピング / 置き場) は local-docs 側の `CLAUDE.md` と `STRUCTURE.md` を**一次情報源**として読む。この skill 本体には type 一覧を複製しない (No Derived Literals)。

## 起動

```
/local-docs new {type} {topic}        # 新規作成
/local-docs update {path}             # 既存 doc を内容更新
/local-docs update {path} --reformat  # 既存 doc をテンプレ準拠へ整形
```

サブコマンド省略時は文脈から `new` / `update` を判定する。

## 前提読み込み (毎回)

1. local-docs repo を特定する (`cd` 先 or 引数 path の repo root)。
2. `CLAUDE.md` の「Templates」と `STRUCTURE.md` の「html 形式」「type enum」「置き場フロー」を読む。
3. 正規 type と集約マッピングは**そこから取得**する。skill 内の記憶で代用しない。

## `new {type} {topic}` — 新規作成

### 1. 生成
1. **type 判定**: topic から type を決め、揺れ呼称は CLAUDE.md のマッピングで正規 type に集約する。
2. **置き場判定**: STRUCTURE.md の配置フローに従い保存先ディレクトリを決める。
3. **テンプレ複製**: `cp _templates/{type}.html {置き場}/{name}.html`。
4. **中身を埋める**: 骨格 h2・`<style>`・`<script>` は**そのまま使う**。`{...}` placeholder だけ差し替える。骨格 h2 は原則維持 (doc 固有の追加 h2 は可)。
5. **metadata**: 冒頭コメント `type` を正規値に、`status` を実態に直す。`last-updated` は書かない (廃止規約)。
6. **title**: STRUCTURE.md の Title Rules に従い短く、親コンテキストの繰り返しを避ける。

### 2. 磨き
- `/jp-writing` 相当の self-check で AI 臭・冗長表現を排除する。HTML 本文の日本語を読みやすく直す。

### 3. 検証
- textlint (HTML 前処理が要る場合は本文抽出してから) を通す。
- `node _index/build.mjs` で index を再生成し exit 0 を確認する。
- ブラウザで開いて装飾崩れがないか確認するよう案内する。

## `update {path}` — 既存 doc 更新

mode を判定する: `--reformat` 明示時、または旧構造 (手書き toc / tldr / `local-docs-decorate` 不在 / 旧 style) を検出した時は reformat を提案する。それ以外はデフォルト (内容更新)。

### デフォルト: 内容更新
1. 既存 doc を読み、本文を追記 / 書き換える。
2. 骨格・style・script は触らない (テンプレ準拠が崩れていなければ維持)。
3. 磨き → 検証 (上記と同じ)。

### `--reformat`: テンプレ準拠化
1. doc の type を判定 (冒頭 metadata or 内容から)。揺れは正規 type に集約する。
2. 最新 `_templates/{type}.html` の骨格 h2・`<style>`・`<script>` (decorate v4.1) に揃える。
3. 旧構造 (手書き toc / tldr / 旧 style) を撤去する。**本文は保持**する。
4. metadata を必須セット (`type` / `status`) に直す。`last-updated` があれば削除する。
5. 検証 (上記と同じ)。

## 制約

- **public-repo**: この skill は public 管理。固有名 (社内サービス名 / 識別子) を skill 本体に書かない。固有情報は local-docs 側 `CLAUDE.md` を参照させる。
- **`.md` 新規作成は禁止**。新規 doc は必ず `_templates/{type}.html` 由来の `.html`。root meta 5 ファイルと既存 `.md` はそのまま維持する。
- **テンプレの style / script を改変しない**。doc 側は中身だけ埋める。

## 関連

- local-docs `CLAUDE.md` — 正規 type / 集約マッピング (一次情報)
- local-docs `STRUCTURE.md` — 置き場フロー / type enum / Title Rules
- local-docs `_templates/README.html` — テンプレ一覧と使い方
