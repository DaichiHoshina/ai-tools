# UI/UX 設計ガイドライン

> **目的**: Claude Codeに「渡して、そのまま設計・実装に効く」実践的ガイド

---

## 鉄板3原則（優先順）

| 原則 | 強み | 実装への直結度 | 公式 |
|------|------|---------------|------|
| **1. Material Design 3** | コンポーネント状態の完全定義、デザイントークン一元管理 | ⭐⭐⭐ Tailwind/shadcn実装パターン | [m3.material.io](https://m3.material.io/) |
| **2. WCAG 2.2 AA** | コントラスト、フォーカス、キーボード操作を数値基準で担保 | ⭐⭐⭐ lint/チェックリスト化 | [WCAG 2.2](https://www.w3.org/TR/WCAG22/) |
| **3. Nielsen 10原則** | 「なぜ使いづらいか」を言語化、設計レビューに強い | ⭐⭐ セルフチェック | [10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) |

---

## Claude Code用プロンプトテンプレート

```
この画面をMaterial Design 3でコンポーネント分解し、
状態（loading/disabled/error/success）を定義。
WCAG AA（コントラスト4.5:1以上、キーボード操作、フォーカス表示）を満たす
Tailwind/shadcn実装案を提案。
Nielsen 10原則でセルフレビューして指摘も添えて。

【管理画面向け】デジタル庁デザインシステムの日本語文言・フォーム設計も参考に。
【一般向け】M3 Expressiveで視覚的魅力を重視。
```

---

## Material Design 3（M3）実装ガイド

### コンポーネント状態（全インタラクティブ要素で必須）

| 状態 | 視覚表現 | 実装（Tailwind） |
|------|---------|-----------------|
| Default | 通常 | `bg-primary text-white` |
| Hover | マウスオーバー | `hover:bg-primary/90` |
| Focus | フォーカス | `focus:ring-2 focus:ring-primary focus:ring-offset-2` |
| Active | 押下時 | `active:bg-primary/80` |
| Disabled | 無効化 | `disabled:bg-gray-300 disabled:cursor-not-allowed` |
| Loading | 読み込み中 | `opacity-50` + スピナー |
| Error | エラー | `bg-red-500 border-red-600` |
| Success | 成功 | `bg-green-500` |

### デザイントークン

**カラー**（M3準拠）:
```typescript
colors: {
  primary: '#6750A4', 'on-primary': '#FFFFFF',
  secondary: '#625B71', error: '#B3261E', success: '#2E7D32'
}
```

**スペーシング**: 4px基準（4, 8, 12, 16, 24, 32, 48）
**角丸**: sm=8px, md=12px, lg=16px, xl=28px

### M3 Expressive（2025年）

35の新シェイプ + モーフィング、15のコンポーネント更新 → 一般ユーザー向けで視覚的魅力重視

---

## WCAG 2.2 AA完全準拠

### 必須達成基準（数値）

| 対象 | 最低比率 | 推奨（AAA） |
|------|---------|------------|
| 通常テキスト（<18pt） | **4.5:1** | 7:1 |
| 大テキスト（≥18pt） | **3:1** | 4.5:1 |
| UIコンポーネント/グラフィック | **3:1** | - |

### キーボード操作（必須）

| 操作 | キー | 実装 |
|------|------|------|
| フォーカス移動 | Tab/Shift+Tab | `tabindex="0"` |
| 実行 | Enter/Space | `onKeyDown` handler |
| 閉じる | Escape | Dialog/Modal |
| 選択 | Arrow keys | Select/Radio |

### フォーカス表示

```tsx
// ✅ 明確なフォーカスリング（2px以上）
className="focus:ring-2 focus:ring-primary focus:ring-offset-2"

// ❌ outline:none のみ（NG）
```

### タッチターゲットサイズ

**最低**: 44x44px（WCAG 2.2新基準）

```tsx
<button className="min-h-[44px] min-w-[44px] px-4">ボタン</button>
```

### WCAG 2.2 新達成基準（2023年追加）

1. **Focus Not Obscured** - フォーカス要素が隠れない
2. **Dragging Movements** - ドラッグ操作の代替手段
3. **Target Size** - 24x24px最低（AA）

---

## Nielsen Norman 10原則（クイックリファレンス）

| 原則 | 実装ポイント |
|------|-------------|
| **1. System Status** | ローディング状態、進捗表示（`<Spinner />`, `<Progress>`） |
| **2. Real World Match** | 自然な言葉（「保存」 not 「Commit」） |
| **3. User Control** | 元に戻す、キャンセル機能 |
| **4. Consistency** | 統一されたボタンスタイル（variant） |
| **5. Error Prevention** | 確認ダイアログ、バリデーション |
| **6. Recognition > Recall** | アイコン + ラベル |
| **7. Flexibility** | ショートカット提供（Ctrl+S等） |
| **8. Minimalist Design** | 必要な情報のみ表示 |
| **9. Error Recovery** | 明確なエラーメッセージ + 対処方法 |
| **10. Help** | ツールチップ、ヘルプリンク |

---

## デジタル庁デザインシステム（管理画面向け）

[design.digital.go.jp](https://design.digital.go.jp/)

**用途**: SaaS管理画面、B2Bダッシュボード、データ入力フォーム
**参考**: 日本語の文言パターン、エラーメッセージ表現、確認画面構成

---

## 実装例（Tailwind/shadcn）

### ボタン完全実装

```tsx
<Button
  disabled={isLoading}
  className="min-h-[44px] focus:ring-2 focus:ring-primary
    disabled:opacity-50 hover:bg-primary/90"
>
  {isLoading ? <Spinner /> : '保存'}
</Button>
```

### フォーム完全実装

```tsx
<Label htmlFor="email">メールアドレス</Label>
<Input id="email" type="email" required
  aria-describedby="email-error"
  className="min-h-[44px] focus:ring-2" />
<FormMessage id="email-error">{errors.email}</FormMessage>
```

---

## チェックリスト

### M3準拠
- [ ] コンポーネント状態8種定義（Default/Hover/Focus/Active/Disabled/Loading/Error/Success）
- [ ] デザイントークン使用
- [ ] スペーシング4pxベース

### WCAG 2.2 AA
- [ ] コントラスト比4.5:1以上（通常テキスト）
- [ ] 全機能がキーボード操作可能
- [ ] フォーカス表示が明確（2px以上のリング）
- [ ] タッチターゲット44x44px以上
- [ ] 画像に代替テキスト（alt）
- [ ] フォームにラベル（label/aria-label）
- [ ] エラーメッセージが明確
- [ ] 色だけに依存しない情報伝達

### Nielsen 10原則
- [ ] システム状態の可視化
- [ ] 自然な言葉使用
- [ ] 元に戻す/キャンセル機能
- [ ] 一貫性のあるデザイン
- [ ] エラー防止機能
- [ ] アイコン + ラベル
- [ ] ショートカット提供
- [ ] ミニマルデザイン
- [ ] 明確なエラーメッセージ
- [ ] ヘルプ/ツールチップ

---

## ツール

**コントラストチェッカー**: [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
**アクセシビリティ検証**: axe DevTools（Chrome拡張）、Lighthouse（Chrome DevTools）
**デザイントークン管理**: Tailwind CSS設定、CSS Variables
