# 未使用コード検出・削除ガイド

TypeScript + React (Next.js App Router) 向け。

---

## 対象・除外

| 項目 | 内容 |
|------|------|
| 対象 | 未使用の `const` / `function`（ローカル・エクスポート）<br>拡張子: `.ts`, `.tsx` |
| 除外 | Next.js 予約エクスポート: `metadata`, `dynamic`, `revalidate`, `generateMetadata`, `GET/POST` 等<br>バレルファイル（`index.ts`）<br>`_` プレフィックス付き識別子 |

---

## ツール設定

| ツール | 設定 | 機能 |
|--------|------|------|
| ESLint | `eslint-plugin-unused-imports` | import 未使用を自動削除 |
| ESLint | `@typescript-eslint/no-unused-vars` | 変数/関数の未使用を検出（`_` は無視） |
| TypeScript | `noUnusedLocals: true`<br>`noUnusedParameters: false` | コンパイラレベルでチェック |
| ts-prune | - | 未使用エクスポート候補抽出 |
| ts-unused-exports | - | プロジェクト単位で未使用検出 |

---

## 削除ポリシー

| 分類 | 対象 | 削除方法 |
|------|------|----------|
| 自動削除可 | import の未使用<br>副作用のないローカル `const`/`let` | `eslint --fix` で自動削除 |
| 半自動（人間確認） | 未使用 `function` 宣言<br>未使用 `export`<br>React コンポーネント | ツールで検出 → 人間が判断 |
| 削除禁止 | Next.js 予約エクスポート<br>公開 API（packages/* の外部公開） | 誤検出を除外設定 |

---

## 実行手順

| ステップ | 内容 |
|---------|------|
| 1. ESLint | `eslint --fix` で import 自動削除 |
| 2. ts-prune | 未使用 export 候補収集 |
| 3. 除外 | Next.js 予約名を除外 |
| 4. 削除 | ローカル未使用 `const`/`function` を削除 |
| 5. 確認 | `tsc --noEmit` で型チェック確認 |

---

## セーフティ

| 項目 | 対策 |
|------|------|
| ブランチ | 新規ブランチで実施 |
| 確認 | コミット前に差分目視確認 |
| 意図的未使用 | `_` プレフィックス |
