---
name: comprehensive-review
description: 包括的コードレビュー - 設計・品質・可読性・セキュリティ・ドキュメント・テスト充足度・恒久対応・ログを統合評価。/reviewコマンドで自動選択。--focusで観点を絞れる。
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design]
    default: all
    description: レビュー観点のフォーカス
---

# comprehensive-review - 包括的コードレビュー

## 11の観点

1. **architecture** - クリーンアーキテクチャ、DDD、レイヤー違反
2. **quality** - コード臭、パフォーマンス、型安全性
3. **readability** - 命名、認知的複雑度、一貫性
4. **security** - OWASP Top 10、機密情報漏洩
5. **docs** - ドキュメント品質（テストファイル等の補助ドキュメント）
6. **test-coverage** - テストケースの充足度
7. **root-cause** - 対症療法vs根本治療
8. **logging** - ログレベル適切性、構造化ログ
9. **writing** - ヒト向けドキュメント（md / Notion / PR description / PRD / Design Doc）の文章品質
10. **silent-failure** - エラー握りつぶし、空 catch、不適切なフォールバック
11. **type-design** - 型による不変条件表現、enum乱用回避、Optional/Result設計

## パラメータ

`--focus`で観点を絞る（デフォルト: all）:

| 値 | レビュー範囲 |
|----|-------------|
| all | 全11観点（デフォルト） |
| architecture | 設計のみ |
| quality | 品質のみ |
| readability | 可読性のみ |
| security | セキュリティのみ |
| docs | ドキュメントのみ |
| test-coverage | テスト充足度のみ |
| root-cause | 恒久対応のみ |
| logging | ログのみ |
| writing | ヒト向けドキュメントの文章品質のみ |
| silent-failure | エラー握りつぶし検出のみ |
| type-design | 型設計のみ |

## Effort 連動モード（`${CLAUDE_EFFORT}`）

実行時の effort level（`${CLAUDE_EFFORT}`）で挙動を変える。Claude Code 2.1.120+ で `${CLAUDE_EFFORT}` は `low` / `medium` / `high` のいずれかに展開される。

| effort | Critical 信頼度閾値 | 履歴クロスチェック | 観点制御 |
|--------|---------------------|-------------------|---------|
| `low` | 90+（false positive 極小化） | スキップ | writing / type-design / docs を省略 |
| `medium`（既定） | 80+ | 過去 90 日 | 全 11 観点 |
| `high` | 70+（過検出寄り） | 全履歴 | + 設計トレードオフ・前提依存の問い詰め（adversarial 視点） |

`${CLAUDE_EFFORT}` が未展開（環境変数なし）の場合は `medium` 扱い。Step 4.5 の信頼度フィルタリング、Step 0 の履歴ロード範囲、Step 4 の観点選択でこの値を参照する。

## 実行フロー

### Step 0: 履歴ロード（繰り返し指摘の検出）

リポジトリの `.claude/review-history.jsonl` を読み、過去の指摘を memory として保持。

```bash
HISTORY_FILE="$(git rev-parse --show-toplevel)/.claude/review-history.jsonl"
if [ -f "$HISTORY_FILE" ]; then
    # 過去90日分のみ採用、それ以前は無視
    cutoff=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)
    awk -v c="$cutoff" -F'"date":"' '$2 >= c' "$HISTORY_FILE"
fi
```

**繰り返し検出規則**: 同一 `file:line±3行` + 同一 `focus` の指摘が **過去履歴に3回以上** ある場合、最終出力で `🔁 繰り返し指摘（Nth時）: ...` と prefix。チームレベルの問題（言語仕様・設計方針）の可能性示唆。

ファイル不在時はスキップ（初回実行扱い）。

### Step 1: 変更ファイル分析

`git diff --name-only`で言語・ファイル種別・変更規模を判断。

