# 設計フェーズ遷移と各コマンドの役割

要件整理から実装・蓄積までの 6 コマンドの位置付けと遷移を整理する。

## 遷移図

```
[アイデア]
   │
   ├─(1) 設計が不明確 ──→ /brainstorm（Superpowers、対話的精緻化）
   │                          │
   ▼                          ▼
[要件が見える] ←──────────────┘
   │
   └─(2) 要件整理 ──→ /prd（11ペルソナレビュー、Q1-Q5 意思決定）
                         │
                         ▼
                  [PRD 確定（chat or md）]
                         │
   ┌─────────────────────┤
   │                     ▼
   │  (3) 設計書化 ──→ /design-doc（チーム共有用 12セクション md）
   │                     │
   │                     ▼
   │              [Design Doc（docs/design/*.md）]
   │                     │
   ▼                     │
(4) 実装計画 ──→ /plan（PO Agent、Phase 分割、~/.claude/plans/）
                         │
                         ▼
                  (5) 実装 ──→ /dev または /flow
                                    │
                                    ▼
                            [動作確認・PR]
                                    │
                                    ▼
                  (6) ナレッジ蓄積 ──→ /docs（Notion 投稿）
```

## 各コマンドの責務

| # | コマンド | 入力 | 出力 | フェーズ |
|---|---------|------|------|---------|
| 1 | `/brainstorm` | 漠然とした課題 | chat（精緻化された要件） | 発散・対話 |
| 2 | `/prd` | 要件 | chat or `--out` で md | 要件定義 |
| 3 | `/design-doc` | PRD（`--prd`）or 自然言語 | `docs/design/<slug>.md` | 設計 |
| 4 | `/plan` | Design Doc or 設計済前提 | chat or `~/.claude/plans/*.md` | 実装計画 |
| 5 | `/dev` `/flow` | Plan or タスク | コード変更 | 実装 |
| 6 | `/docs` | git diff or `--from <md>` | Notion ページ | 完了後蓄積 |

## 使い分けの判断軸

| 状況 | 推奨スタート地点 |
|------|---------------|
| 要件・設計とも不明確 | `/brainstorm` |
| 要件はあるが整理されていない | `/prd` |
| PRD 済、設計を起こす | `/design-doc --prd <path>` |
| 設計済、実装の Phase 分けが要る | `/plan` |
| 設計・計画済、即実装 | `/dev` または `/flow` |
| 実装完了、ナレッジを残す | `/docs` |

## スキップ判断

- **PRD 不要**: 1ファイル/数十行の修正、バグ修正は `/prd` をスキップして `/dev`
- **Design Doc 不要**: 単一サービス内の機能追加は `/plan` 直行
- **Plan 不要**: 設計が単純で `/dev` 一発で書ける場合

## Q1-Q5 継承

`/prd` で確定した「1.5 意思決定根拠（Q1-Q5）」は `/design-doc --prd <path>` で **転記し再評価せず**、設計起因で前提が変わる Q のみ追記する。

## /plan と /design-doc の境界

| 観点 | `/design-doc` | `/plan` |
|------|--------------|---------|
| 主目的 | チームに **設計判断** を伝える | 実装の **Phase 分け** を決める |
| 出力 | 12 セクション md（Why/比較/失敗ケース/移行戦略） | Phase 1/2/... と Worktree 要否 |
| 入力 | PRD or 自然言語 | Design Doc or 設計済前提 |
| 対象読者 | レビュワー・PM・将来の自分 | 実装者（自分 or developer-agent） |
| 連携 Agent | なし（直接 Edit） | PO Agent（複雑時） |

両方必要なケース: 大型機能。`/design-doc` で「設計を伝える」→ `/plan` で「実装手順に落とす」。
小型修正は `/plan` のみで十分なことが多い。

## 関連

- `design-doc-writing-guide.md` — DesignDoc 書き方の実践ノウハウ（原則・アンチパターン・セルフチェック）
- `design-doc-scope-guide.md` — テンプレ選択・粒度・行数目安
- `design-doc-template.md` — 12 セクションのフルテンプレート
- `prd-review-checkpoints.md` — PRD レビューで人間が集中すべき観点
- `decision-quality-checklist.md` — 意思決定品質の 5 問チェック
- `performance-issue-template.md` — パフォーマンス改善 issue の計測→分析→段階改善→負荷試験
- `review-patterns-universal.md` — 設計判断・SQL 方言で頻出するレビュー指摘
