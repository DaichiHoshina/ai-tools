# AI臭を消す — 英単語置換表 (d)

`PRINCIPLES.md` `## AI臭を消す3変換` `(d)` から切り出した詳細置換表。

## 英単語 → 日本語の平易表現 (置換表)

**大原則**: 技術用語に逃げない。その用語を知らない読者でも意味が伝わる平易な日本語で書く。用語を使うのは最終手段。

| 撤去 | 置換 |
|---|---|
| baseline | 基準値 |
| sanity (チェック) | 疎通確認 |
| キャリブ | 再調整 |
| inflation 率 | 増加率 |
| in-flight | 処理中 |
| scratchpad | 作業メモ |
| chain merge / provisional / gate 指標 / silenced 起動 | 日本語の平易表現 |
| arrival-rate / VU 駆動 / RPS | 「秒間に流入させるリクエスト数」など説明的に |
| exit code / CI ゲート化 / ハードゲート | 「自動で合否を判定」「閾値で不合格にする」 |
| metric / executor / tags 設計 | 「指標」「シナリオ設定」「分類軸」 |
| dashboard | 「画面」「監視ボード」 |
| lock 競合 / lock 取得 | ロック衝突 / ロック取得 |
| commit (DB 文脈) | コミット |
| TX / トランザクション | トランザクション (TX 単独表記禁止) |
| writer / reader | 書き込み処理 / 読み取り処理 |
| deploy | デプロイ (英表記禁止) |
| migration (DB 文脈) | マイグレーション (英表記禁止) |
| DDL | スキーマ変更 (DDL) |
| AUTO-INC | AUTO_INCREMENT (略すな、SQL 識別子は正式名) |
| undo log / redo log | undo ログ / redo ログ (InnoDB 内部語のため英表記を残し、ログ部分のみカナ化。同一文書内で「undo log」と「undo ログ」混在禁止) |
| index / query / table / row / column / schema | インデックス / クエリ / テーブル / 行 / 列 / スキーマ (PM/QA 読者想定なら日本語化。SQL コードブロック内・識別子は英表記維持) |
| metadata lock | メタデータロック |
| replica lag | レプリカ遅延 |
| batch / hourly batch | バッチ / 毎時バッチ |
| #1234 (番号のみ) | 「グループ #1234」「PR #1234」「issue #1234」等、何の番号か文脈明示 |

**残す技術用語**: `FOR UPDATE SKIP LOCKED` / `O(1)` / `EXPLAIN` / `p95` / `AUTO_INCREMENT` / `InnoDB` 等、置換すると意味が崩れるコード・SQL 識別子・数式に限定。

**英日混在病の判定**: 「lock」「commit」「deploy」「TX」「group」「writer」等の汎用語は既に日本語訳が定着している。これらを英語で残す正当な理由 (読者が SQL log 中の literal を期待している等) がない限り日本語化。表記揺れ (同一文書内で「lock」と「ロック」混在) は最悪、片方に統一。

**評価語に根拠 1 文必須**: リスク評価表で「低」「中」「高」「なし」だけで終わらせない。必ず「なぜそう判断したか」を 1 文添える。例: NG 「AUTO-INC lock: 低」 → OK 「AUTO_INCREMENT のロック衝突: 低い。検証環境で 36 万 4 千行を 1 分 39 秒で処理、本番時間帯に他の書き込み処理なし」。

**判定基準**: 「この用語を知らない PM / QA / 非エンジニア運営が読めるか」。読めなければ平易化。

**表記揺れ統一**: 単独の「メンテ」→「メンテナンス」等、語尾を揃える。ただし社内用語として定着しているもの (「メンテ IN/OUT」等) は残す。
