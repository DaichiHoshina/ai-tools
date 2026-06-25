---
allowed-tools: Bash, Read, Edit
name: local-docs-cleanup
description: local-docs の released プロジェクトを cleanup する。archive 送り候補をスキャンして確認リストを提示し、承認後に ../local-docs-archive/ へ移動する。「local-docs cleanup」「archive に送って」「不要な doc を整理」「released プロジェクトの cleanup」等で使用する。
---

# local-docs-cleanup

Organize released project docs following STRUCTURE.md cleanup rules. **No deletion — archive move only**.

## Invocation

```
/local-docs-cleanup {project-dir}   # cleanup specific project
/local-docs-cleanup --all           # scan all released projects
```

## Steps

### 1. Load prerequisites (required)

```bash
Read("{local-docs-root}/STRUCTURE.md")  # primary source for cleanup rules
```

Do not rely on skill memory for "keep" / "archive" criteria — always derive from STRUCTURE.md.

### 2. Identify targets

With argument: use the specified directory. With `--all`: detect README.html files containing `<!-- status: released -->` under `projects/`.

```bash
grep -rl "status: released" {local-docs-root}/projects/*/README.html 2>/dev/null
```

### 3. Scan and classify

Classify all HTML files under target projects using STRUCTURE.md cleanup rules.

**Keep (maintain in repo)**:
- RCA / postmortem / lessons-learned
- Runbooks / specs still in active use
- Docs likely referenced as decision basis in future
- Specs already extracted or candidates for domain-specs/

**Archive candidates**:
- Intermediate plans / design notes under `planning/`
- Individual `verification/rehearsal/` logs (skip if series summary exists)
- `inbox/` remnants
- `notion-drafts/` (presumed migrated)
- Duplicate summaries / drafts (keep newer, archive older)
- Files duplicating README (e.g. `active-readme.html`)

**Needs review (user judgment)**:
- Files requiring content read to decide
- Files potentially referenced by other projects

### 4. Present confirmation list

Output in this format and wait for user approval.

```
## cleanup 候補 — {project-dir}

### archive 送り (自動判定)
- planning/db-migration/rehearsal.html — 中間リハーサルログ
- verification/rehearsal/result-20260529.html — シリーズ summary あり

### 要確認 (内容次第)
- post-release/related/other-pj.html — 他 PJ 参照、まだ必要か？

### 残す
- post-release/rca/deadlock-rca.html — RCA、継続参照価値あり
- lessons-learned.html — lessons-learned、維持

OK なら「実行して」と返してください。
個別変更は「X は残す / Y も archive」等で指示してください。
```

### 5. Archive move (only after approval)

Do not run `mv` before receiving explicit approval.

```bash
ARCHIVE_DIR="{local-docs-root}/../local-docs-archive/$(date +%Y%m%d)-{project-name}"
mkdir -p "$ARCHIVE_DIR/{元のサブパス}"
mv "{local-docs-root}/projects/{target}" "$ARCHIVE_DIR/{target}"
```

After move:
1. Run `node {local-docs-root}/_index/build.mjs` to rebuild index
2. Report move count and remaining count

### 6. Update README

Append 1 line to the project's `README.html` recording cleanup date and move count.

## Constraints

- **No deletion**: do not use `rm`. Move everything to `../local-docs-archive/`
- **Approval required**: do not `mv` without explicit confirmation on the list
- **Out of scope**: `_index/` / `_templates/` / `domain-specs/` / `tool-guides/` / `operations/`
- **Archive destination**: `{local-docs-root}/../local-docs-archive/`

## Related

- `mem:local-docs` — local-docs skill (new doc creation)
- local-docs `STRUCTURE.md` — primary source for cleanup rules (`## PJ released 後の cleanup レビュー` section)
