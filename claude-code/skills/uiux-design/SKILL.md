---
name: uiux-design
description: UI/UXデザインレビュー - Material Design 3 + WCAG 2.2 AA + Nielsen 10原則で実装に直結するレビュー
requires-guidelines:
  - uiux
  - nextjs-react
  - tailwind
  - shadcn
---

# UI/UXデザインレビュー

## 使用タイミング

- **UIコンポーネント実装時**
- **アクセシビリティチェック時**
- **デザインシステム構築時**
- **レビュー・改善提案時**

---

## 鉄板3原則レビュー（優先順）

### 1️⃣ Material Design 3（コンポーネント実装）⭐

**レビュー観点**:
- コンポーネント状態の完全性（8種：default, hover, focus, active, disabled, loading, error, success）
- デザイントークンの一貫性
- スペーシング（4pxベース）

### 2️⃣ WCAG 2.2 AA（アクセシビリティ）⭐

**レビュー観点**:
- コントラスト比（4.5:1以上）
- キーボード操作（Tab/Enter/Escape）
- フォーカス表示（2px以上のリング）
- タッチターゲット（44x44px以上）

### 3️⃣ Nielsen 10原則（ユーザビリティ）⭐

**レビュー観点**:
- システム状態の可視化
- 一貫性と標準
- エラー防止と回復

---

## レビュー手順

### Step 1: Material Design 3チェック

#### 🔴 Critical: コンポーネント状態未定義

```tsx
// ❌ 危険: 状態定義が不完全
<button className="bg-primary text-white">
  保存
</button>

// ✅ 正しい: 全状態を定義
<button className="
  bg-primary text-white                // Default
  hover:bg-primary/90                  // Hover
  focus:ring-2 focus:ring-primary      // Focus
  active:bg-primary/80                 // Active
  disabled:opacity-50                  // Disabled
  disabled:cursor-not-allowed
">
  {isLoading ? <Spinner /> : '保存'}  // Loading
</button>
```

#### 🟡 Warning: デザイントークン不使用

```tsx
// ⚠️ カスタムカラーの乱用
<button className="bg-[#6750A4]">保存</button>

// ✅ デザイントークン使用
<button className="bg-primary">保存</button>
```

### Step 2: WCAG 2.2 AAチェック

#### 🔴 Critical: コントラスト比不足

```tsx
// ❌ 危険: コントラスト比2:1程度（WCAG違反）
<p className="text-gray-300 bg-gray-200">テキスト</p>

// ✅ 正しい: 4.5:1以上
<p className="text-gray-900 bg-white">テキスト</p>
```

**測定方法**:
```bash
# WebAIM Contrast Checkerで確認
https://webaim.org/resources/contrastchecker/
```

#### 🔴 Critical: キーボード操作不可

```tsx
// ❌ 危険: キーボード操作不可
<div onClick={handleClick}>クリック</div>

// ✅ 正しい: セマンティックHTML
<button type="button" onClick={handleClick}>
  クリック
</button>
```

#### 🔴 Critical: フォーカス表示なし

```tsx
// ❌ 危険: フォーカス表示削除
<button className="outline-none">保存</button>

// ✅ 正しい: 明確なフォーカスリング
<button className="
  focus:outline-none
  focus:ring-2
  focus:ring-primary
  focus:ring-offset-2
">
  保存
</button>
```

#### 🔴 Critical: タッチターゲット不足

```tsx
// ❌ 危険: 24x24px（小さすぎ）
<button className="h-6 w-6 p-1">×</button>

// ✅ 正しい: 44x44px以上
<button className="min-h-[44px] min-w-[44px] p-2">×</button>
```

#### 🔴 Critical: フォームラベルなし

```tsx
// ❌ 危険: ラベルなし
<input type="email" placeholder="メールアドレス" />

// ✅ 正しい: ラベル紐付け
<Label htmlFor="email">メールアドレス</Label>
<Input id="email" type="email" />
```

### Step 3: Nielsen 10原則チェック

#### 1. Visibility of System Status（システム状態の可視化）

```tsx
// ❌ ローディング状態が不明
<Button onClick={save}>保存</Button>

// ✅ 状態を表示
<Button disabled={isLoading}>
  {isLoading ? <Spinner /> : '保存'}
</Button>
```