### Step 2: 静的解析ツール実行（必須）

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50
```

### Step 3: cleanup-enforcement確認

未使用import/変数/関数、後方互換残骸、進捗コメントを確認。

### Step 4: レビュー観点の選択と実行

focusパラメータで指定された観点のみ実行。`all`の場合は全11観点を並列実行。

**test-coverage観点のチェック項目**:

| チェック | 内容 |
|---------|------|
| **テスト有無** | 変更したロジックに対応するテストファイルが存在するか |
| **新規コードのテスト** | 新しい関数・メソッド・エンドポイントにテストがあるか |
| **バグ修正の回帰テスト** | 修正したバグの再発を防ぐテストケースがあるか |
| **境界値・異常系** | 正常系だけでなくエラーケース・境界値がカバーされているか |
| **テストの質** | テストが実装の詳細でなく振る舞いを検証しているか |

**writing観点のチェック項目**（`guidelines/common/user-voice.md` 準拠）:

対象ファイル: md（Design Doc、README、ADR、調査レポート）、Notion 投稿下書き、PR description、PRD。コード・コードコメントは対象外（コードは `readability` focus で扱う）。

NG 辞書の **single source of truth** は `claude-code/lib/writing-self-check.sh` の `_WRITING_NG_EVAL`（評価語）/ `_WRITING_NG_STOCK`（定型語）配列。本表の例示と乖離があれば lib/ 側を正とする。

| チェック | NG 例 | Critical / Warning |
|---------|-------|-------------------|
| **結論先行** | 「本稿では〜について説明します」導入、数段落後に結論 | Warning |
| **根拠なき評価語** | `_WRITING_NG_EVAL` 配列の語（「適切な」「最適な」「重要」「必須」「推奨」「最優先」「強化する」「向上させる」）を根拠1文なしで使用 | Critical（1箇所でもあれば） |
| **抽象語の放置** | 「改善」「最適化」「効率化」「強化」に数字 or 事例が隣接していない | Critical |
| **難語の未定義** | 初出の idempotency / Saga / RLS / CQRS 等を定義併記なしで使用 | Warning |
| **主語の省略** | 誰が・何がが不明な文（「対応しました」「実施する」） | Warning |
| **5W1H 欠落** | When / Where / Who が不明な決定記述 | Warning |
| **箇条書き金太郎飴** | 3項目以上の bullet の前後に地の文が1文もない | Warning |
| **AI 定型語** | `_WRITING_NG_STOCK` 配列の語（「効果的に」「効率的に」「シームレスに」「革新的な」「を実現します」「を可能にします」）等 | Warning |
| **読後アクション未明示** | 末尾に「レビュワーは X を確認」「次は Y を実行」が無い | Warning |

**Critical / Warning の扱い**:
- Critical: 1箇所でもあれば書き直し必須
- Warning: 3箇所以下なら修正推奨、4箇所以上で書き直し必須

**出力例**:
```
🔴 Critical: [writing] 根拠なき「必須」使用（docs/design/oripa.md:45）
修正案: 「SET LOCAL 必須」→ 「SET LOCAL 必須。session-scoped の SET は connection pool で次 request に tenant が漏洩するため」
```

**silent-failure観点のチェック項目**:

| チェック | NG例 | 重み |
|---------|------|------|
| **空 catch / except** | `catch (e) {}` / `except: pass` | Critical |
| **err 握りつぶし** | Go の `_ = err` / `if err != nil { return nil }`（ログなし） | Critical |
| **広域 catch + ログのみ** | 例外を全捕獲してログだけ書いて握る | Critical |
| **不適切フォールバック** | API失敗時に空配列返却で正常系扱い | Critical |
| **Promise.catch 未処理** | `.catch(() => {})` / unhandled rejection | Critical |
| **boolean 戻り値で失敗隠蔽** | `success bool` 返却のみで原因不明 | Warning |
| **エラーの型情報喪失** | `throw new Error(String(e))` で stack trace 喪失 | Warning |
| **デフォルト値で例外回避** | `parseInt(x) || 0`（NaN握りつぶし） | Warning |

**type-design観点のチェック項目**:

| チェック | NG例 | 重み |
|---------|------|------|
| **string で状態表現** | `status: string`（"pending"/"done" 等が文字列） | Warning |
| **boolean フラグ乱用** | `isActive`/`isDeleted`/`isArchived` 並列（状態爆発） | Warning |
| **null/undefined 多用** | Optional 型/Maybe 型未使用、`T \| null \| undefined` | Warning |
| **不変条件の型未表現** | 「正の数」を `number` のまま、Branded type 未使用 | Warning |
| **巨大 union 型** | 10要素以上の string literal union（discriminated union 化推奨） | Warning |
| **Result/Either 未使用** | エラー戻り値を例外で返す（型シグネチャに失敗が現れない） | Warning |
| **primitive 過信** | UserId/OrderId 等を `string` のまま（取り違え可能） | Critical（金融/PII系） |
| **可変オブジェクト共有** | readonly/Immutable 未指定の API レスポンス型 | Warning |

**ファイル種別による自動追加**:

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs` |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |
| ロジック変更（テストファイル以外の`.go`, `.ts`, `.py`） | `test-coverage` + `silent-failure` |
| 型定義変更（`*.d.ts`, `types/*`, struct/interface追加） | `type-design` |
| MySQL bulk INSERT（`.go`/`.sql` で `INSERT INTO` 含む変更） | `bulk-insert-correctness` |

**bulk-insert-correctness 観点のチェック項目**（[backend/mysql-performance.md §12](../../guidelines/backend/mysql-performance.md) 準拠）:

