---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
name: doc-sync
description: DD / PRD / local-docs の整合性チェックと差分吸収。「再度DD読んで」「再度DDと比較して」「整合性チェックして」「整合性大丈夫か」「DDとPRDが合っているか」「local-docsに反映」「再度コメント読み込み」等で使用する。
---

# doc-sync

Cross-check consistency between DD / PRD / local-docs and absorb discrepancies.

## Activation

Auto-fires on any of:

- 「再度DD読んで」「再度DD読み込んで」「再度DDと比較して」「再度DDとの整合性チェック」「DDと比較して整合性大丈夫か」「DDとPRDが合っているか」
- 「PRDとの整合性チェック」「整合性チェックして」「整合性取れているか」「local-docsに反映」
- 「再度コメント読み込み」「再度コメント読んで」(PR/Issue comment 再読込)
- Mid-`/flow` check when changes since last sync are suspected
- correction prefix 「違う、」「再度」を受けた場合は、直前 task 結果と現状の diff を 1 行 echo してから着手する (差分を明示することで再認識ループを短縮する)

> 「PR最新化」「最新 main を取り込んで」は git rebase / merge 系で doc-sync 対象外。`git merge --ff-only main` 等を案内する。

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
