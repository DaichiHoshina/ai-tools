---
name: パフォーマンス改善issueテンプレート
description: パフォーマンス改善issueの計測→pprof分析→段階的改善→負荷試験の進め方。
type: reference
---

# パフォーマンス改善 issue の進め方テンプレート

issue に何を残すかのテンプレート。Go `pprof` 例だが計測→分析→段階改善→負荷試験のフローは言語非依存。

## Phase 1: 検討・情報収集

issue コメントに検討資料・過去の関連負荷試験記録・手法検討スレッドの URL を貼る。

```markdown
検討資料: {設計メモ・ドラフト URL}
過去の関連負荷試験記録: {Datadog Notebook / Grafana / 内部 wiki}
手法検討スレッド: {チャット URL}
```

ポイント: 過去の類似試験を必ず探す / 検討段階情報も issue に集約。

## Phase 2: ベンチマーク基盤の整備

着手前に計測環境を整備し、issue に実行方法を記載。

```markdown
## ベンチマーク実行コマンド
{コマンド}

### プロファイル取得
{cpuprofile / blockprofile / trace 付きコマンド}

## ベンチマークコード
#{関連 PR 番号} の変更を適用したコードを使用。

### 見方の注意
{何を計測しているか / ローカル計測 / 絶対値でなく相対比較}
```

ポイント: 計測条件・前提明記（並列数、delay、マシン）/ 「何の数値か」を必ず説明 / 再現可能なコマンド。

## Phase 3: 改善前の状態を記録

```markdown
## 改善実施前のベンチマーク
{結果}
- 生ログ: [bench-00-before-improvement.log](添付)

### 状況整理
#### 全体所感
- {主要ボトルネック}
#### {条件別}分析
- {条件A}: {観察結果}
```

ポイント: 生ログは添付（本文は結果行のみ）/ 数値だけでなく所感・分析必須。

## Phase 4: pprof 分析（Go 例）

他言語は同等プロファイラに読替（Python: cProfile / Node: --prof / Ruby: stackprof）。

### 取得コマンド

```bash
go test -tags serial \
  -bench={ベンチ名} -benchmem -benchtime=1x \
  -cpuprofile /tmp/{name}.cpu.pprof \
  -blockprofile /tmp/{name}.block.pprof \
  -trace /tmp/{name}.trace \
  -run='^$' ./{パッケージ}/
```

### 分析コマンド

```bash
go tool pprof -top -cum {file}.cpu.pprof    # cumulative（呼出元込）
go tool pprof -top -flat {file}.cpu.pprof   # flat（自身の消費）
go tool pprof -top {file}.block.pprof       # goroutine ブロック
```

### 判断基準

| CPU サンプル率 | 意味 | 次アクション |
|---|---|---|
| 高い >20% | CPU bound | アプリ最適化（アルゴリズム改善） |
| 低い <10% | I/O bound | DB round-trip 削減、バルク化、クエリ最適化 |

| flat top 上位 | 意味 |
|---|---|
| syscall / runtime | DB I/O 待ち中心、CPU 最適化余地なし |
| アプリコード関数 | ホットスポット、改善対象 |

### コメント形式

```markdown
## プロファイル分析（{方式名} {規模}）

### 計測条件
- ベンチマーク: `{name}`
- 結果: `{時間} / {メモリ} / {allocs}`
- マシン: {CPU} / Docker DB {バージョン}

<details><summary>CPU Profile</summary>{flat top + cumulative + 所見}</details>
<details><summary>Block Profile</summary>{待ち時間内訳 + 所見}</details>

### 結論
{CPU/I/O bound 判定、ボトルネック特定、次アクション}
```

ポイント: **改善前後で2回取得**（前で主犯特定→後で残課題）/ `<details>` で折りたたむ / AI 分析時はプロンプトも記載 / 次アクションを1行で宣言。

## Phase 5: 段階的改善と計測

**1 改善 = 1 コメント**で記録。小さく分割、各段階で効果計測。

```markdown
## {改善カテゴリ}
- [x] {対象1}
- [ ] {未着手}

### 1st: {具体的な改善内容}
{結果}
{分析（前回比較、条件別変化、副次影響）}
生ログ: [bench-01-{改善名}.log](添付)

### 2nd: {次の改善}
{同様フォーマット}

## 所感
{ここまでの成果と次の判断}
```

ポイント: 改善は一気にやらず1つずつ計測 / 各段階で効果有無を明記 / 別 issue 送り判断も所感に。

## Phase 6: スコープ判断・設計ドキュメント

```markdown
{施策名}について整理。
- {別 issue との関係}
- {後方互換性}
- {現改修でのカバー範囲}

{スコープ判断結論}

<details><summary>DesignDoc 素案</summary>
### {設計名}
{テーブル設計・クエリ設計・互換性}
#### 採用しなかった案
- {却下案と理由}
</details>
```

ポイント: 「今やること」「次 issue 送り」を明確分離 / 将来設計提案も DesignDoc 素案として残す / 判断根拠を書く。

## Phase 7: 負荷試験

```markdown
## 負荷試験結果
{Datadog Notebook / Grafana URL}
```

ポイント: 結果はモニタリングツールに記録、issue はリンクのみ / ローカルベンチとは別に開発環境等で実施。

## Phase 8: リリースタスク

```markdown
## リリースタスク
- DesignDoc: [ ] 記述 {URL} / [ ] レビュー
- Backend: [ ] {タスク1}（{見積}）#{PR} / [ ] レビュー
- Frontend: [ ] {タスク}（{見積}）#{PR} / [ ] レビュー
- テスト: [ ] 開発環境
- リリース: [ ] Backend / [ ] Frontend

### 備考
- DB スキーマ変更: {あり/なし}
- 後方互換性: {対応内容}
```

ポイント: 各タスクに PR 番号紐付 / 見積記載 / レビューもチェック項目化 / 備考でスキーマ変更・後方互換明記。
