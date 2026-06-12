---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, mcp__serena__*
description: Serena MCP update - detect diff, auto-apply, track unused features
---

# /serena-update-fix

Update Serena local clone (`~/serena`), then adapt claude-code config/docs/all activated projects per CHANGELOG diff.

## Phase 1: Detect Diff

```bash
cd ~/serena && git pull --rebase --autostash               # sync main
git tag --sort=-v:refname | head -1                         # latest tag
cat ~/ai-tools/claude-code/SERENA_VERSION                   # confirmed version
cat ~/ai-tools/claude-code/references/SERENA-OPPORTUNITIES.md 2>/dev/null
```

No diff AND no Opportunity unsolved → "latest confirmed" → done.
No diff BUT Opportunity exists → run Phase 3-B only.
Diff found → proceed Phase 2.

## Phase 2: Structured CHANGELOG Extract

Extract CHANGELOG.md from confirmed-to-current range. Tag each entry as one of:

| Tag | Keywords | Next Action |
|-----|----------|------------|
| `RENAME` | removed, renamed, deprecated, Breaking change | → 3-1 |
| `TOOL` | Add new tools, tool name (`find_*`, `get_*`, `jet_brains_*` etc) | → 3-2 |
| `CONFIG` | project.yml, setting, `base_modes`, `added_modes`, `language_backend` | → 3-3 |
| `MCP` | start-mcp-server, --context, --project, CLI arg | → 3-4 |
| `LSP` | language server, LSP, `ls_specific_settings`, lang add | → 3-5 |
| `CONTEXT` | context (claude-code, agent), mode add | → 3-6 |

No tag (bugfix/perf/JetBrains-only) → ignore.

## Phase 3: Extension Point Map

| Tag | Inspect | Detect Method |
|-----|---------|---------|
| 3-1 RENAME | `agents/README.md` Serena tools table, `agents/*.md` allowed-tools, `commands/*.md`, `CLAUDE.md` | grep old name, replace → new name |
| 3-2 TOOL | `agents/README.md` tool catalog, `agents/*.md` `allowed-tools: ... mcp__serena__*` | new tool: add to catalog, check related agent allowed-tools |
| 3-3 CONFIG | all activated `.serena/project.yml` | new key: propose template add. deprecated key: propose delete. schema breaking = grep impact across projects |
| 3-4 MCP | `templates/.mcp.json.template`, `settings/mcp-servers/serena.json.template`, `claude mcp list` user-scope arg | startup arg change: update both templates + re-register user-scope |
| 3-5 LSP | `.serena/project.yml` `languages:` / `ls_specific_settings:` | lang add: check if applicable in activated projects |
| 3-6 CONTEXT | `templates/.mcp.json.template` `--context` value, `settings/mcp-servers/serena.json.template` same | context rename/add: update template |

### 3-B. Re-evaluate Opportunity

Re-check each in `references/SERENA-OPPORTUNITIES.md`. Adopted/obsolete → close. Unadopted + valid → keep.

### Activated Projects List

```bash
grep -A 50 "^projects:" ~/.serena/serena_config.yml | grep "^- /"
```

When CONFIG has schema breaking, check/update all `.serena/project.yml`.

## Phase 4: Apply (stratified)

Priority: **Critical** (schema mismatch/startup fail) > **Warning** (deprecated removal) > **Auto** (tool ID replace, template args, SERENA_VERSION bump) > **Opportunity** (new feature) > **Info**

| Layer | Target | Behavior |
|----|--------|----------|
| **auto-apply** | Auto (tool rename, template args, SERENA_VERSION bump) | Edit without ask |
| **ask-apply** | Critical + Warning (schema change, user-scope re-register etc) | AskUserQuestion all/individual/skip |
| **track-only** | Opportunity + Info | add to `references/SERENA-OPPORTUNITIES.md` |

After auto-apply, show all diffs, then ask-apply.

## Phase 5: Cleanup

1. bump `SERENA_VERSION` to current tag
2. verify: `claude mcp list` show `serena: ... ✓ Connected`
3. if template changed, run `./sync.sh to-local --yes`
4. update Opportunity tracking (Phase 3-B diff)
5. regen CC system prompt override (if cc-system-prompt-override in use):
   ```bash
   PYTHONWARNINGS=ignore uv run --directory ~/serena serena prompts print-cc-system-prompt-override > ~/.claude/serena-cc-prompt.txt
   ```
   ops detail: `references/serena-cc-prompt-setup.md`
6. if 3+ file changes OR non-trivial judgment, save to Claude Code auto-memory (`~/.claude/projects/<project>/memory/serena-update-YYYYMMDD.md` via `Write`) — Serena `write_memory` forbidden (2026-06-10)

## Notes

- `~/serena` = local clone (user-scope MCP startup base). `git pull` = `--rebase --autostash` only
- if CHANGELOG has main's `# Unreleased`, ignore pre-release changes (next tag-release pick them up). except Breaking change → adapt immediately
- `--version` verify = `uv run --directory ~/serena serena --version` (warn suppress = `PYTHONWARNINGS=ignore` like hooks/serena-hook.sh)
- v1.3.0+ dropped `serena-mcp-server`, now `serena start-mcp-server` required
- user-scope MCP = `--project-from-cwd` startup assumed (all activated projects Connected). if placing project-scope `.mcp.json`, explicit `${PROJECT_ROOT}`
