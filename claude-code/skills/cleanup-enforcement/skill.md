---
name: cleanup-enforcement
description: コードクリーンアップ強制 - 後方互換残骸・未使用コード・進捗コメントを徹底削除
requires-guidelines:
  - common
  - typescript  # lang=typescript の場合
  - golang  # lang=go の場合
---

# cleanup-enforcement - コードクリーンアップ強制

## 使用タイミング

- 実装完了後のコードクリーンアップ時
- リファクタリング後の不要コード除去時
- PR作成前の最終チェック時

## 目的

CLAUDE.mdやコマンドで書いても従わない「削除系」の指示を強制する。

## 強制削除ルール

### 1. 未使用コードの即時削除

- 未使用の import 文
- 未使用の変数・定数
- 未使用の関数・メソッド
- 未使用の型定義・interface

**判断基準**: IDE/Linterが警告を出すものは全て削除

### 2. 後方互換残骸の禁止

以下のパターンは**絶対禁止**:

```typescript
// ❌ 禁止: 未使用の旧名エクスポート
export { newName as oldName }

// ❌ 禁止: _prefix で未使用マーク
const _deprecatedValue = ...

// ❌ 禁止: 後方互換のためだけの re-export
export * from './legacy'
```

**対応**: 発見次第、削除する。使用箇所があれば同時に修正。

### 3. 進捗コメントの禁止

以下のコメントは**絶対禁止**:

```typescript
// ❌ 禁止
// 実装した
// 完了
// TODO: remove later
// FIXME: temporary
// 2024-01-15: added this

// ✅ 許可（理由の説明）
// Workaround for Chrome bug #12345
// Required by external API specification
```

### 4. YAGNI違反の検出と削除

以下は**過剰な実装**として削除対象：

```typescript
// ❌ 禁止: 1回だけ呼ばれるヘルパー
function formatUserName(name: string) { return name.trim() }
// → 呼び出し元で直接 name.trim() を使用

// ❌ 禁止: 使われていない抽象化
interface IUserRepository { /* 実装が1つだけ */ }
// → 実装が1つだけなら interface 不要

// ❌ 禁止: 過剰な設定可能性
function createUser(config: { enableCache?: boolean, enableLog?: boolean })
// → 現時点で使わない設定は削除

// ❌ 禁止: 未来のための準備
class UserService {
  // future: support for multiple auth providers
  async login(provider: 'google' | 'facebook') { /* google のみ実装 */ }
}
// → 現在サポートしていない機能は削除
```

**判断基準**:
- ヘルパー関数が1箇所からのみ呼ばれている → インライン化
- 抽象化（interface/abstract class）の実装が1つだけ → 削除
- 設定オプションで未使用のもの → 削除
- コメントで「将来」「予定」と書かれている機能 → 削除

### 5. 削除すべきもの

| 対象 | アクション |
|------|-----------|
| 空のファイル | 削除 |
| 空の関数/クラス | 削除（スタブ以外） |
| コメントアウトされたコード | 削除 |
| console.log / print デバッグ | 削除 |
| 到達不能コード | 削除 |

## 適用タイミング

- `/dev` 実装完了時
- `/refactor` 完了時
- `/review` で問題検出時

## 出力フォーマット

```
## Cleanup Report

### 削除済み
- ✅ 未使用import 3件削除
- ✅ 未使用変数 `oldConfig` 削除
- ✅ 進捗コメント 2件削除

### 確認が必要
- ⚠️ `legacyHandler` は外部から参照されている可能性あり

### 統計
- 削除行数: -45 lines
- 削除ファイル: 0
```

## 注意事項

- **迷ったら削除**: 必要になったらgit履歴から復元できる
- **依存関係確認**: 削除前に `find_referencing_symbols` で参照確認
- **テスト実行**: 削除後は必ずテスト実行
