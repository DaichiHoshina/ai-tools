---
name: ui-skills
description: UI Skills - Tailwind CSS/motion/react特化のエージェント向けUI構築制約 + UIデザインシステム + Playwrightビジュアル検証。React/Tailwind実装、アニメーション、アクセシブルコンポーネント構築時に使用。
requires-guidelines:
  - nextjs-react
  - tailwind
  - shadcn
---

# ui-skills - UI構築制約

## テクノロジースタック

| 要素 | 要件 |
|------|------|
| スタイリング | **MUST** Tailwind CSS defaults |
| アニメーション | **MUST** `motion/react` |
| クラス管理 | **MUST** `cn`（`clsx` + `tailwind-merge`） |

## ルール早見表

### Components

| 区分 | ルール |
|------|--------|
| MUST | アクセシブルコンポーネントプリミティブ使用（Base UI, React Aria, Radix） |
| MUST | アイコンのみボタンに`aria-label` |
| NEVER | 同一インタラクション内で複数プリミティブシステム混在 |
| NEVER | キーボード・フォーカス動作の手動実装 |

### Interaction

| 区分 | ルール |
|------|--------|
| MUST | 破壊的アクション → `AlertDialog`必須 |
| MUST | エラーはアクション発生場所の隣に表示 |
| MUST | 固定要素に`safe-area-inset`尊重 |
| NEVER | `h-screen`使用（`h-dvh`に置換） |
| NEVER | `input`/`textarea`のペースト禁止 |

### Animation

| 区分 | ルール |
|------|--------|
| MUST | 明示的リクエストなしのアニメーション追加禁止 |
| MUST | `transform`, `opacity`のみアニメート |
| NEVER | レイアウト属性の動画化（`width`, `height`, `margin`等） |
| NEVER | インタラクションフィードバック200ms超 |

### Typography / Layout / Performance / Design

| 区分 | ルール |
|------|--------|
| MUST | 見出し → `text-balance`、本文 → `text-pretty`、データ → `tabular-nums` |
| MUST | 固定z-indexスケール（任意`z-[999]`禁止） |
| MUST | 空状態に明確な次アクションを用意 |
| NEVER | 大規模`blur()`/`backdrop-filter`の動画化 |
| NEVER | レンダーロジックで可能な処理に`useEffect` |
| NEVER | 明示要求なしのグラデーション、紫色/マルチカラーグラデーション |
| SHOULD | ローディングは構造的スケルトン表示 |
| SHOULD | `prefers-reduced-motion`尊重 |
| SHOULD | 正方形要素は`size-*`（`w-* h-*`より優先） |
| SHOULD | 既存テーマ/Tailwind標準色を優先 |

## 初回実装品質ガード

### 実装前確認

| # | 確認項目 | 方法 |
|---|---------|------|
| 1 | 既存UIとの一貫性 | 同プロジェクト内の類似画面を確認 |
| 2 | モーダル/ポップアップのサイズ | 内容量に応じた適切なサイズ |
| 3 | 表示データの具体性 | IDではなくタイトル・名前など人間が読める情報 |

### 実装後セルフチェック

| # | チェック | よくある失敗 |
|---|---------|-------------|
| 1 | z-indexの競合 | モーダルが背面に隠れる |
| 2 | ローディング状態 | 非同期処理中の表示がない |
| 3 | 空状態/エラー状態 | データなし時の表示が未定義 |
| 4 | API所要時間の事前確認 | 重い処理をUI内で同期実行 |
| 5 | レスポンシブ確認 | サイズが画面に対して不適切 |

## 出力形式

```text
Critical: `ファイル:行` - 違反内容 → 修正案
Warning: `ファイル:行` - 改善推奨 → 推奨案
Summary: Critical X件 / Warning Y件
```

## 参考リンク

- [ui-skills](https://github.com/ibelick/ui-skills)
- [Base UI](https://base-ui.com/) / [React Aria](https://react-spectrum.adobe.com/react-aria/) / [Radix UI](https://www.radix-ui.com/)
