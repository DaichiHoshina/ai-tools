# NG 辞書

hook (`lib/jp-quality-check.sh:_extract_term_list`、`hooks/pre-tool-use.sh` から source) が動的抽出する NG 語 list。key 名・記法を 1 文字も変えない。

執筆論・使用指針は [PRINCIPLES.md](PRINCIPLES.md) 参照。

**AI定型語**: 効果的に / 効率的に / シームレスに / 直感的に / 革新的な / 素晴らしい / 強力な / より良い / 〜を実現します / 〜を提供します / 〜を可能にします / 〜することができます / ご紹介します / ご覧ください / 〜いただけます / 重要なポイント / 注目すべき点 / 本機能は / 本ドキュメントは / 本記事では / 本稿では〜について述べる / 包括的な / 堅牢な / 柔軟な / スケーラブルな / 最適化 / 影響なし / 収まる / 外挿 / 余裕大 / 無視可 / 無視可能 / 懸念解消 / 全観点 / 判定確定 / 漸近

**断定語 (warn-only)**: 完了 / 解消 / 見込み / クリア / 問題なし / 完了,問題なし

> 連続漢字≥5 の頻出 NG 例 (structural warn 対象、warn-only): 動作確認手順 / 回答案検討 / 回答案確定 / 対応方針決定 / 参照箇所影響範囲確認 / 上流下流関係 / 再投稿完了 / 同梱未対応。「動作の 確認手順」「回答案を 検討」のように助詞挿入か訓読み開きで分解する。

**英語jargon (warn-only)**: digest / inject / sweep / canonical / trigger / fan out / fan-out / stale / orchestrate / delegate / salience / priming / fallback / dedup / throttle / insight / takeaway / deep dive / edge case / align

> 英語jargon は warn-only。日本語で言える一般語は日本語化する (digest→要約 / inject→差し込む / sweep→点検 / canonical→正 / trigger→きっかけ / stale→古い / fallback→代替 / edge case→境界事例 / align→そろえる)。識別子・command 名として正当に使う場合は backtick で囲むと検査対象外になる。追加根拠は user 指摘「専門用語使いすぎ」(2026-07-10) の incident。

**体言止め末尾 (structural)**: 済 / 済み / 完了 / 可能 / 必要 / 対応 / 中 / なし / あり / 予定 / 実施 / 確認 / 追加 / 削除 / 修正 / 更新 / 化

> 体言止め末尾は hook の構造 warn (`_check_sentence_structure`) が bullet 行末の名詞終止判定に使う suffix list。block ではなく warn-only。

**主体不明断定 (skill-only)**: 多くの〜 / 一般に〜 / 一般的に〜 / よく〜される / 〜と言われる / 〜だろう / 〜と考えられている

> `(skill-only)` mode は hook 抽出対象外。`/jp-writing` skill self-check 経由でのみ参照する。技術 README 等で正当な総称表現として使う場面があり、hook 自動 block / warn は誤爆コストが高いため。語源は PRINCIPLES.md `## AI臭の根本: 書き手不在` `(1) 主体を明示する`。

**主体不明断定 (warn-only)**: と言われる / と考えられている / とされている

> hook (chat 経路) が warn する grep-safe subset。上の skill-only key は「〜」placeholder 入りで literal grep に載らないため別 key として分離した。「一般的に」「だろう」は正当用法が多く誤爆コストが高いので含めない。

**jp-writing 固有 NG (skill-only)**:

| NG | OK |
|----|-----|
| 体言止め圧縮による擬人化 (`flag 未渡しが実行を走らせない`) | 主語を明示し使役展開する (`flag を渡さない場合、実行されない`) |
| 連用形否定 (`未渡し` / `未指定時`) | 「指定されなかった場合」と展開する |
| 口語動詞 (`倒す` / `握る` / `走らせる`) | 書き言葉に置換する (`無効化する` / `保持する` / `実行する`) |
| 英単語 + `する` の動詞化 (地の文で `commit する`) | 日本語動詞に置換。識別子・コマンド名はバッククォート囲み、動詞化しない |
| 専門用語 (異職種向け): `fail-closed` / `TX` / `dead code` | 安全側に倒す / トランザクション / 死蔵コード。識別子・コマンド・DBカラムは維持 |
| 社内造語: `派生値` / `stale-write` / `race window` | `計算値` / `古い値による上書き` / `並行する処理が古い値でUPDATEする競合`。外向き文書は平易化 |

