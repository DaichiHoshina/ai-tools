# skillOverrides Design Guide

Decision criteria for controlling skill visibility via `skillOverrides` in `settings.json`. Requires CLI 2.1.129+.

## Exact meanings of 4 values

| Value | Model auto-launch | `/skill` direct call | Description shown | Use |
|----|---|---|---|---|
| `on` | ✓ | ✓ | ✓ | Default. Skills Claude launches based on context |
| `name-only` | ✓ (name only) | ✓ | ✗ | Name is sufficient for decision. Saves description tokens |
| `user-invocable-only` | **✗** | ✓ | ✓ | `/` input only. **Claude cannot launch as proxy** |
| `off` | ✗ | ✗ | ✗ | Fully disabled (effectively deleted) |

Plugin skills are **not affected** (managed separately via `/plugin`).

## Key blind spot: `user-invocable-only` pitfall

Setting `user-invocable-only` because "user explicitly calls it" means **Claude cannot proxy-launch it when user requests it in natural Japanese**.

### Real example (detected in 2026-05-07 retrospective)

- User says "retrospective して" → Claude runs `Skill(retrospective)` → `Skill retrospective is disabled for model invocation` error
- `/reload` was set to user-invocable-only but was a high-frequency skill with 12 uses in last 1000 prompts → high natural-language launch demand

### Correct decision criteria

**`user-invocable-only` only for**:
- Commands that genuinely only activate via `/` input (`/init`, `/loop`, `/schedule` etc.)
- Confident user will never request in Japanese natural language
- Internal-reference-only commands that never launch standalone (`aliases`, `protection-mode` etc.)

**Keep `on`** (Claude proxy-launch demand exists):
- "振り返りして" → retrospective
- "リロード" → reload
- "アップデート対応" → claude-update-fix
- "分析して" → analytics
- "セキュリティレビュー" → security-review
- "strict mode に" → session-mode
- "設定変更" → update-config
- "キーバインド変更" → keybindings-help
- "スキル追加" → skill-add
- "ガイドライン更新" → update-guidelines
- "スキル管理" → skills-manage
- "ダッシュボード" → dashboard

**`name-only` recommended**:
- Language skills not used in this repo/project (terraform / grpc-protobuf / react-best-practices etc.)
- Design-phase skills where explicit invocation is the norm (prd / design-doc / brainstorm / architecture-diagram)

## Token reduction estimate

`name-only`: ~50-100 token reduction per skill (50-200 chars description). 20 skills → 1000-2000 token/session.

`user-invocable-only` reduction is similar, but **cost of losing proxy-launch** > **token savings** when usage frequency is high. Check `~/.claude/history.jsonl` before deciding.

```bash
# Skill usage frequency in last 1000 prompts
tail -1000 ~/.claude/history.jsonl | jq -r '.display // empty' | grep -E "^/" | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
```

## Settings location

| Scope | File | Use |
|---------|---------|------|
| User | `~/.claude/settings.json` | Use this for this repo's operation |
| Project | `<repo>/.claude/settings.json` | Project-specific skill control |
| Local | `<repo>/.claude/settings.local.json` | Personal local override; `/skills` menu writes here |

In this repo: defined in `claude-code/templates/settings.json.template` → merged to `~/.claude/settings.json` by `sync.sh` (CLI 2.1.132+).

## sync.sh sync behavior (important)

`sync_settings_skill_overrides` is **add/update only** — no auto-delete. Reason: avoid destroying overrides user added live.

| Operation | Behavior |
|------|------|
| Add to template | Reflected in live (add) |
| Change value in template | Reflected in live (overwrite) |
| **Delete from template** | **Remains in live → sync outputs warning** |

To reflect template deletion in live, manually delete:

```bash
jq 'del(.skillOverrides["key-to-delete"])' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

## Pre-change checklist

Before adding/changing skillOverrides:

- [ ] Confirmed natural-language launch demand in `history.jsonl`
- [ ] Considered "is there any case Claude would proxy-launch this?" before setting `user-invocable-only`
- [ ] Test: after setting, try requesting the skill "in Japanese" and verify it launches

## Related

- CHANGELOG: CLI 2.1.129
- Official docs: https://code.claude.com/docs/en/settings (skillOverrides section)
