# Web 可読性 (詳細)

`PRINCIPLES.md` `## Web 可読性` から切り出した詳細規約。

## scan pattern 対応

外向き prose は web (GitHub / GitLab / Notion / Slack / Confluence) で読まれる。読者は読まずに **scan する** (NNG: 79% scan / 16% line-by-line)。

| pattern | 読者行動 | 書き手の対応 |
|---|---|---|
| F-pattern | 上から左寄り、段落先頭数語のみ拾う | 段落先頭に keyword、左端に情報 |
| layer-cake | 見出しだけ拾って必要箇所だけ本文へ | 見出しを「主張」化、descriptive に |
| spotted | 太字 / link / 数値だけ拾う | keyword を太字、評価語に数値併記 |

外向き文書生成時 (`/git-push --pr` / `/post-comment` / `/docs`) は 3 pattern の **どれで読まれても主旨が伝わるか** を self-check する。

## Web 用 ミクロ規則

- **1 文 60 字以内** (最大 80 字)、読点 3 個まで — 技術文書 120 字上限を web 文脈では上書き
- **1 段落 3-4 行 / 250 字以内** — 段落間に空行必須
- **漢字比率 3 割目安** — 「行う / 出来る / 事 / 物 / 為」→「やる / できる / こと / もの / ため」
- **見出しは主張化** — 「アーキテクチャ」 NG / 「読み書き分離で負荷分散」 OK
- **結論先出し + 本文量半減** (inverted pyramid)
- **数値 / file path は太字 or `code`** — spotted pattern で拾われる確率上昇
- **見出し / キャッチは意味単位で改行** — Notion / Slack は実 viewer で preview
- **コードブロック / list の前後に空行** — renderer 差で潰れる対策
- **heading 前 2 語に keyword (front-loading)** — F-pattern で末尾は読まれない。先頭語が情報の核になるよう語順反転 (NG `データ可視化による不正検出の早期化` / OK `不正を 24% 早期検出: データ可視化導入`)
- **heading の文脈外自己完結** — search result / SNS feed / RSS で heading のみ露出するため、具体的事実 (数値 / 対象) を含める
- **heading の読点 3 個以下** — heading は 1 メッセージに絞る、句読点最小化
- **a11y: 色 + 書体 / 文言の二重識別** — 強調はボールド + 色、必須項目は「赤字」でなく「赤い ※ のついた」、色弱者 / screen reader 利用者に届く
- **WCAG 3.1.5 reading level**: 中学卒業相当 (連続ひらがな + 漢字長の計算式) を超えるなら平易版 or 要約ページを併記
- **モバイル: 難解語は読速を落とす** — comprehension は維持されるが読速低下で離脱する。SP 想定なら語数削減 + 平易語選択

## 出力前 web 用 追加 check

- [ ] 1 文 60 字以内 / 読点 3 個以内
- [ ] 見出しが主張型 (ラベル型でない)
- [ ] 段落 3-4 行以内、空行で区切り
- [ ] keyword / 数値 / file path が太字 or `code` で scan 可能
