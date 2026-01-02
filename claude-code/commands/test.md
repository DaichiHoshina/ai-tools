---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_file, mcp__serena__find_referencing_symbols, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__insert_after_symbol, mcp__serena__insert_before_symbol, mcp__serena__list_dir, mcp__serena__read_memory, mcp__serena__replace_regex, mcp__serena__replace_symbol_body, mcp__serena__search_for_pattern, mcp__serena__write_memory, mcp__context7__resolve-library-id, mcp__context7__get-library-docs
description: テスト作成専用モード - 既存コードに対するテストを作成
---

## /test - テスト作成モード

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
- `test-quality-review` - テスト品質チェック
- `type-safety-review` - テスト型安全性

**自動レビュー:**
テスト作成後、`test-quality-review` Skillを自動実行:
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

- 全テスト成功 → `/review` or `/commit`
- テスト失敗 → `/debug` で原因特定
- カバレッジ不足 → 追加テスト作成

Serena MCP でコード分析。モックは必要最小限に。