**難読漢語 (block)**: 鑑みる / 勘案 / 斟酌 / 慮る / 忖度 / 俯瞰 / 俯瞰的 / 概観 / 敷衍 / 援用 / 惹起 / 奏功 / 踏襲 / 看做す / 然るに / 喫緊 / 肝要 / 要諦 / 蓋し

**弱い表現 (block)**: かもしれない / と思います / と思われる / 可能性がある

**冗長表現 (block)**: することができる / することが可能 / を行う / ということになる / であると言えます

**非日常英語 (block)**: leverage / utilize / facilitate / mitigate / comprehensive / robust / seamless / holistic / granular / rationale / paradigm

**AI段取り定型 (block)**: まず / まずは / 次に / 最後に / 続いて / 加えて / さらに / それでは / では〜していきます / まず〜しましょう / 次に〜します / 最後に〜します / 続いて〜します / 加えて〜します / さらに〜します / それでは〜していきましょう

**ヘッジ濫用 (block)**: 念のため / 一応 / 改めて確認 / 念のために / 改めまして / なお念のため / 一応念のため

**過剰丁寧 (block)**: ご確認ください / ご確認をお願いします / お手数ですが / 恐れ入りますが / お気軽に / ご不明な点 / お気軽にご相談 / ご一読いただけますと

**置換候補 (頻出)**: 踏襲→引き継ぐ / 鑑みる→踏まえる / 喫緊→直近 / leverage→活かす / utilize→使う / mitigate→緩和する / 影響なし→該当なし or 既存挙動そのまま or repo に取り込み不要

**カタカナ造語禁止**: シームレス / シームレスに / ロバスト / スケーラブル / 直感的 / 直感的に / 革新的 / 革新的な / 包括的 / 包括的な / 堅牢 / 堅牢な / フレキシブル / インテリジェント / スマート / リッチ / モダン / クリーン / ハイレベル / ローレベル / クリティカル / クリティカルに / セキュア

> 中間漢語 (網羅 / 整合 / 妥当 / 逐次 / 担保 / 起因 / 是正 等) は block 対象外。「中学生が辞書なしで読める」基準で都度判断、難読 list 拡大は incident ベースのみ。

## 偶然一致 (false positive) 回避

hook の match logic は `grep -ioFf` (substring・case-insensitive)。技術用語 / skill 名 / library 名が NG 語を内包すると hit する (例: skill 名「robust-XX」が `robust` に hit、prose 内の `leverage` を含む製品名 / API 用語等)。

### 回避優先順位

1. **inline code 化 (default)**: 技術用語 / 固有名詞は backtick で囲む。`_strip_code_blocks` が ` `code` ` / ` ```block``` ` を除去するため hook をすり抜ける。commit message / PR / Slack / Notion / DD / RCA すべて適用。
   - 例: `leverage を使う` → ✗ block / `` `leverage` ライブラリを使う `` → ○ pass
2. **書き換え**: 自然言語の prose 内に bare 出現する場合は plain JP / EN に置換する (`leverage → 活かす`、`robust → 堅実な`)。NG-DICT 末尾の置換候補表を参照。
3. **whitelist 追加 (incident base 限定)**: 1, 2 で吸収できず**かつ同じ語で 3 回以上 false positive 実害**が出た時のみ、本 file に whitelist section を新設して exact match 除外する。先回り whitelist 化禁止 (hook 機能後退の温床)。

### canonical 運用

- skill 名 / agent 名 / library 名 / API method 名 を**外向き prose に bare 出現させない**。code fence 内に閉じ込めるか日本語説明に置換する
- block 発生時の retry は本 section の優先順位に従う (whitelist 提案を先に出さない)
- `~/.claude/logs/jp-quality-block.log` に hit 履歴が残る。同語 3 回到達後に whitelist 化を再評価する
