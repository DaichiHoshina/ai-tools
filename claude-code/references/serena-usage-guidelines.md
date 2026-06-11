# Serena MCP Usage Guidelines

Accident prevention rules for Serena tool use. Supplements the dotall greedy incident (2026-05-18).

## search_for_pattern: specify `multiline=False` for single-line scope searches

`multiline=False` opt-out added in v1.5.0 (default is `multiline=True` with `re.DOTALL|MULTILINE` enabled).

- **Rule**: For searches clearly completing within a single line, explicitly specify `multiline=False`. Structurally eliminates risk of `.*` greedily consuming across newlines.
- **Apply to**: variable names / function names / single-line config values / single import lines / single-line annotations
- **Do not apply (keep multiline=True)**: function body / class body / multi-line config block searches

**Why**: Prevents same pattern as 2026-05-18 dotall greedy incident in `search_for_pattern`. Since `replace_content` dotall hardcode (Tool API constraint) cannot be avoided, narrow scope on search side first.

## replace_content: immediate response on ambiguity error

`ContentReplacer.replace()` in v1.5.0 now returns `ValueError("Match is ambiguous: ...")` when the same pattern reappears inside the match.

- **Response steps on error**:
  1. **Switch to literal mode**: escape all regex meta chars, specify target string as literal match.
  2. **Explicit end anchor**: combine `.*?` (non-greedy) + explicit end anchor (newline literal `\n` / adjacent invariant string).
  3. **Narrow scope**: if multiple locations in one file match, switch to `find_symbol` for symbol-unit editing (`replace_symbol_body` / `insert_after_symbol` etc.).

**Why**: Serena now auto-detects the same pattern as the 2026-05-18 dotall greedy incident (greedy `.*\n` fired across 5 files). Switch to the 3 steps above immediately instead of manually fixing regex.
