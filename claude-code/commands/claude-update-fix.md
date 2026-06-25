---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
argument-hint: "[--dry-run] [--channel stable|latest|next]"
description: Claude Code update adaptation — detect diffs, auto-apply safe changes, track unimplemented features
---

# /claude-update-fix

Proactively align repo w/ CLI updates. Auto-apply low-risk fixes, track unimplemented features.

## Phase 1: Channel detection & diff

```bash
claude --version                                                 # local CLI
npm view @anthropic-ai/claude-code dist-tags --json              # { stable, latest, next }
cat claude-code/VERSION                                          # last confirmed
cat claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md 2>/dev/null
```

**Channel judgment** (track per release channel):

| Condition | CHANNEL | TARGET |
|------|---------|--------|
| `claude --version` == `dist-tags.stable` | `stable` | `stable` tag version |
| `claude --version` == `dist-tags.latest` | `latest` | `latest` tag version |
| neither matches (mid-version / manually pinned) | `latest` (current default) | `latest` tag version |

Rationale: repo runs on the **stable** channel (switched back from latest 2026-06-23). Align fetch scope and bump target to the stable tag. Adopt renames/new hooks/new keys as they land; the local CLI is expected to track stable.

**Decision**:
- `VERSION > TARGET` (next channel / pre-bump / post-channel-switch downgrade) → no-op exit; display `> [WARN] VERSION (X) > TARGET (Y), below channel target. Fetch range goes backward — skip. Confirm manually aligning VERSION to TARGET`
- `TARGET == VERSION` + opportunities resolved → "already up to date" & exit
- `TARGET == VERSION` + opportunities exist → Phase 3-B only
- `TARGET > VERSION` → Phase 2 (CHANGELOG fetch range: `VERSION+1` ~ `TARGET`)

## Phase 2: CHANGELOG structured extraction

Fetch (priority order):
1. `WebFetch`: `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`
2. `npm view @anthropic-ai/claude-code time` → version ↔ date map
3. `WebSearch`: "claude code changelog {version}"

Extract confirmed-to-current range, tag each entry (multi-tag OK):

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

1. Update `claude-code/VERSION` to **TARGET** (channel-matched version confirmed in Phase 1; write channel target, not `latest`)
2. Run `./claude-code/sync.sh to-local --yes` (at this step only)
3. Update opportunity file (reflect Phase 3-B diffs)
4. If major changes (3+ files or non-obvious decisions), save to Claude Code auto-memory (`~/.claude/projects/<project>/memory/claude-update-YYYYMMDD.md` via `Write`) — Serena `write_memory` forbidden (2026-06-10)

## Opportunity tracking format

`claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md`:

```markdown
## <version> (detected YYYY-MM-DD, <channel>)
- [ ] **<feature name>**: <summary> — review target: <file/agent>
```

- `<channel>` = `stable` or `latest` (as determined in Phase 1). Recording channel lets you scope past history correctly after a channel switch
- when adopted: check & reference in commit msg
- when stale: strike out as `~~<feature name>~~ (obsolete YYYY-MM-DD)`

## Notes

- `claude doctor` is interactive; use `claude --version` instead
- `npm view ... dist-tags --json` fails (network etc.) → safe fallback: treat current `VERSION` as TARGET, no-op exit, display `> [WARN] dist-tags fetch failed, cannot determine channel. Re-run after CLI reconnects`
- If CHANGELOG fetch fails: minimal analysis via `claude --help` + npm view
- Auto-apply must remain git-diff-reviewable (do not run sync.sh until after confirm-apply)
- **VERSION file update aligns to stable tag** — value written in Phase 5 Step 1 is `dist-tags.stable`
- **CHANGELOG / feature adoption scope is `(current VERSION + 1) ~ stable tag`**
- **Channel is `stable` (switched back from latest 2026-06-23)** — local CLI tracks the stable tag. Switching to latest would require explicit user confirmation
