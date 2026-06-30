---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
argument-hint: "[--dry-run] [--channel stable|latest|next]"
description: Claude Code update adaptation — detect diffs, auto-apply safe changes, track unimplemented features
---

# /claude-update-fix

Proactively align repo w/ CLI updates. Auto-apply low-risk fixes, track unimplemented features.

## Phase 1: Channel detection & diff

Run: `claude --version` (local CLI) / `npm view @anthropic-ai/claude-code dist-tags --json` ({ stable, latest, next }) / `cat claude-code/VERSION` / `cat claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md 2>/dev/null`.

**Channel judgment** (track per release channel):

| Condition | CHANNEL | TARGET |
|------|---------|--------|
| `claude --version` == `dist-tags.stable` | `stable` | `stable` tag version |
| `claude --version` == `dist-tags.latest` | `latest` | `latest` tag version |
| neither matches (mid-version / manually pinned) | `latest` (current default) | `latest` tag version |

Repo runs on the **stable** channel (switched back from latest 2026-06-23); fetch scope and bump target align to stable tag.

**Decision**:
- `VERSION > TARGET` → no-op exit; display `> [WARN] VERSION (X) > TARGET (Y)` (fetch range backward — skip)
- `TARGET == VERSION` + opportunities resolved → "already up to date" & exit
- `TARGET == VERSION` + opportunities exist → Phase 3-B only
- `TARGET > VERSION` → Phase 2 (CHANGELOG fetch range: `VERSION+1` ~ `TARGET`)

## Phase 2: CHANGELOG structured extraction

Fetch priority: (1) `WebFetch` `raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` → (2) `npm view @anthropic-ai/claude-code time` → (3) `WebSearch "claude code changelog {version}"`. Extract confirmed-to-current range, tag each entry (multi-tag OK):

| Tag | Keywords (case-insensitive) | Next action |
|-----|------------------------------|-------------|
| `RENAME` | removed, renamed, deprecated | → 3-1 |
| `HOOK` | hook, event, PreCompact, PostCompact, SessionStart | → 3-2 |
| `SETTING` | setting, config, option, env var, permission | → 3-3 |
| `MODEL` | model, claude-sonnet, claude-opus, claude-haiku | → 3-4 |
| `TOOL` | tool, parameter, Task, Bash, Edit, EnterWorktree | → 3-5 |
| `SKILL` | skill, frontmatter, description char-limit | → 3-6 |
| `COMMAND` | slash command, new `/` command names | → 3-7 |

No tag (UI/perf/bugfix etc) → ignore.

## Phase 3: Extension point map (fixed mapping table)

For each tag, run grep/read at **decisive detection points**. Generate fix suggestions if found.

| Tag | Inspection target | Detection method |
|-----|------------------|------------------|
| 3-1 RENAME | `claude-code/agents/*.md`, `commands/*.md`, `skills/*/SKILL.md`, `CLAUDE.md`, `hooks/*.sh`, `templates/settings.json.template` | grep old name, replace w/ new name |
| 3-2 HOOK | `claude-code/hooks/*.sh`, `hooks` section in `templates/settings.json.template` | new event: suggest template if unregistered. I/O change: grep existing hook schema |
| 3-3 SETTING | `claude-code/templates/settings.json.template` | new key: suggest add to template (live `.claude/settings.json` is overwritten by `sync.sh to-local` — not an edit target; per CLAUDE.md "root keys are template canonical"). deprecated: suggest remove |
| 3-4 MODEL | `claude-code/CLAUDE.md`, `agents/*.md` frontmatter, `skills/*/SKILL.md`, `scripts/**/*.{sh,py}` | grep old model ID, replace all |
| 3-5 TOOL | `allowed-tools:` and tool lists in `claude-code/agents/*.md` | tool rename: replace. new tool: suggest if useful for agent |
| 3-6 SKILL | `claude-code/skills/*/SKILL.md` frontmatter | validate new rules (e.g. description length) |
| 3-7 COMMAND | file names in `claude-code/commands/*.md` vs built-in new names | name collision: suggest rename w/ prefix (e.g. `_custom`) |

### 3-B. Opportunity re-evaluation

Re-check each item in prior `CLAUDE-CODE-OPPORTUNITIES.md`. Adopted/stale → close. Unimplemented + still valid → continue.

## Phase 4: Application (by tier)

Priority: **Critical** (collision/breakage) > **Warning** (deprecated removal) > **Auto** (mechanical replace) > **Opportunity** (new feature) > **Info**

| Tier | Scope | Action |
|------|-------|--------|
| **Auto-apply** | Auto (model ID replace, deprecated option remove, frontmatter key order normalize) + VERSION bump | Edit w/o confirm. Skip prose/desc rewrites |
| **Confirm-apply** | Critical + Warning | AskUserQuestion: apply all / individual / skip |
| **Track only** | Opportunity + Info | append to `references/CLAUDE-CODE-OPPORTUNITIES.md` (no execution) |

After auto-apply, output all diffs then proceed to confirm-apply.

## Phase 5: Cleanup (after Phase 4 confirm-apply)

1. Update `claude-code/VERSION` to **TARGET** (Phase 1 channel-matched version)
2. Run `./claude-code/sync.sh to-local --yes` (at this step only)
3. Update opportunity file (reflect Phase 3-B diffs)
4. Major changes (3+ files / non-obvious decisions) → save via `Write` to `~/.claude/projects/<project>/memory/claude-update-YYYYMMDD.md` (Serena `write_memory` forbidden 2026-06-10)

## Opportunity tracking format

`claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md` に `## <version> (detected YYYY-MM-DD, <channel>)` + `- [ ] **<feature>**: <summary> — review target: <file>` 形式で append。`<channel>` は Phase 1 判定値 (stable / latest)。採用時は check + commit msg 参照、陳腐化時は `~~<feature>~~ (obsolete YYYY-MM-DD)` で打消す。

## Notes

- `claude doctor` is interactive; use `claude --version` instead
- `npm view ... dist-tags --json` fails → safe fallback: treat current `VERSION` as TARGET, no-op exit, display `> [WARN] dist-tags fetch failed`
- CHANGELOG fetch fails → minimal analysis via `claude --help` + npm view
- Auto-apply must remain git-diff-reviewable (do not run sync.sh until after confirm-apply)
