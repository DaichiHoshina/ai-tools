# Review noise discard (default 厳しめ filter)

`/review` / `/review-fix-push` / `comprehensive-review` skill / `reviewer-agent` の出力は **default で厳しめ filter**。過剰な finding (noise) は user 提示前に discard する。Signal < noise の review 結果は意思決定 cost を増やし net negative。

## Discard 対象 (Stage A 7 観点に加えて適用)

- Confidence <80% の finding — skill 内 confidence-80 filter を厳守、border case は discard 側
- Style nitpick (typo / wording 改善 / 句読点 / heading style 等) — Critical / Warning ではなく Info 以下に降格 or 削除
- Hypothetical edge case (実コードで再現条件未確認) — root cause 系のみ残し、speculation は削除
- "consider also X" 系 (現変更 scope 外の追加提案) — Scope 違反、discard
- Over-prescription (具体的な実装手段まで指示する finding、抽象レベルで足りる場合) — Severity 降格 or 削除
- 同一 root cause 由来の重複 finding — Stage B で 1 つに統合
- Docs-only diff での test coverage / type-design 指摘 — perspective ミスマッチ、discard

## 残す対象 (signal)

- 機能不全 / data loss / security vuln 等の明確な P0/P1
- Cross-ref desync / propagation incompleteness (file 間整合性破壊)
- 明確な evidence + reproducible repro path 持ち
- Severity Critical で actionable な fix path 明示可能なもの

## 適用範囲

- `/review`、`/review-fix-push`、`comprehensive-review` skill (Self-Review Stage A 内で適用)
- `reviewer-agent` (Report 出力前に適用)
- review 系 hook / githook も同等

## 違反時

User 指摘 ("過剰なレビューはスルー" 等) → feedback memory に記録 → 次回より閾値を更に厳しく調整。Compounding Engineering サイクルで根治。
