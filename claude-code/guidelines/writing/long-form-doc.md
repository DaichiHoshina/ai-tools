# 長文ドキュメント執筆 (DD / PRD / RCA / Notion ページ)

> **本ファイルは PR-A 時点での stub**。PR-B (writing refactor 第 2 弾) で `guidelines/common/user-voice.md` (223 行) を取り込み、ADR / PRD MoSCoW / EARS テンプレを統合する予定。
>
> 現時点の長文 doc 詳細ガイドは以下を参照:
> - 共通原則: [PRINCIPLES.md](PRINCIPLES.md) (4 問 / 媒体別構造 / セルフチェック 6)
> - DesignDoc: [design-doc-protocol.md](design-doc-protocol.md) (4 Step + 10 パターン + テンプレ選択 + アンチパターン + セルフチェック 18)
> - 詳細パターン: `references/writing-patterns.md` (書き直し Phase 1-8 / レビュー3段 / textlint)
> - user-voice (移送予定): `guidelines/common/user-voice.md` (長文向け 4 問 / 5 原則 / NG 辞書 / 3 層リライト)

## TL;DR (PRINCIPLES.md より)

長文 (Design Doc / PRD / RCA / Notion ページ) を書くときの最小ルール:

- **TL;DR 冒頭 1-3 文で結論**。「本稿では〜について述べる」系導入は削除
- 800-1500 字 / ページ、2000 字超なら分割
- 1 セクション = 地の文 3-5 割 + 箇条書き / 表 5-7 割
- 箇条書きは 3-5 項目。7 超は表 or 段落分割
- コードブロックは 5 行以内、超過時は意図 1 文補足
- 箇条書きだけだと「何故列挙か」が消える → 前後に 1-3 文の地の文

## 想定追加内容 (PR-B)

| 章 | 移送元 | 行数目安 |
|---|---|---|
| 長文向け 4 問 (詳細版) | `guidelines/common/user-voice.md` | 40 |
| 5 つの執筆原則 | 同上 | 50 |
| 3 層リライト (対話型) | 同上 | 15 |
| NG 辞書 | 同上 | 30 |
| トリアージルール (質問過多回避) | 同上 | 15 |
| ADR テンプレ | `references/writing-patterns.md` (旧 writing-principles.md から移送済) | 40 |
| PRD MoSCoW テンプレ | 同上 | 50 |
| EARS 受入基準 | 同上 | 40 |

PR-B で本 stub を 270 行版に置換予定。
