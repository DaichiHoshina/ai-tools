# AI開発ルール（要約版）

> **目的**: AIにコードを作らせる際の品質保証と一貫性確保

---

## 📌 鉄則3原則（最重要）

### 1. YAGNI（You Aren't Gonna Need It）を徹底

**禁止**:
- 「将来使うかも」の機能実装
- 過度な汎用化・抽象化
- 不要なデザインパターンの適用

**許可**:
- 今必要な機能のみ実装
- 3回目の重複で初めて共通化検討

**例**:
```typescript
// ❌ 悪い例: 過度な汎用化
class GenericDataProcessor<T, U, V> {
  process(data: T, transformer: (t: T) => U, validator: (u: U) => V): V

 {
    // 複雑な汎用ロジック
  }
}

// ✅ 良い例: シンプル
class UserDataProcessor {
  process(userData: UserData): ProcessedUserData {
    // シンプルなロジック
  }
}
```

---

### 2. 実装前の確認（必須フロー）

**手順**:
1. 実装計画を提示
2. アプローチを説明
3. 影響範囲を明示
4. ユーザーの承認を得る

**Guard関手での分類**:
- **Safe射（即実行）**: 読み取り、分析、提案
- **Boundary射（要確認）**: 実装、ファイル編集、設定変更
- **Forbidden射（拒否）**: YAGNI違反、過度な抽象化

---

### 3. 既存パターンの踏襲

**AIは新しいコードを書く前に**:
1. 既存のコードベースを分析（Serena MCP使用）
2. 既存のパターンを特定
3. 同じパターンで実装

**新しいパターンは必ずユーザーに確認**

---

## 📊 実装チェックリスト（簡略版）

### 実装前
- [ ] 既存パターンを確認
- [ ] YAGNI違反がないか確認
- [ ] 実装計画をユーザーに提示
- [ ] ユーザーの承認を得る

### 実装中
- [ ] 段階的に実装（一度に全部実装しない）
- [ ] TodoWrite で進捗を管理
- [ ] エラーが発生したら即座に報告

### 実装後
- [ ] すべてのテストが通ることを確認
- [ ] デグレがないことを確認
- [ ] セキュリティチェック（SQLインジェクション、XSS等）
- [ ] コードレビュー（`/review` コマンド）

---

## 参考

詳細は以下のガイドラインを参照:
- `guidelines/common/code-quality-design.md` - SRP、関数サイズ等
- `guidelines/common/type-safety-principles.md` - 型安全性
- `guidelines/common/testing-guidelines.md` - テスト戦略
