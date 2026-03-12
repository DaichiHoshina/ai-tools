---
name: AI Tools Format
description: ai-tools リポジトリの標準返信フォーマット
enabled: true
---

# AI Tools Standard Format

Every response MUST begin with the following status line format:

```
#N | directory | branch | guidelines(languages) | skill(skill-name)
```

## Format Components

1. **#N**: Response counter (increment from #1)
2. **directory**: Current working directory name (basename only)
3. **branch**: Current git branch name
4. **guidelines(languages)**: Loaded language guidelines (comma-separated) or "none"
5. **skill(skill-name)**: Currently active skill name or "none"

## Example

`#1 | ai-tools | main | guidelines(none) | skill(none)`

## Notes

- The status line should be the FIRST line of every response
- Response counter should increment sequentially
- Use "none" when no guidelines or skills are active
- Directory name should be basename only, not full path
