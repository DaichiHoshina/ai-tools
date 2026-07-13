# Serena MCP tool map (per agent)

各 agent が Serena MCP で第一に使うべき tool の一覧。frontmatter `tools: mcp__serena__*` の一括許可下で、用途ごとの優先順を canonical 化する。

## Common tools (all Serena-using agents)

| Tool | 用途 |
|---|---|
| `find_symbol` | symbol path 検索 |
| `get_symbols_overview` | file 構造把握 |
| `find_referencing_symbols` | 参照箇所列挙 |
| `search_for_pattern` | 横断検索 |

## Per-agent priorities

### reviewer-agent / root-cause-analyzer

| Goal | Tool |
|---|---|
| Impact scope, reverse refs | `find_referencing_symbols` |
| interface ↔ impl | `find_implementations` (v1.3.0) |
| Declaration position | `find_declaration` (v1.3.0) |
| File structure | `get_symbols_overview` |
| Symbol search | `find_symbol` |
| Type errors, LSP diagnostics | `get_diagnostics_for_file` / `_for_symbol` (v1.3.0) |
| Pattern cross-codebase search | `search_for_pattern` |

### developer-agent

Primary: `get_symbols_overview` / `find_symbol` / `replace_symbol_body` / `insert_after_symbol` / `get_diagnostics_for_file` (self-verify)

| Goal | Tool |
|---|---|
| File structure / code overview | `get_symbols_overview` |
| Symbol lookup | `find_symbol` |
| Replace implementation | `replace_symbol_body` |
| Insert code | `insert_after_symbol` |
| Self-verify (type errors) | `get_diagnostics_for_file` |

### manager-agent

| Goal | Tool |
|---|---|
| Dependency / impact scope | `find_symbol` |
| All callers (task decomp) | `find_referencing_symbols` |
| Interface change impl count | `find_implementations` (v1.3.0) |
| Baseline type errors | `get_diagnostics_for_file` (v1.3.0) |
| Comprehensive change targets | `search_for_pattern` |
| Project constraints | `read_memory` |

## Accident prevention rules (dotall greedy incident 2026-05-18)

### activate_project は絶対 path 必須

`activate_project(".")` は Serena server の cwd 誤認で別 repo を activate しうる (2026-06-13 に oraios/serena が誤 activate された)。常に絶対 path を渡し、応答の `Programming languages:` が対象 repo と整合するか確認する (ai-tools なら bash)。誤 activate しても絶対 path で再 activate すれば復帰する。

### worktree 作業では Serena 書込系を使わない

Serena の project root は main repo に固定され、subagent 側に activate_project がなく worktree へ切替できない。書込系 (`insert_after_symbol` / `replace_content` 等) は worktree でなく main repo の同名 file を誤編集する (2026-07-13 /flow 並列で実害)。worktree で作業する agent への delegation prompt に「Serena は read-only 用途のみ、編集は Read/Edit/Write/Bash を worktree 絶対 path で行う」と明記し、parent は統合前に main repo の `git status --porcelain` で誤爆残留を点検する。

### search_for_pattern: specify `multiline=False` for single-line scope searches

`multiline=False` opt-out added in v1.5.0 (default is `multiline=True` with `re.DOTALL|MULTILINE` enabled).

- **Rule**: For searches clearly completing within a single line, explicitly specify `multiline=False`. Structurally eliminates risk of `.*` greedily consuming across newlines.
- **Apply to**: variable names / function names / single-line config values / single import lines / single-line annotations
- **Do not apply (keep multiline=True)**: function body / class body / multi-line config block searches

**Why**: Prevents same pattern as 2026-05-18 dotall greedy incident in `search_for_pattern`. Since `replace_content` dotall hardcode (Tool API constraint) cannot be avoided, narrow scope on search side first.

### replace_content: immediate response on ambiguity error

`ContentReplacer.replace()` in v1.5.0 now returns `ValueError("Match is ambiguous: ...")` when the same pattern reappears inside the match.

- **Response steps on error**:
  1. **Switch to literal mode**: escape all regex meta chars, specify target string as literal match.
  2. **Explicit end anchor**: combine `.*?` (non-greedy) + explicit end anchor (newline literal `\n` / adjacent invariant string).
  3. **Narrow scope**: if multiple locations in one file match, switch to `find_symbol` for symbol-unit editing (`replace_symbol_body` / `insert_after_symbol` etc.).

**Why**: Serena now auto-detects the same pattern as the 2026-05-18 dotall greedy incident (greedy `.*\n` fired across 5 files). Switch to the 3 steps above immediately instead of manually fixing regex.
