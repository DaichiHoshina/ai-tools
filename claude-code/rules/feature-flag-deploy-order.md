# feature flag は「flag ON」と「利用側 deploy」の 2 コンポーネント

feature flag / maintenance flag / config 切替は、**「flag ON」と「利用側の deploy / 再読み込み」の 2 コンポーネントが揃って初めて有効になる**。片方だけでは機能しない。

## 原則

- flag ON だけでは有効化しない。**「設定変更 + 利用側 deploy / 再読み込み」の両方**が要る
- 新 middleware を含む機能リリースは **「deploy 完了 → flag ON」順を厳守**する
- 「flag ON できた」の判定根拠を明確化する: 設定反映 (Redis 等の状態確認) ≠ 実際の挙動変化 (実 traffic で確認)

## Why

flag だけ立てて middleware / 利用側 deploy がまだの状態は「flag だけ立ってる」中間状態で、外形挙動は変わらない。過去に admin 操作で flag ON した 50 分後に deploy 完了で新 middleware が稼働するまで、対象 API は通常応答を返し続けた事例があった。データ整合性は仕組み (FK / UNIQUE / SELECT FOR UPDATE) で担保されたが、「flag ON できた」の判定根拠が曖昧になった。

## 同構造の他パターン

- feature flag + 利用箇所 deploy
- config 書換え + 再読み込み
- DB schema 変更 + 利用 query 更新
- CDN 設定切替 + キャッシュ purge

すべて「設定変更」と「利用側 deploy / 再読み込み」を独立に考える。

## How to apply

- runbook に「deploy 完了確認」step を必ず入れ、deploy 前に flag 操作しない
- 「flag ON できた」と言うときの根拠を 2 段で確認する
  - 状態確認 (Redis / DB / config store の値変化)
  - 実挙動確認 (実 traffic に対する応答変化)
- 逆順 (flag ON 後に deploy) は事故を招く。deploy が失敗しても flag だけ立ってる中間状態が本番に残る

## 適用範囲

- 全 repo / 全 stack
- feature flag / maintenance flag / config 切替 / DB schema 変更のリリース手順設計時

## 参照

- `rules/pr-release-order.md` (release 順の設計)
- CLAUDE.md `## Definition of Done`
