---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
name: doc-sync
description: DD / PRD / local-docs の整合性 check と差分吸収。「再度DD読んで」「整合性チェックして」で起動。
---

# doc-sync

Cross-check consistency between DD / PRD / local-docs and absorb discrepancies.

## Activation

Auto-fires on any of:

- 「再度DD読んで」「再度DD読み込んで」「再度DDと比較して」「再度DDとの整合性チェック」「DDと比較して整合性大丈夫か」「DDとPRDが合っているか」
- 「PRDとの整合性チェック」「整合性チェックして」「整合性取れているか」「local-docsに反映」
- 「再度コメント読み込み」「再度コメント読んで」(PR/Issue comment 再読込)
- 短縮・口語形 (「再度」prefix なしの初回読込も含む): 「dd調べて」「DD調べて」「DD読んで」「PRとDDを読み込んで」「DDを全部読み込んで」「整合性が取れるように」「整合取れてる」「dd見て」。大文字小文字は問わない (dd / DD 双方)
- spec / 設計変更の反映系: 「spec 更新を local-docs に吸収」「設計変更を doc に反映して」「spec と local-docs を合わせて」
- 実装変更後の doc 追跡系: 「実装が変わったので doc も更新して」「コードが変わったので DD も更新」「実装に合わせて local-docs を更新して」
- memory 突合系: 「memory も含めて整合性」「memory と doc の整合」(memory = `~/ai-tools/memory/` または repo 配下 `memory/` の md file。Serena `.serena/memories/` と `~/.claude/projects/` 配下は照合対象外)
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