#### 2. Match Between System and Real World（現実世界とのマッチ）

```tsx
// ⚠️ 技術用語
<Button>Commit</Button>

// ✅ 自然な言葉
<Button>保存</Button>
```

#### 3. User Control and Freedom（ユーザー制御と自由）

```tsx
// ⚠️ キャンセルできない
<Dialog>
  <DialogContent>...</DialogContent>
</Dialog>

// ✅ キャンセル可能
<Dialog>
  <DialogContent>
    <DialogClose>キャンセル</DialogClose>
  </DialogContent>
</Dialog>
```

#### 4. Consistency and Standards（一貫性と標準）

```tsx
// ⚠️ 不統一なボタン
<button className="bg-blue-500">保存</button>
<button className="bg-green-600">送信</button>

// ✅ 統一されたvariant
<Button variant="default">保存</Button>
<Button variant="default">送信</Button>
```

#### 5. Error Prevention（エラー防止）

```tsx
// ⚠️ 確認なし削除
<Button onClick={deleteUser}>削除</Button>

// ✅ 確認ダイアログ
<AlertDialog>
  <AlertDialogTrigger>削除</AlertDialogTrigger>
  <AlertDialogContent>
    <AlertDialogTitle>本当に削除しますか？</AlertDialogTitle>
  </AlertDialogContent>
</AlertDialog>
```

#### 6. Recognition Rather Than Recall（再認識 > 想起）

```tsx
// ⚠️ アイコンのみ
<Button><TrashIcon /></Button>

// ✅ アイコン + ラベル
<Button>
  <TrashIcon />
  削除
</Button>
```

#### 7. Flexibility and Efficiency of Use（柔軟性と効率性）

```tsx
// ✅ ショートカット提供
<div className="text-sm text-muted-foreground">
  Ctrl+S で保存
</div>
```

#### 8. Aesthetic and Minimalist Design（美的でミニマルな設計）

```tsx
// ⚠️ 情報過多
<Card>
  <CardHeader>...</CardHeader>
  <CardContent>...</CardContent>
  <CardFooter>...</CardFooter>
  <CardExtra>...</CardExtra>  // 不要
</Card>

// ✅ 必要な情報のみ
<Card>
  <CardHeader>...</CardHeader>
  <CardContent>...</CardContent>
</Card>
```

#### 9. Help Users Recognize, Diagnose, and Recover from Errors（エラー認識・診断・回復支援）

```tsx
// ⚠️ 曖昧なエラー
<FormMessage>エラーが発生しました</FormMessage>

// ✅ 具体的なエラー
<FormMessage>
  メールアドレスの形式が正しくありません。
  例: user@example.com
</FormMessage>
```

#### 10. Help and Documentation（ヘルプとドキュメント）

```tsx
// ✅ ツールチップで説明
<Tooltip>
  <TooltipTrigger>
    <InfoIcon />
  </TooltipTrigger>
  <TooltipContent>
    この機能は...
  </TooltipContent>
</Tooltip>
```

---

## チェックリスト

### Material Design 3
- [ ] コンポーネント状態8種定義（default, hover, focus, active, disabled, loading, error, success）
- [ ] デザイントークン使用（primary, secondary, error, success）
- [ ] スペーシング4pxベース（4, 8, 12, 16, 24, 32, 48）
- [ ] 角丸M3準拠（sm:8px, md:12px, lg:16px）

### WCAG 2.2 AA
- [ ] コントラスト比4.5:1以上（通常テキスト）
- [ ] コントラスト比3:1以上（UIコンポーネント）
- [ ] キーボード操作可能（Tab, Enter, Escape）
- [ ] フォーカス表示明確（2px以上のリング）
- [ ] タッチターゲット44x44px以上
- [ ] 画像にalt属性
- [ ] フォームにlabel要素
- [ ] 色だけに依存しない情報伝達

### Nielsen 10原則
- [ ] 1. システム状態の可視化（Loading, Progress）
- [ ] 2. 現実世界とのマッチ（自然な言葉）
- [ ] 3. ユーザー制御と自由（Undo, Cancel）
- [ ] 4. 一貫性と標準（統一されたUI）
- [ ] 5. エラー防止（確認ダイアログ）
- [ ] 6. 再認識 > 想起（アイコン+ラベル）
- [ ] 7. 柔軟性と効率性（ショートカット）
- [ ] 8. 美的でミニマル（情報過多を避ける）
- [ ] 9. エラー認識・診断・回復（具体的なメッセージ）
- [ ] 10. ヘルプとドキュメント（ツールチップ）

