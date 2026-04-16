---
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, AskUserQuestion
description: パフォーマンス改善issueの進行管理（計測→pprof分析→段階的改善→負荷試験）
---

# /performance-issue - パフォーマンス改善フロー

計測→分析→段階的改善→負荷試験の進行管理。issueコメントに作業ログを蓄積しながら段階的に改善する。

## 入力

`$ARGUMENTS` からissue番号またはタスク概要を取得。なければAskUserQuestionで確認。

## フロー

| Phase | やること | 成果物 |
|-------|---------|--------|
| 1. 情報収集 | issue/チケット読み込み、関連リソース探索 | リンク集 |
| 2. ベンチマーク基盤 | 対象コード特定、実行コマンド・プロファイル取得方法を記載 | コマンド+計測条件 |
| 3. 改善前計測 | ベンチマーク実行、生ログ保存 | 結果+ボトルネック分析 |
| 4. pprof分析 | プロファイル取得→分析→次アクション宣言 | CPU/IO判定+改善優先度 |
| 5. 段階的改善 | **1改善=1計測**。before/after比較 | チェックリスト+効果検証 |
| 6. スコープ判断 | 「やる/別チケットに送る」を根拠付きで判断 | 判断+DesignDoc素案 |
| 7. 負荷試験 | dev環境で負荷試験実行 | 結果リンク |
| 8. リリースタスク | DesignDoc/BE/FE/テスト/リリースのチェックリスト | PR番号・見積付き |

## Phase 4: pprof分析（詳細）

### プロファイル取得コマンド（Go）

```bash
go test -tags serial \
  -bench={ベンチマーク名} -benchmem -benchtime=1x \
  -cpuprofile /tmp/{name}.cpu.pprof \
  -blockprofile /tmp/{name}.block.pprof \
  -trace /tmp/{name}.trace \
  -run='^$' ./{package}/
```

### 分析コマンド

```bash
# CPU: どの関数がCPU時間を消費しているか
go tool pprof -top -cum {file}.cpu.pprof
go tool pprof -top -flat {file}.cpu.pprof

# Block: どこでgoroutineがブロックしているか
go tool pprof -top {file}.block.pprof
```

### 判断基準

| CPUサンプル率 | 判定 | 次のアクション |
|-------------|------|--------------|
| 高い（>20%） | CPU bound | アルゴリズム改善、計算量削減 |
| 低い（<10%） | I/O bound | DB round-trip削減、バルク化、クエリ最適化 |

| flat top上位 | 意味 |
|-------------|------|
| syscall/runtime | DB I/O待ち中心。Go側のCPU最適化余地なし |
| アプリコード関数 | その関数がホットスポット。コード改善対象 |

### issueコメント形式

```markdown
## プロファイル分析（{方式名}）

### 計測条件
- ベンチマーク: `{名前}`
- 結果: `{時間} / {メモリ} / {allocs}`
- マシン: {CPU} / {DB環境}

<details>
<summary>CPU Profile 分析</summary>

{flat top表 + cumulative top + 所見}

</details>

<details>
<summary>Block Profile 分析</summary>

{待ち時間の内訳 + 所見}

</details>

### 結論
{CPU bound / I/O bound判定、ボトルネック特定、次のアクション}
```

## 原則

1. **計測ファースト**: 改善前後で必ずベンチマーク
2. **段階的改善**: 1改善ごとに効果確認。一気にやらない
3. **作業ログ集約**: 検討・計測・分析・判断すべてissue/チケットに記録
4. **生データは添付**: 本文は要約+分析、生ログは別ファイル
5. **`<details>`活用**: 長い分析は折りたたみ
6. **スコープ判断を明文化**: 根拠付きで「やる/送る」を宣言

ARGUMENTS: $ARGUMENTS
