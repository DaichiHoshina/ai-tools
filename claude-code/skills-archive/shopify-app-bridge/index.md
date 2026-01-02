---
name: shopify-app-bridge
description: Shopify App Bridge v4 開発 - Toast/Redirect/Loading API、iframe制約、マイグレーション対応
requires-guidelines:
  - typescript
---

# Shopify App Bridge v4 開発スキル

Shopify 埋め込みアプリ開発時に読み込む。App Bridge v4 の API 使用方法と iframe 内での制約に対応。

## 読み込むガイドライン

- `~/.claude/guidelines/integrations/shopify-app-bridge-v4.md`

## 主な対応内容

### API 使用

- Toast: `shopify.toast.show(message, options)`
- Redirect: `shopify.redirect.dispatch({ url })`
- Loading: `shopify.loading(true/false)`
- ID Token: `await shopify.idToken()`

### iframe 制約対応

- `window.location.href` で admin.shopify.com へ遷移不可
- X-Frame-Options: DENY によるブロック
- `shopify.redirect.dispatch()` を使用して回避

### v3 → v4 マイグレーション

- `createApp()` 初期化不要
- `app.dispatch()` → `shopify.xxx()` 直接呼び出し
- Web Components ベースの Modal

## 使用例

### Toast 表示

```typescript
shopify.toast.show('保存しました');
shopify.toast.show('エラー', { isError: true });
```

### サブスクリプション承認リダイレクト

```typescript
// ❌ NG
window.location.href = confirmationUrl;

// ✅ OK
const shopify = window.shopify;
if (shopify) {
  shopify.redirect.dispatch({ url: confirmationUrl });
}
```

## 参考

- [App Bridge Library](https://shopify.dev/docs/api/app-bridge-library)
- [Migration Guide](https://shopify.dev/docs/api/app-bridge/migration-guide)
