# Claude Skill Authoring

`.claude/skills/*/SKILL.md` ファイルの作成規約。

## Frontmatter

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `name` | 必須 | ケバブケース識別子 |
| `description` | 必須 | 目的と使用タイミング（スキル一覧表示・選択判断に使用） |
| `user-invocable` | 任意 | `true` でユーザーが `/<name>` で直接呼び出し可能 |

```markdown
---
name: my-skill
description: Brief description of what this skill does and when to use it.
user-invocable: false
---
```

## 原則

- スキルファイル本文は英語で記述（ガイドラインファイル自体は日本語可）
- `description` には「何をするか」と「いつ使うか」を明記
- ユーザー呼び出しスキルと内部スキルを `user-invocable` で区別
