---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
name: doc-sync
description: DD / PRD / local-docs の整合性チェックと差分吸収。「再度DD読み込んで」「PRDとの整合性チェック」「local-docsに反映」「DDとPRDが合っているか確認」「整合性を取れているか」等で使用する。
---

# doc-sync

Cross-check consistency between DD / PRD / local-docs and absorb discrepancies.

## Activation

Auto-fires on any of:

- 「再度DD読み込んで」「PRDとの整合性チェック」「local-docsに反映」「DDとPRDが合っているか確認」「整合性を取れているか」
- Mid-`/flow` check when changes since last sync are suspected

## Phase 1: Identify targets

```bash
git log --since=7.days --name-only --format="" | grep -E "\.(md|html)$" | sort -u
```

User-specified paths take priority.

## Phase 2: Diff check (parallel)

3+ files → dispatch `explore-agent` in parallel. 1-2 files → inline read.

| Check | Criteria |
|------|---------|
| Numeric alignment | Counts / dates / limits match across all docs |
| Term consistency | Same concept uses same name everywhere |
| Status alignment | DD/PRD phase matches local-docs last update |
| Missing sections | DD findings not reflected in local-docs |

## Phase 3: Absorb discrepancies

On finding discrepancies:

1. Present diff list (filename / line / content)
2. Confirm fix targets and method before executing
3. Update local-docs via `/local-docs update {path}` skill

No discrepancies → report `整合性 OK: {N} ファイル間で不整合なし` and stop.

## Output format

```
## 整合性チェック結果 (YYYY-MM-DD)

確認対象: {file list}

### 不整合 ({N}件)
- {fileA} ↔ {fileB}: {detail}

### 対応済み
- なし / {N}件修正

次のアクション: {action or 「対応不要」}
```
