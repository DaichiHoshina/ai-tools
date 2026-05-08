---
name: slack-rich-copy
description: HTMLをSlack/Notion/Gmail で貼れるリッチテキスト（HTML+RTF+plain）として macOS クリップボードへ。リンク一覧・テーブル貼付時に使用。
---

# slack-rich-copy

macOS NSPasteboard に **HTML / RTF / plain text** を同時セットし、Slack・Notion・Gmail・Apple Notes などの rich text composer で `⌘V` するとリンクや書式が保持されたまま貼付できる。

## なぜ必要か

- `pbcopy` は plain text のみ。Slack composer に貼ると `<URL|text>` mrkdwn は解釈されない（送信後のみ展開）
- `pbcopy -Prefer rtf` で RTF だけ送っても Slack は無視することがある
- osascript `«data HTML...»` は `«class HTML»` 単独で UTI 不足 → Slack 認識されない
- **`public.html` UTI + `public.rtf` + plain string の3点同時セット**が確実

## ワークフロー

### Step 1: HTML を生成

リスト・リンク・テーブル等を含む HTML を `/tmp/rich.html` 等に書き出す。

```html
<ul>
  <li><a href="https://example.com/1">item 1</a> 説明</li>
  <li><a href="https://example.com/2">item 2</a> 説明</li>
</ul>
```

### Step 2: Swift スクリプトで pasteboard セット

```bash
swift ~/.claude/skills/slack-rich-copy/scripts/copy-rich.swift /tmp/rich.html
```

オプションで plain text フォールバックを別ファイルから読むことも可能:

```bash
swift ~/.claude/skills/slack-rich-copy/scripts/copy-rich.swift /tmp/rich.html /tmp/rich.txt
```

成功すると `OK html=...B rtf=...B plain=...chars` と出力。

### Step 3: 確認（任意）

```bash
osascript -e 'clipboard info'
# → «class HTML», N, «class RTF », N, «class utf8», N, string, N
```

### Step 4: 貼付

Slack・Notion・Gmail composer で `⌘V`。リンクとリスト構造が保持される。

## 失敗時の切り分け

| 症状 | 原因 | 対処 |
|---|---|---|
| Slack で plain text として貼られる | composer がマークダウン入力モード | composer 右下の **Aa** アイコンを ON（rich text モード） |
| `swift` not found | Xcode CLT 未インストール | `xcode-select --install` |
| HTML parse failed | HTML が壊れている | 単純な構造で再試行（`<ul><li>...</li></ul>` 等） |

## 設計メモ

- pbcopy で HTML UTI を直接書く API がないため Swift NSPasteboard を使う
- Python (PyObjC) でも可能だが macOS 同梱 python3 は AppKit 非搭載 → Swift が無依存で確実
- `«class HTML»` (Apple HTML pasteboard type) だけだと Slack に認識されないことがあり、`public.html` UTI の同時設定が鍵

## トリガー語

「Slack に貼れる形で」「リッチテキストで」「リンク付きリストでコピー」等。
