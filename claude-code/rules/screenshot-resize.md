# Screenshot リサイズ必須

外向き text にスクショを添付するときは **必ずリサイズしてから貼る**。原寸貼付は禁止。

## 適用範囲

- PR body / issue comment / MR description
- Slack / Notion 投稿
- local-docs HTML doc の `<img>` 埋込
- chat 内で user に画像を返す時 (参考画像として提示する場合含む)

## 基準 (default)

| 項目 | default |
|---|---|
| 幅 | 上限 1200px (retina 撮影は @1x 相当まで縮小) |
| file size | 500KB 目安、超えるなら JPEG 化 or 品質下げ |
| 形式 | PNG (UI screenshot) / JPEG (写真・広範囲) |

## 手順 (macOS 標準)

```bash
# 幅 1200px にリサイズ (アスペクト比維持)
sips -Z 1200 <file>.png

# 500KB 超なら JPEG 化 (品質 80)
sips -s format jpeg -s formatOptions 80 <file>.png --out <file>.jpg
```

複数枚一括:

```bash
for f in *.png; do sips -Z 1200 "$f"; done
```

## 例外

- **pixel 単位の欠け / 1px ずれの UI bug 報告**: 原寸可。ただし該当箇所を crop してから貼る (画面全体を原寸で貼らない)。理由を 1 行併記 (例: 「1px border 欠けを見せるため原寸」)
- **font hinting / anti-aliasing の比較**: 原寸可。同上、crop + 理由併記

## Why

- 原寸 retina screenshot は 5-10MB 級で PR / Slack / Notion の load を遅くする
- Slack は自動リサイズするが、Notion / GitHub は原寸を保持し scroll 阻害を起こす
- local-docs HTML に埋め込むと `<img>` の幅を CSS で絞っても download size は原寸のまま、共有時に相手側の帯域を無駄に消費する
- 1200px 上限は Notion / GitHub の実表示幅 (約 800-1000px) を超えない範囲で dpr 2 対応する妥協点

## 参照

- `guidelines/writing/README.md` (外向き text 全般の canonical)
