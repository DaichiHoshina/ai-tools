---
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Task, mcp__serena__*, mcp__context7__*, mcp__confluence__*, mcp__jira__*
description: PRD作成 - 対話式で要件整理、数学的定式化（オプション）、10の専門家視点で厳格レビュー
---

# /prd - 要件定義・PRD作成コマンド

複雑な要件を整理し、あらゆる角度から抜け漏れを検出する。

## 実行フロー

### Phase 1: 情報収集（対話式・スキップ禁止）

**autoモードでもスキップ不可。必ずAskUserQuestionで対話する。**

| Step | AskUserQuestion | 選択肢例 |
|------|----------------|----------|
| 1 | 何を実現したいですか？ | 新規機能 / 既存改善 / 不具合修正 |
| 2 | どのサービスが関係？ | （コードベースから自動検出） |
| 3 | 外部API・依存は？ | あり / なし / 不明 |
| 4 | 主な利用者は？ | エンドユーザー / 管理者 / 開発者 |
| 5 | 主要フローを教えてください | （自由入力） |

### Phase 1.5: 数学的定式化（複雑な要件の場合）

AskUserQuestion → 「はい」の場合: 用語集、エンティティ、状態遷移表（現状態→イベント→次状態→Guard→pre/post→不変条件）、操作の合成、例外・境界条件、DDDマッピングを定式化。

### Phase 2: PRD自動生成

概要、ユーザーストーリー、サービス依存関係（Mermaid図）、外部API仕様、状態遷移、受け入れ基準。`guidelines/common/user-voice.md` の4問・原則5点を参照し文章品質を担保する。

### Phase 3: 多角的レビュー（11ペルソナ）

| ID | チェック | ID | チェック |
|----|---------|-----|---------|
| SEC | 認証、暗号化、インジェクション | UX | エラー表示、待機UI |
| PERF | N+1、ボトルネック、キャッシュ | DATA | 履歴、監査ログ、整合性 |
| SRE | SPOF、障害検知、ロールバック | BIZ | ROI、優先度、MVP |
| QA | エッジケース、境界値 | LEGAL | 個人情報、保持期間 |
| ARCH | 依存関係、拡張性 | EXT | フォールバック、リトライ |
| CUST | 顧客価値、WTP、体験ジャーニー、代替手段との比較 | — | — |

CUST は UX（操作性）と BIZ（事業 ROI）の中間。「ユーザーは本当にこの機能に対価を払うか／既存代替（Excel・他社・自前）から乗り換えるか」を問う観点。

レビュー手法: MECE、状態遷移完全性、条件分岐網羅、矛盾検出、反証質問

### Phase 4: 指摘一覧出力

Critical（必須対応）/ Warning（推奨対応）/ Info（検討推奨）

### Phase 4.5: writing 観点の self-review（chat 出力直前）

`/prd` は chat 出力で、ファイル化していないため `/review` の git diff 対象にならない。AI が出力直前に、生成済み draft 本文に対して以下を自己検査する:

- `skills/comprehensive-review/SKILL.md` の writing 観点 NG 表（結論先行・根拠なき評価語・抽象語放置・難語未定義・主語省略・5W1H 欠落・箇条書き金太郎飴・AI 定型語・読後アクション未明示）
- `guidelines/common/user-voice.md` の NG 辞書

Critical 1件以上、または Warning 4件以上ヒット → 該当箇所を修正してから Phase 5 に渡す（最大2 loop）。修正は推測せず、4問（読み手・読後アクション・数字・なぜ）の答えを本文に織り込む方向で行う。

`--out <path>` オプションで PRD をファイル化した場合は、`/design-doc` の Step 8.5 と同等に `Read` + `Edit` の書き直し loop を使う。

### Phase 5: 修正・承認

AskUserQuestion → 修正 or 承認 → `/design-doc`（チーム共有用設計資料） or `/plan` or `/dev`

## 出力テンプレート

```markdown
# PRD: [機能名]
## 1. 概要（目的/背景/スコープ）
## 2. ユーザー（ターゲット/ストーリー/権限）
## 3. システム構成（依存関係/データフロー/外部API）
## 4. 機能要件（状態遷移/ビジネスルール）
## 4.5 定式化（複雑時のみ）
## 5. 非機能要件
## 6. 受け入れ基準
## 7. レビュー結果
## 8. 次のアクション
```

**読み取り専用**: 実装はしない。外部APIはWebFetchで取得。反復可能。

ARGUMENTS: $ARGUMENTS
