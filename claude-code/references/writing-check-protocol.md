# Writing check protocol (canonical)

外向き text を permanent store (file / PR / issue / Notion / commit / MR) に書き出す前に走らせる self-check の共通仕様を集約する。閾値変更時は本 file のみ更新すればよい (drift 防止)。

## 参照元 (5 command)

以下の 5 command が本 protocol を参照する。各 command 側には check 対象の doc 種別のみ残す。

- `commands/design-doc.md` (Step 8.5)
- `commands/docs.md` (Step 4.8)
- `commands/prd.md` (Phase 4.5)
- `commands/post-comment.md` (Step 2.5)
- `commands/git-push.md` (Step 2 / Step 5.5)

## 共通仕様

- **Check 対象**:
  - NG dict: `guidelines/writing/NG-DICTIONARY.md` (AI 定型語 / 要根拠語 / 難読漢語 / 非日常英語)
  - Writing axis: `guidelines/writing/PRINCIPLES.md` (体言止め / 助詞省略 / 主語省略 / 1 文長 / 抽象語放置 等)
- **Severity 判定**: hit を Critical (must fix) / Warning (recommended) / Info (consider) に分類する。分類基準は NG dict / PRINCIPLES 各項目のラベルに従う。
- **Rewrite 発動閾値**: Critical ≥1 or Warning ≥4 でその draft を rewrite する。閾値未満なら pass。
- **Loop 上限**: rewrite → re-check を max 2 loops まで実施する。2 loop 後も残存すれば user に残存違反と loop limit reason (info gap / decision pending 等) を提示して続行確認する。
- **File 永続化時**: `Read` で書き出した内容を再取得し、`Edit` で該当箇所のみ差分修正する (全文書き直ししない)。
- **Chat / stdin draft 時**: 生成 text を直接 self-check し、rewrite 済 draft を出力に反映する。

## Override 規約

各 command が override してよいのは「**check 対象の doc 種別**」1 点のみ (例: design doc / Notion doc / PRD / issue comment / commit message / PR body)。閾値・loop 上限・check 対象 canonical (NG dict / PRINCIPLES) の変更は本 file で一元管理し、command 側で上書きしない。

## 関連

- `guidelines/writing/PRINCIPLES.md` — 文体規範 canonical
- `guidelines/writing/NG-DICTIONARY.md` — 語彙 block canonical
- `skills/comprehensive-review/SKILL.md` — writing axis NG table (PRINCIPLES 実装補助)
