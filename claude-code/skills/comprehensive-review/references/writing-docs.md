# writing観点 - ヒト向けドキュメント文章品質

## 対象ファイル

md（Design Doc、README、ADR、調査レポート）、Notion投稿下書き、PR description、PRD。コード・コードコメントは対象外（コードは `readability` focus で扱う）。

## チェック項目

NG辞書の **single source of truth** は `claude-code/lib/writing-self-check.sh` の `_WRITING_NG_EVAL`（評価語）/ `_WRITING_NG_STOCK`（定型語）配列。本表の例示と乖離があれば lib/ 側を正とする。

| チェック | NG 例 | 重み |
|---------|-------|------|
| **結論先行** | 「本稿では〜について説明します」導入、数段落後に結論 | Warning |
| **根拠なき評価語** | `_WRITING_NG_EVAL` 配列の語（「適切な」「最適な」「重要」「必須」「推奨」「最優先」「強化する」「向上させる」）を根拠1文なしで使用 | Critical |
| **抽象語の放置** | 「改善」「最適化」「効率化」「強化」に数字 or 事例が隣接していない | Critical |
| **難語の未定義** | 初出の idempotency / Saga / RLS / CQRS 等を定義併記なしで使用 | Warning |
| **主語の省略** | 誰が・何がが不明な文（「対応しました」「実施する」） | Warning |
| **5W1H 欠落** | When / Where / Who が不明な決定記述 | Warning |
| **箇条書き金太郎飴** | 3項目以上の bullet の前後に地の文が1文もない | Warning |
| **AI 定型語** | `_WRITING_NG_STOCK` 配列の語（「効果的に」「効率的に」「シームレスに」「革新的な」「を実現します」「を可能にします」）等 | Warning |
| **読後アクション未明示** | 末尾に「レビュワーは X を確認」「次は Y を実行」が無い | Warning |

## 判定基準

- **Critical**: 1箇所でもあれば書き直し必須
- **Warning**: 3箇所以下なら修正推奨、4箇所以上で書き直し必須

## 出力例

```
🔴 Critical: [writing] 根拠なき「必須」使用（docs/design/oripa.md:45）
修正案: 「SET LOCAL 必須」→ 「SET LOCAL 必須。session-scoped の SET は connection pool で次 request に tenant が漏洩するため」
```
