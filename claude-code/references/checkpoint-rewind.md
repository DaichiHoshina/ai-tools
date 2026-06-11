# Checkpoint / Rewind

Claude Code auto-creates checkpoints before changes. Restore conversation, code, or both to a prior state.

## Operations

| Action | Effect |
|--------|--------|
| `Esc` | Stop Claude mid-execution. Keep context, change direction |
| `Esc + Esc` or `/rewind` | Show rewind menu: conversation only / code only / both / summarize from selection |
| `"Undo that"` | Ask Claude to revert the last change |
| `/clear` | Full context reset between unrelated tasks |

## When to Use

- **Risky trials**: Run bold changes assuming "rewind if it fails"
- **Contaminated conversation**: After 2+ failed corrections, clean up with summarize-from-here
- **Experiment branching**: Try multiple approaches in sequence, keep the best
- **Cross-session**: Checkpoints persist after session end. Rewind works after closing the terminal

## Constraints

- Checkpoints track **only Claude-made changes**. External processes (manual edits, CI, git operations) are excluded
- **Not a git replacement**. Use git commit for important state preservation
- No new tool calls during rewind

## Official Recommended Pattern

> "tell Claude to try something risky. If it doesn't work, rewind and try a different approach." — over "carefully planning every move"

Compare planning cost vs trial cost. If trial is cheap, run with rewind assumed.

## Related Commands

- `claude --continue` — resume previous session
- `claude --resume` — select from recent sessions
- `/rename` — assign session name (e.g., `oauth-migration`, `debugging-memory-leak`)
- `/btw` — side question without contaminating context. Answer shown in overlay, not saved to history