| チェック | NG | 重み |
|---------|----|------|
| **`INSERT ... SELECT` 共存** | `lastInsertID + i` 採番関数と同テーブルへの `INSERT ... SELECT` を行う他関数が同 transaction / 同サービスに追加される | Critical |
| **`ON DUPLICATE KEY UPDATE` 付き bulk** | multi-row VALUES + `ON DUPLICATE KEY UPDATE` で `LastInsertId() + i` 採番 | Critical |
| **混合モード挿入** | id 列の一部明示・一部 NULL/省略の VALUES に対する `LastInsertId()` 利用 | Critical |
| **動的行数 INSERT** | `placeholders` と `values` の長さが ループ条件依存で `len(entities)` と一致保証なし | Warning |
| **migration での同テーブル backfill** | maintenance 外実行で並行 bulk insert を破壊 | Warning |

### Step 4.5: 信頼度スコアリング（必須・ノイズ除去）

各 finding に **0-100 の信頼度スコア** を付与し、低スコア指摘を降格・破棄する。Anthropic 公式 `code-review` プラグインのスコアリング方式に準拠。

**Rubric（各 finding に対し自己採点）**:

| スコア | 判定基準 |
|--------|---------|
| 0-24   | False positive。軽い吟味で否定される、または既存コードの問題（差分外） |
| 25-49  | やや確度低。実問題かもしれないが検証不能。スタイル系で CLAUDE.md 言及なし |
| 50-74  | 中確度。実問題と検証済みだが nitpick または発生頻度低 |
| 75-89  | 高確度。再確認済み・実運用でヒット濃厚、または CLAUDE.md 明示違反 |
| 90-100 | 確実。証拠が直接示す。頻発する実バグ |

**フィルタリング規則**（`${CLAUDE_EFFORT}` で閾値変動。表は medium 既定値）:

| スコア帯 | 扱い |
|---------|------|
| 80以上（low では 90+、high では 70+） | Critical のまま出力 |
| 50-79   | **Warning に降格**（元 Critical でも） |
| 25-49   | Warning のまま出力 |
| 25未満  | **破棄**（出力しない） |

**False positive チェックリスト**（スコア下げ要因）:

- 既存コード（差分外行）の指摘
- linter / typechecker / compiler が拾う指摘（CI で別途検出される）
- 「テスト不足」「ドキュメント不足」の一般論（CLAUDE.md 明示なき限り）
- スタイル nitpick（lint ignore コメント済み箇所など）
- 意図的な機能変更を「変更」として指摘
- senior engineer なら指摘しない過剰な細部

**出力形式に信頼度を含める**:

```text
🔴 Critical: [security] SQLi（src/api/user.ts:120）信頼度95
🟡 Warning:  [quality] sort.Slice → slices.Sort（pkg/sort.go:15）信頼度70
```

### Step 5: 結果集約

### Step 6: 履歴記録

確定した Critical / Warning（信頼度25以上）を `.claude/review-history.jsonl` に追記。

```bash
HISTORY_FILE="$(git rev-parse --show-toplevel)/.claude/review-history.jsonl"
mkdir -p "$(dirname "$HISTORY_FILE")"
# .gitignore 未設定の場合は `.claude/` を gitignore に追記提案（初回のみ）
```

**1指摘あたりの行フォーマット（jsonl、1行 = 1 指摘）**:

```json
{"date":"2026-04-27","severity":"Critical","focus":"security","file":"src/api/user.ts","line":120,"finding":"SQLi","confidence":95,"branch":"feat/x","commit":"abc1234"}
```

書き込み時の注意:
- `severity` は降格後の最終値（信頼度 80未満 Critical → Warning として記録）
- 信頼度25未満（破棄）は記録しない
- `branch` / `commit` は `git rev-parse --abbrev-ref HEAD` / `git rev-parse --short HEAD`
- ファイルが100MB超えたら古い行から削除提案（運用リスク提示のみ、自動削除はしない）

**.gitignore 提案**: 初回 history 記録時、リポジトリの `.gitignore` に `.claude/review-history.jsonl` が無ければユーザーに追記提案（個人作業履歴のため）。

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging / silent-failure / type-design

### Critical（修正必須・信頼度80以上）
- [security] SQLインジェクション脆弱性（src/api/user.ts:120）信頼度95
- 🔁 繰り返し指摘（4th時）: [architecture] Domain→Infrastructure参照（src/domain/user.ts:45）信頼度85

### Warning（要改善・信頼度25-79）
- [quality] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）信頼度65

Total: Critical N件 / Warning N件 / 破棄M件（信頼度25未満） / 🔁 繰り返しK件
```

## コメント添字

レビューコメントには添字を付ける:

| 添字 | 意味 | 対応 |
|------|------|------|
| `must` | 修正必須 | Critical扱い |
| `imo` | 提案（任意） | Warning扱い |
| `nits` | 細かい指摘 | Warning扱い |
| `q` | 質問 | 情報提供 |

## 注意事項

- 大量の差分 → 1ファイルずつ、Critical → Warningの優先度順
- 問題指摘だけでなく具体的な修正案を提示
- focus=allの場合は全11観点を並列実行