---

## 出力形式

### レビュー結果

```
## UI/UXレビュー結果

### 1️⃣ Material Design 3

🔴 **Critical**: `Button.tsx:15` - コンポーネント状態未定義
- 問題: hover/focus/disabled状態が未定義
- 修正案: [コード例]

🟡 **Warning**: `Card.tsx:8` - デザイントークン不使用
- 問題: カスタムカラー#6750A4を直接指定
- 改善案: bg-primary使用

### 2️⃣ WCAG 2.2 AA

🔴 **Critical**: `Form.tsx:42` - フォームラベルなし
- 問題: input要素にlabel紐付けなし
- 修正案: [コード例]

🔴 **Critical**: `Hero.tsx:20` - コントラスト比不足
- 問題: text-gray-300 on bg-gray-200 (2.1:1)
- 修正案: text-gray-900使用（7:1）

### 3️⃣ Nielsen 10原則

🟡 **Warning**: `DeleteButton.tsx:5` - エラー防止不足
- 問題: 確認なしで削除実行（原則5違反）
- 改善案: AlertDialog追加

📊 **Summary**:
- Material Design 3: Critical 1件 / Warning 1件
- WCAG 2.2 AA: Critical 2件 / Warning 0件
- Nielsen 10原則: Warning 1件

✅ **総合評価**: Critical問題を優先的に修正してください
```

---

## プロジェクト別対応

### 管理画面（SaaS）

**追加チェック**:
- デジタル庁デザインシステム参照
- 日本語文言の適切性
- フォーム設計パターン

### 一般ユーザー向けWebサービス

**追加チェック**:
- M3 Expressive活用
- 視覚的魅力（シェイプ、モーション）
- LP/マーケティングサイト最適化

---

## 関連ガイドライン

レビュー実施前に以下を参照:
- `~/.claude/guidelines/design/ui-ux-guidelines.md` - 鉄板3原則詳細
- `~/.claude/guidelines/languages/nextjs-react.md` - React実装パターン
- `~/.claude/guidelines/languages/tailwind.md` - Tailwind CSS v4
- `~/.claude/guidelines/languages/shadcn.md` - shadcn/ui v2.5

---

## 外部知識ベース

最新情報確認には context7 を活用:
- [Material Design 3](https://m3.material.io/)
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [Nielsen Norman Group](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [デジタル庁デザインシステム](https://design.digital.go.jp/)
- shadcn/ui公式
- Radix UI（アクセシビリティパターン）

---

## 実装例テンプレート（そのまま使える）

### ボタン完全実装

```tsx
<Button
  variant="default"
  disabled={isLoading}
  className="
    min-h-[44px]                          // WCAG: タッチターゲット
    focus:ring-2 focus:ring-primary       // WCAG: フォーカス表示
    focus:ring-offset-2
    disabled:opacity-50                   // M3: Disabled状態
    disabled:cursor-not-allowed
    hover:bg-primary/90                   // M3: Hover状態
    active:bg-primary/80                  // M3: Active状態
  "
>
  {isLoading ? <Spinner /> : '保存'}     // Nielsen: 状態の可視化
</Button>
```

### フォーム完全実装

```tsx
<form>
  <div className="space-y-4">              {/* M3: スペーシング4pxベース */}
    <div>
      <Label htmlFor="email">              {/* WCAG: ラベル必須 */}
        メールアドレス
      </Label>
      <Input
        id="email"
        type="email"
        required
        aria-describedby="email-error"     {/* WCAG: エラー紐付け */}
        className="
          min-h-[44px]                     // WCAG: タッチターゲット
          focus:ring-2 focus:ring-primary  // WCAG: フォーカス表示
        "
      />
      {errors.email && (
        <FormMessage id="email-error">     {/* Nielsen: エラー診断 */}
          メールアドレスの形式が正しくありません
        </FormMessage>
      )}
    </div>
  </div>
</form>
```
