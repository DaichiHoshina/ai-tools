# feature flag は「flag ON」と「利用側 deploy」の 2 コンポーネント

feature flag / maintenance flag / config 切替は、**「flag ON」と「利用側の deploy / 再読み込み」の 2 コンポーネントが揃って初めて有効になる**。片方だけでは機能しない。

## 原則

- flag ON だけでは有効化しない。「設定変更 + 利用側 deploy / 再読み込み」の両方が要る
- 新 middleware を含む機能リリースは「**deploy 完了 → flag ON**」順を厳守する
- 「flag ON できた」判定は 2 段で確認する: 状態確認 (Redis / DB / config store の値変化) + 実挙動確認 (実 traffic の応答変化)
- 逆順 (flag ON 後に deploy) は禁止。deploy 失敗時に flag だけ立った中間状態が本番に残り、外形挙動が変わらない中途半端な状態が長時間放置される (過去に 50 分放置の事例あり)

## 同構造パターン

feature flag + 利用箇所 deploy / config 書換え + 再読み込み / DB schema 変更 + 利用 query 更新 / CDN 設定切替 + キャッシュ purge。すべて「設定変更」と「利用側 deploy / 再読み込み」を独立に扱う。

## 適用範囲

全 repo / 全 stack の feature flag / maintenance flag / config 切替 / DB schema 変更のリリース手順設計時。

## 参照

- `rules/pr-release-order.md` (release 順の設計)
- CLAUDE.md `## Definition of Done`
