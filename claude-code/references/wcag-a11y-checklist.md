# WCAG a11y Checklist (canonical, WCAG 2.2 AA)

本 file が Claude Code config における a11y checklist の canonical。UI/UX review 系の記述はすべて本 file を参照する。

参照元:
- `commands/design-review.md` (Phase 4: Playwright ライブ検証時に本 checklist を使う)
- `agents/design-review-agent.md` (Phase 4: ライブ検証時に本 checklist を使う)
- `skills/uiux-review/SKILL.md` (Step 2: 静的コードレビュー時に本 checklist を使う)

基準は WCAG 2.2 AA に統一する。旧 WCAG 2.1 AA 記述は本 file に統合済のため、参照元では使わない。

## Critical (Blocker 相当、必須)

### Perceivable (知覚可能)

視覚・聴覚に依存せず情報を知覚できるかを確認する。

- [ ] コントラスト比が本文 text で 4.5:1 以上ある
- [ ] コントラスト比が大文字 text / UI component / graphical object で 3:1 以上ある
- [ ] 情報を色のみで伝えていない (色 + text / icon / 下線などを併用する)
- [ ] 全ての img / icon-button に alt text または aria-label がある
- [ ] video / audio の代替 text (caption / transcript) が提供されている

### Operable (操作可能)

pointer なしの keyboard / touch 操作だけで全機能に到達できるかを確認する。

- [ ] Tab / Enter / Space / Escape のみで全機能が操作できる
- [ ] Tab 順序が視覚上の読み順と一致する
- [ ] focus indicator が 2px 以上の ring / outline で明確に見える
- [ ] focus が component の背後に隠れない (WCAG 2.2 追加: Focus Not Obscured)
- [ ] touch target が 24×24px 以上ある (44×44px を推奨する。WCAG 2.2 追加: Target Size Minimum)
- [ ] keyboard trap がない (modal / dropdown 内から Tab で抜けられる)
- [ ] destructive action (削除 / 送信) に確認 dialog がある

### Understandable (理解可能)
- [ ] 全 form input に label が関連付けられている (`<label for>` / `aria-label` / `aria-labelledby`)
- [ ] required 項目 / エラーメッセージが text で明示されている
- [ ] error message が原因と修正方法を伝える
- [ ] 同一操作で予期しない context 変化 (自動 submit / focus 移動) が起きない

### Robust (堅牢)
- [ ] semantic HTML が使われている (`<button>` / `<nav>` / `<main>` / heading level)
- [ ] ARIA role / state / property が仕様準拠 (invalid ARIA を使わない)
- [ ] name / role / value が支援技術に伝わる

## Warning (High/Medium 相当、推奨)

Blocker にはしないが、放置すると利用性を損なう項目を確認する。

- [ ] skip link (main content へのジャンプ) がある
- [ ] page title / heading 構造が階層順 (h1 → h2 → h3) になっている
- [ ] language attribute (`<html lang>`) が設定されている
- [ ] motion / animation を prefers-reduced-motion で抑制できる
- [ ] session timeout に warning + 延長手段がある
- [ ] drag 操作に代替手段がある (WCAG 2.2: Dragging Movements)
- [ ] 認証 flow が cognitive test (パズル / 記憶) に依存しない (WCAG 2.2: Accessible Authentication)

## 適用 note

- Playwright ライブ検証 (`/design-review`) では実際の DOM / snapshot / screenshot で確認する
- 静的コードレビュー (`uiux-review` skill) では code 上で判断できる項目のみ確認する (contrast / touch target 実測は skip 可)
- 違反発見時は triage matrix (`commands/design-review.md` 参照) の Blocker / High-Priority / Medium-Priority / Nitpick に分類する

## 参照

- [W3C WCAG 2.2](https://www.w3.org/TR/WCAG22/) — 公式仕様
- `commands/design-review.md` — Playwright ライブ検証の 7-phase フロー canonical
- `guidelines/writing/PRINCIPLES.md` — text 書式規範
