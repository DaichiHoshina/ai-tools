---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, mcp__context7__*, WebSearch, WebFetch
description: Guideline staleness/redundancy/AI-readability check & auto-fix via 3-axis
argument-hint: "[scope]"
---

Inspect `guidelines/` via **3 axes**, auto-apply safe fixes.

| Axis | Target |
|------|--------|
| staleness | version num, release date, defunct API, deprecated pattern |
| redundancy | within-file / cross-file duplication, verbose preamble, surplus examples |
| AI-readability | table format priority, short prose, explicit judgment, inline code, emoji trim |

## Usage

```
/update-guidelines                      # full scan 3-axis, auto-fix
/update-guidelines <path>               # single file
/update-guidelines --dry                # detect, no fix
/update-guidelines --check-only         # --dry alias
/update-guidelines --only=staleness     # staleness only
/update-guidelines --only=redundancy    # redundancy only
/update-guidelines --only=readability   # AI readability only
```

`--only` values (1-char abbrev ok): `staleness|s` / `redundancy|r` / `readability|a`

## Flow

| Step | Action |
|------|--------|
| 1. identify target | arg? → file / else → `claude-code/guidelines/**/*.md` full scan |
| 2. parallel scan | 3 axes in parallel (each extract → judge) |
| 3. get latest | Context7 → fallback WebSearch (staleness axis only) |
| 4. auto-fix | apply "safe" judgment only (see table) |
| 5. collect require-review | list auto-unable items |
| 6. report | Critical/Warning/Info per axis + fix summary |

## Axis 1: Staleness Check

| Type | Detect Pattern | Severity | Auto-fix |
|------|-------------|--------|---------|
| defunct API/feature | official deprecation posted | Critical | strikethrough + mention replacement (don't delete) |
| major version gap | doc Go 1.20, latest 1.26 | Warning | update version + date |
| minor version gap | TS 5.7, latest 5.9.x | Info | update version |
| deprecated pattern | Next.js pages/ router focus | Warning | ask (pattern change = semantic shift) |

Extract patterns:
- language/FW: `(TypeScript|Go|Python|Rust|Next\.js|React)\s*[\d.]+((対応|supported)|(\+|plus)|(時点|as.?of))`
- release date: `\d{4}年\d{1,2}月((時点|as.?of)|(リリース|release))`

## Axis 2: Redundancy Check

| Type | Detect Method | Severity | Auto-fix |
|------|---------|--------|---------|
| within-file dup | same heading 2x, same table re-show | Warning | delete latter, consolidate to first |
| cross-file dup | 2+ files, 3+ lines identical | Warning | ask (which is primary?) |
| verbose preamble | "this guideline explains…" | Info | delete |
| surplus examples | 3+ per principle | Info | propose 2, ask |
| long para | 1 para 200+ chars | Info | propose table, ask |

## Axis 3: AI-Readability Check

| Type | Check | Severity | Auto-fix |
|------|------|--------|---------|
| no 1-line summary | H1 post missing file purpose 1-line | Warning | add to frontmatter `description` or header-next 1-line |
| logic unclear | if/when → text, not table/bullets | Warning | ask (text→table needs review) |
| wordy connector | "so" / "because" / honorific repeat | Info | convert to telegraphic |
| code surplus | 5+ lines per principle | Info | propose ≤5, ask |
| emoji excess | 10+ per file | Info | trim non-essential (keep ✅❌⚠️), propose, ask |
| ASCII-around-space | JP + en-digit spacing variance | Info | align to `~/.claude/rules/markdown.md` |

## Fix Safety

- **auto-safe**: version number, verbose preamble delete, telegraphic convert, space delete
- **ask-needed**: table convert, pattern change, cross-file merge
- **Critical→--dry forced**: defunct API delete always user-confirm
- **diff output**: report changed line count post-fix

## Output format

```
## Guideline 3-Axis review

### Staleness
Critical: N / Warning: N / Info: N

### Redundancy
Warning: N / Info: N

### AI-readability
Warning: N / Info: N

### Fix summary
- auto: N items (N files)
- ask: N items (list)
- skip: N items

### Changed files
- path (+X -Y)

### Next
- sync.sh to-local → commit proposed
```

## Out of Scope

- new guideline creation (`/design-doc` or manual)
- rules/references/skills scan (guidelines only)
- code body (`/dev` job)

Post-execution: `./claude-code/sync.sh to-local` → `/git-push`

ARGUMENTS: $ARGUMENTS
