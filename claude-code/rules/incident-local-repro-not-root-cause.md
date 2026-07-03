# incident 調査: ローカル再現 = 真因確定ではない

incident 調査で「ローカルで再現できた」を「本番の真因を突き止めた」と同一視しない。症状 endpoint だけを見て真因を断定してはいけない。

## 原則

- **ローカル再現は仮説検証であって真因確定ではない**。再現した現象が本番の**規模・種類と一致するか**を必ず突き合わせる
- **症状 endpoint に視野を閉じない**。同時刻に他 endpoint / service でも異常が出ていないかを必ず横断で確認する
- 一致しなければ別経路。再現できた満足感で判断を止めない

## Why

症状が 1 endpoint に出ていても、根本原因は DB 全体 / infra 全体で起きているケースがある。ローカルで別経路 (例: 同一 user 並列アクセス) の再現が取れても、本番は無関係な多数 user / endpoint が同時に詰まる別現象、ということが起きる。「再現できた」satisfaction が視野を狭めて真因を取り違える。

## 読み違えの典型構造

1. **ローカル再現 = 真因確定 の誤同一視**: 再現した現象と本番現象の「規模」「種類」の違いを確かめない
2. **症状 endpoint への視野閉塞**: 症状 endpoint のログ・trace で完結し、同時刻に他 endpoint も詰まっていた事実を見落とす

## How to apply (incident 調査手順)

1. **error signature を service 横断で時系列集計**: 症状 endpoint で error を見つけたら、まず同じ error (例: `Lock wait timeout` / `Error 1205`) を全 endpoint / 全 service で集計する。1 endpoint に閉じてないか先に確認する
2. **infra メトリクスを必ず見る**: ロック競合系は DB インスタンスメトリクス (`row_lock_time` / `blocked_transactions` / `deadlocks` / CPU / `write_latency`) を確認する。窓がピタッと始まりピタッと終わる + 全 endpoint 横断 = infra 全体イベントのサイン
3. **ローカル再現の突合**: 再現した現象が本番の「規模 (件数 / QPS)」「種類 (どの経路で起きるか)」と一致するか必ず突き合わせる。一致しなければ別経路として仮説を組み直す
4. **握り手の特定**: lock を「握っていた側」の TX は APM では特定しづらい。DBM activity sample / slow query log / Performance Insights の Top SQL (lock wait 順) を直接見る

## 教訓のひとことまとめ

「再現できた」≠「真因」。症状の点でなく、同時刻の面 (全 endpoint + infra メトリクス) を見る。

## 適用範囲

- 全 repo / 全 stack の incident 調査
- 5xx / 4xx 増加 / latency 悪化 / DB ロック競合 / connection 枯渇など、症状が特定 endpoint に集中する障害調査

## 参照

- CLAUDE.md `## Root Cause Analysis`
- `/root-cause` skill
