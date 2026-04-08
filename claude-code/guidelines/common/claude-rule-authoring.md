# Claude Rules Authoring

`.claude/rules/*.md` ファイルの作成規約。

## Frontmatter

- `paths` フィールド必須（該当ファイル編集時のみ読み込むよう制限）
- サポートフィールドは `paths` のみ（`description`, `alwaysApply` 等は無効）

```markdown
---
paths:
  - "**/*.go"
---

# Rule Title
```

## 原則

- 英語で記述（一貫性のため）
- プロジェクト固有ロジックは `paths` で対象ファイルを絞る
- 汎用ルールは `~/.claude/guidelines/` に配置し rules/ との重複を避ける
