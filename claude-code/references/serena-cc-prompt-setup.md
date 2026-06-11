# Serena CC System-Prompt Override Setup

`serena prompts print-cc-system-prompt-override` added in Serena v1.2.0. Inject at Claude Code startup via `--append-system-prompt` to reinforce Serena symbolic tool priority at system prompt layer.

## How it works

- Existing reminder hooks (`be89e99`, SessionStart/PreToolUse/Stop) notify at **messages layer**
- cc-system-prompt-override injects Serena tool priority rules at **system prompt layer**
- Complementary (no duplication)

## Setup

### 1. Generate prompt file

```bash
PYTHONWARNINGS=ignore uv run --directory ~/serena serena prompts print-cc-system-prompt-override > ~/.claude/serena-cc-prompt.txt
```

Regenerate on Serena update via `/serena-update-fix` (built into Phase 5).

### 2. Launch method (recommended: `ccs` shell function)

Add to `~/.zshrc` / `~/.bashrc`:

```bash
ccs() {
  local prompt_file="$HOME/.claude/serena-cc-prompt.txt"
  if [[ -r "$prompt_file" ]]; then
    command claude --append-system-prompt "$(cat "$prompt_file")" "$@"
  else
    echo "[ccs] $prompt_file not found → launching normal claude (generate: /serena-update-fix)" >&2
    command claude "$@"
  fi
}
```

Usage:
- `claude` → normal launch (no Serena override, CLAUDE.md only)
- `ccs` → Serena symbolic tools priority rules injected into system prompt

### 3. Verify launch

Check with `/btw Serena tool priority rules in system prompt?`.

## Notes

- File size: 154 lines (~3.5KB). Keep stable same content each session for `--append-system-prompt` cache efficiency
- Skip file generation if Serena not installed
- `--bare` mode requires explicit `--append-system-prompt` (no CLAUDE.md auto-load)

## Comparison: `ccs` function vs. CLAUDE.md inline

| Aspect | `ccs` (`--append-system-prompt`) | CLAUDE.md inline |
|--------|----------------------------------|-----------------|
| Invasiveness | Low (only on explicit `ccs` launch) | High (always in all project memory) |
| Updateability | File regeneration only | CLAUDE.md manual edit + sync required |
| Cache | System prompt cache (independent) | CLAUDE.md cache (invalidated by other edits) |
| Non-Serena projects | Normal launch with `claude` | Need CLAUDE.md comment |

**Recommendation**: `ccs` function. CLAUDE.md inline only for Serena-dedicated environments.
