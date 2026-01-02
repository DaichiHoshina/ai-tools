# Tailwind CSS ガイドライン

Tailwind CSS v4.0対応（2025年）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **Utility-First**: ユーティリティクラス中心の設計
- **レスポンシブ**: モバイルファーストのブレークポイント
- **カスタマイズ可能**: テーマ・デザイントークンで一元管理
- **パフォーマンス**: 未使用CSSの自動削除

---

## v4.0 新機能（2025年）

### 高速エンジン
- フルビルド: **5倍高速化**
- インクリメンタルビルド: **100倍以上高速化**（マイクロ秒単位）

### モダンCSS活用
- Cascade Layers使用
- `@property`で登録カスタムプロパティ
- `color-mix()`サポート

### セットアップ簡素化
- 依存関係削減
- ゼロコンフィグ
- CSS1行で導入: `@import "tailwindcss";`

### Vite統合
- 公式Viteプラグイン
- 自動コンテンツ検出（設定不要）
- 最大パフォーマンス

---

## 新ユーティリティ・バリアント

### not-* バリアント
他のバリアント・セレクター・メディアクエリに一致しない時のみスタイル適用:
```html
<div class="not-hover:opacity-50">...</div>
```

### 新ユーティリティ
- `color-scheme` - ダーク/ライトモード制御
- `field-sizing` - フォームフィールドサイズ
- 複雑シャドウサポート
- `inert` - 非活性要素

---

## ブラウザサポート

- Safari 16.4+
- Chrome 111+
- Firefox 128+

---

## ベストプラクティス

### クラス命名
- 意味的に明確なユーティリティの組合せ
- 複雑な組合せはコンポーネント化

### レスポンシブ設計
```html
<div class="w-full md:w-1/2 lg:w-1/3">
```

### ダークモード
```html
<div class="bg-white dark:bg-gray-900">
```

### 再利用
- 繰り返しパターン → `@apply`でコンポーネント化
- ただし、過度な`@apply`使用は避ける（Utility-First原則）

---

## Next.js統合

### インストール
```bash
npm install tailwindcss@next @tailwindcss/vite@next
```

### 設定（v4）
`app/globals.css`:
```css
@import "tailwindcss";
```

`next.config.js`:
```js
import tailwindcss from '@tailwindcss/vite'

export default {
  experimental: {
    vitePlugins: [tailwindcss()]
  }
}
```

---

## カスタマイズ

### CSS変数でテーマ定義
```css
@theme {
  --color-primary: #3b82f6;
  --font-display: "Inter", sans-serif;
}
```

### 使用
```html
<h1 class="text-primary font-display">
```

---

## パフォーマンス最適化

- PurgeCSS統合（v4で自動）
- JIT（Just-In-Time）モード標準
- 本番ビルドで未使用CSS自動削除
