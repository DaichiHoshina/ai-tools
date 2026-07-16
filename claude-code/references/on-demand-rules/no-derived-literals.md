# 派生値 literal 禁止 (canonical 参照のみ)

canonical source (一次データ) から導出できる派生値 (count / sum / list 長さ / 集計値) を、別 file に literal 数値で書かない。canonical への **参照のみ** を書く。

## Why

canonical に要素を足した瞬間、literal を書いた全箇所が古い値で残留する。2026-05-27 に AI 定型語 NG 辞書の語数を hook prompt / command 2 file へ literal で書き、辞書更新のたびに false positive の整合性指摘と再 fix loop が発生した。複数箇所に同じ数字を書いて片方だけ更新する古典 anti-pattern と同型だ。

## 書くな / 書け

**書くな**:

- 「N 語」「N 件」「合計 N」等の集計値を canonical 外の file に literal で書く
- list 長さ / 配列 length を literal 化する
- 「<source> の M 個」など、source 側で count できる数字を書く

**書け**:

- 「source: `<path>:<line>`」の参照だけを書く
- list 全体を埋め込みたいなら canonical を **そこへ移し**、元を削除する (source of truth の移動)
- どうしても数字が要るなら canonical 側に `<!-- count: N -->` 等の marker を置き、参照側は marker 名で言及する

**例外**:

- 将来変動しない固定値 (例: http status 200) は literal でよい
- test fixture 内の expected count (test 自体が canonical) は literal でよい

## 検査

- 数字を書く前に self-ask する: 「この数字は別の場所で count できるか?」→ Yes なら literal 化しない
- review 時は `grep -nE '[0-9]+ ?(語|件|個|箇所)' <changed_files>` で派生値疑いを検出する

## 同 file 内 sweep

派生値 literal を 1 箇所 fix したら、**同 file 全行を同型 pattern で grep し、残りも同じ commit で直す**。fix 対象 line だけ直して push すると、同 file 内の見落としが regression として残る (2026-06-24 に同 file 内 2 箇所目を見落として追加 fix になった実績)。

review finding の統合時も同じで、個別 line の指摘は「file X 内の派生値 literal 全件」に集約してから fix scope にする。

## 関連

- `markdown-anchor-sync.md` — cross-ref desync 防止の同系 rule
