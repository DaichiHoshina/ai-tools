# Claude Rules Authoring

`.claude/rules/*.md` ファイルの作成規約。

## Frontmatter

- `paths` フィールド必須（該当ファイル編集時のみ読み込むよう制限）
- 本プロジェクトでは `paths` のみ使用する（他のフィールドは追加しない）

```markdown
---
paths:
  - "**/*.go"
---

# Rule Title
```

## 原則

- rules/skills ファイル本文は英語で記述（ガイドラインファイル自体は日本語可）
- プロジェクト固有ロジックは `paths` で対象ファイルを絞る
- 汎用ルールは `~/.claude/guidelines/` に配置し rules/ との重複を避ける
