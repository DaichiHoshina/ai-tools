---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: テスト作成専用モード - 既存コードに対するテストを作成
---

## /test - テスト作成モード

## protection-mode

`/flow` 経由時は自動適用。単独実行時もファイル変更を伴う場合は `Skill("protection-mode")` を推奨。

## Step 0: ガイドライン自動読み込み（必須）

テスト作成前に必要なガイドラインを読み込む:

### A. 共通ガイドライン（必須）
```
requires-guidelines:
  - common/testing-guidelines.md
```

**読み込み:**
- `~/.claude/guidelines/common/testing-guidelines.md` - テスト指針・パターン

### B. 言語ガイドライン
`load-guidelines` スキルで自動検出:
- TypeScript → `typescript.md`（テスト型定義）
- Go → `golang.md`（テーブル駆動テスト）
- Next.js → `nextjs-react.md`（React Testing Library）

### C. Skill連携
以下のSkillが自動的にガイドラインを読み込み:
- `comprehensive-review --focus=docs` - テスト・ドキュメント品質チェック（Phase 2-5で統合済み、旧スキル名も動作）
- `comprehensive-review --focus=quality` - テスト型安全性・構造品質（Phase 2-5で統合済み、旧スキル名も動作）

詳細は [SKILL-MIGRATION.md](../SKILL-MIGRATION.md) 参照。

**自動レビュー:**
テスト作成後、`comprehensive-review --focus=docs` Skillを自動実行:
- テストの意味チェック
- カバレッジ分析
- モック適切性
- テスタビリティ評価

## フロー

1. **ガイドライン読み込み** - 上記Step 0を実行
2. **対象分析** - Serena MCP で関数シグネチャ、依存関係、エッジケース特定
3. **テスト設計** - 正常系、異常系、境界値、エッジケース
4. **実装** - AAA パターン（Arrange-Act-Assert）
5. **品質レビュー** - `test-quality-review` Skill自動実行
6. **実行・レポート** - カバレッジ含む結果出力

## AAA パターン（必須）

```typescript
test('should do something', () => {
  // Arrange
  const input = createTestData();
  // Act
  const result = targetFunction(input);
  // Assert
  expect(result).toBe(expected);
});
```

## カバレッジ目標

- 最低: 70% / 推奨: 80% / 理想: 90%+

## 次のアクション

```
/test 完了
  → /review（コードレビュー）
  → /commit-push-pr or /commit-push-main（Git操作）
  → テスト失敗時: /debug
  → カバレッジ不足: 追加テスト作成
```

## 関連コマンド

| コマンド | 関係 |
|---------|------|
| `/dev` | 実装後にテスト作成する場合の前段 |
| `/tdd` | テスト駆動開発。先にテストを書く場合はこちら |
| `/lint-test` | CI相当チェック。テスト実行を含む |

Serena MCP でコード分析。モックは必要最小限に。
