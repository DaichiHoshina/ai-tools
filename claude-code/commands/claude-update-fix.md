---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
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

**Channel 判定** (release channel に合わせて追従):

| 条件 | CHANNEL | TARGET |
|------|---------|--------|
| `claude --version` == `dist-tags.stable` | `stable` | `stable` tag version |
| `claude --version` == `dist-tags.latest` | `latest` | `latest` tag version |
| どちらとも不一致 (中間 version / 手動固定) | `stable` (保守) | `stable` tag version |

判定理由: stable channel 運用時に `latest` のみで入った rename / 新 hook を採用すると、stable CLI ではコマンド未存在で破壊的になる。channel に対応する target で fetch 範囲・bump 対象を揃える。

**判定**:
- `VERSION > TARGET` (next channel 利用 / 手動先行 bump / channel switch 後 downgrade) → no-op exit、`> [WARN] VERSION (X) > TARGET (Y)、channel target 未達。fetch 範囲負方向ゆえ skip。手動で VERSION を TARGET に揃えるか確認` を表示
- `TARGET == VERSION` + opportunities 解決済 → "already up to date" & exit
- `TARGET == VERSION` + opportunities exist → Phase 3-B のみ
- `TARGET > VERSION` → Phase 2 へ (CHANGELOG fetch 範囲: `VERSION+1` ~ `TARGET`)

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

no tag (UI/perf/bugfix etc) → ignore.

## Phase 3: Extension point map (fixed mapping table)

For each tag, run grep/read at **decisive detection points**. Generate fix suggestions if found.

| Tag | Inspection target | Detection method |
|-----|------------------|------------------|
| 3-1 RENAME | `claude-code/agents/*.md`, `commands/*.md`, `skills/*/skill.md`, `CLAUDE.md`, `hooks/*.sh`, `templates/settings.json.template` | grep old name, replace w/ new name |
| 3-2 HOOK | `claude-code/hooks/*.sh`, `hooks` section in `templates/settings.json.template` | new event: suggest template if unregistered. I/O change: grep existing hook schema |
| 3-3 SETTING | `claude-code/templates/settings.json.template`, `.claude/settings.json` | new key: suggest add to template. deprecated: suggest remove |
| 3-4 MODEL | `claude-code/CLAUDE.md`, `agents/*.md` frontmatter, `skills/*/skill.md`, `scripts/**/*.{sh,py}` | grep old model ID, replace all |
| 3-5 TOOL | `allowed-tools:` and tool lists in `claude-code/agents/*.md` | tool rename: replace. new tool: suggest if useful for agent |
| 3-6 SKILL | `claude-code/skills/*/skill.md` frontmatter | validate new rules (e.g. description length) |
| 3-7 COMMAND | file names in `claude-code/commands/*.md` vs built-in new names | name collision: suggest rename w/ prefix (e.g. `_custom`) |

### 3-B. Opportunity re-evaluation

Re-check each item in prior `CLAUDE-CODE-OPPORTUNITIES.md`. Adopted/stale → close. Unimplemented + valid → continue.

## Phase 4: Application (by tier)

Priority: **Critical** (collision/breakage) > **Warning** (deprecated removal) > **Auto** (mechanical replace) > **Opportunity** (new feature) > **Info**

| Tier | Scope | Action |
|------|-------|--------|
| **Auto-apply** | Auto (model ID replace, deprecated option remove, frontmatter key order normalize) + VERSION bump | Edit w/o confirm. Skip prose/desc rewrites |
| **Confirm-apply** | Critical + Warning | AskUserQuestion: apply all / individual / skip |
| **Track only** | Opportunity + Info | append to `references/CLAUDE-CODE-OPPORTUNITIES.md` (no execution) |

After auto-apply, output all diffs then proceed to confirm-apply.

## Phase 5: Cleanup (after Phase 4 confirm-apply)

1. Update `claude-code/VERSION` to **TARGET** (Phase 1 で確定した channel 対応 version、`latest` ではなく channel target を書き込む)
2. Run `./claude-code/sync.sh to-local --yes` (at this step only)
3. Update opportunity file (reflect Phase 3-B diffs)
4. If major changes (3+ files or non-obvious decisions), save to Serena memory as `claude-update-YYYYMMDD`

## Opportunity tracking format

`claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md`:

```markdown
## <version> (YYYY-MM-DD 検出, <channel>)
- [ ] **<feature name>**: <summary> — 検討箇所: <file/agent>
```

- `<channel>` = `stable` or `latest` (Phase 1 で確定したもの)。channel を書き残しておくと、後の channel switch 時に過去履歴のスコープが追える
- when adopted: check & reference in commit msg
- when stale: strike out as `~~<feature name>~~ (obsolete YYYY-MM-DD)`

## Notes

- `claude doctor` is interactive; use `claude --version` instead
- `npm view ... dist-tags --json` fails (network 等) → 安全 fallback: 現 `VERSION` を TARGET 扱いで no-op exit、warning 表示 (`> [WARN] dist-tags fetch fail、channel 判定不可。CLI 再接続後に再実行を`)。**`latest` 自動採用は禁止** (stable channel 環境で破壊的変更を引き込むリスク、本 Phase 1 安全側設計と矛盾)
- stable channel 運用時、`latest` のみで入った feature は `Track only` (Opportunity) でも記録しない (stable 到達後に次回検出される) — Phase 2 fetch 範囲を TARGET で限定する目的
- if CHANGELOG fetch fails: minimal analysis w/ `claude --help` + npm view
- auto-apply must remain git-diff-reviewable (do not run sync.sh until after confirm-apply)
