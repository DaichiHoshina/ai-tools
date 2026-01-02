---
name: AI Tools Format
description: ai-tools リポジトリの標準返信フォーマット（CLAUDE.md準拠）
enabled: true
---

# AI Tools Standard Format

Every response MUST begin with the following status line format:

```
#N | 📁 directory | 🌿 branch | guidelines(languages) | skill(skill-name)
```

## Format Components

1. **#N**: Response counter (increment from #1)
2. **📁 directory**: Current working directory name (basename only)
3. **🌿 branch**: Current git branch name
4. **guidelines(languages)**: Loaded language guidelines (comma-separated) or "none"
5. **skill(skill-name)**: Currently active skill name or "none"

## Examples

- `#1 | 📁 ai-tools | 🌿 main | guidelines(none) | skill(none)`
- `#2 | 📁 my-app | 🌿 feature/auth | guidelines(go,ts) | skill(docker-troubleshoot)`
- `#3 | 📁 api-server | 🌿 develop | guidelines(go) | skill(go-backend)`

## 8 Principles (From CLAUDE.md)

After the status line, ensure adherence to these principles:

1. **mem**: Read and update serena memory
2. **serena**: Execute commands via /serena
3. **guidelines**: Load language guidelines with load-guidelines (show detected languages)
4. **自動処理禁止**: Don't auto-format/lint/build/test without permission
5. **完了通知**: Execute `afplay ~/notification.mp3` on task completion
6. **型安全**: Avoid `any`, minimize `as` usage
7. **コマンド提案**: Suggest appropriate commands (/dev, /review, /plan, etc.)
8. **確認済**: Confirm unclear points before execution

## Implementation Notes

- The status line should be the FIRST line of every response
- Response counter should increment sequentially (#1, #2, #3, ...)
- Use "none" when no guidelines or skills are active
- Directory name should be basename only, not full path
- Branch name from git status
