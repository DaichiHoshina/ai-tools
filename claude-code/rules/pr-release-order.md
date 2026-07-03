# PR 分割は「merge 順 = 本番反映順」で 1 PR ずつ検証する

`main merge = 本番リリース` を前提にする repo では、大機能を複数 PR に割るとき、**各 PR を「merge する順」に並べ、その PR が merge された瞬間の本番状態が安全か**を 1 つずつ言語化して確かめる。依存グラフだけ書いて満足しない。

## 原則

- PR を **merge 順に一列化**する (依存表でなく時系列)
- 各 PR で「**merge 直後の本番状態**」を 1 文で言う
  - 例: 「API が生えるが画面がないので誰も叩かない」
  - 例: 「画面が出て初めて user が操作可能になる」
- 3 パターンで安全判定する:
  - **BE 先行 (画面なし)** = 本番に出ても見えない、無害。好きな順で merge 可
  - **FE 公開** = ここで初めて user に見える。前提の BE が全部 merge 済か / 中途半端な機能が露出しないかを確認
  - **Contract (旧削除・破壊的変更)** = 公開・安定後に最後。新旧並走 → 旧落ち切り確認 → 削除
- 段階リリースの定石: **Expand-Migrate-Contract** = BE 全部先行 → FE をリリース日に一斉公開 → 旧削除を最後

## Why

機能単位や層単位で割っただけだと「途中まで merge した状態」が抜ける。admin だけ先に公開して user 側がない場合、当選者が操作できない中途半端な画面が本番に出る事故になる。merge は不可逆 (本番反映) なので、出る順の検証が必須。

## 防御 flag の活用

`has_size` のような「立てなければ無影響」の flag があれば、admin FE を user FE より先出しできる (運営が立てるまで user 無影響)。

## 破壊的 API 変更の前提確認

破壊的変更を含む場合、対象画面が **WebView (サーバー配信) か native app か**を必ずコードで裏取りする。

- **WebView**: FE/BE 同日リリースで旧 client 残留がなく、新旧両対応が不要になり設計が大幅に単純化する
- **Native**: 旧バージョン落ち切りまで両対応が要る

判定を怠ると mobile 合意ブロッカーを不要に抱える。

## How to apply

- 大機能起票時に「merge 順一列化 → 各 PR の merge 直後本番状態 1 文」を DesignDoc / issue に明記する
- BE / FE / Contract を混在させる PR は分割候補として検討する
- Contract PR は本番安定確認後にのみ merge する

## 適用範囲

- 全 repo (main merge = 本番反映 を前提にする repo)
- 3 PR 以上に割る機能リリース時
- 破壊的 API 変更を含むリリース時

## 参照

- `rules/feature-flag-deploy-order.md`
- `rules/chain-pr-main-merge.md`
- CLAUDE.md `## Definition of Done`
