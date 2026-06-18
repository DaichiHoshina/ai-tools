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
