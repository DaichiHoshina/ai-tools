# Serena Unadopted Feature Tracking — 2026Q2 archive

`/serena-update-fix` の再評価対象外。判定確定済み・trigger 待ち dormant section の履歴参照用 archive で、active な track は `../SERENA-OPPORTUNITIES.md` を参照する。dormant entry は trigger 条件 (該当言語 / 構成の project activate) が発生したら active 側へ戻す。

## v1.5.2–v1.5.3 (detected 2026-05-28)

No new opportunities. v1.5.3 is tag-only (core changes completed in v1.5.2).

- `serena-agent` CLI entrypoint (`uvx serena-agent`) [v1.5.2]: Keeping `serena start-mcp-server`, alternative entrypoint not a rename, no switch needed
- Fortls / pyright on-the-fly install [v1.5.2]: Internal LSP impl, no project.yml impact. Fortran unused; Python managed via claude-plugins-official `pyright-lsp`
- Not-existing path returns `False` on ignored checks [v1.5.2]: Bug fix, no action needed
- Hooks code-file extension list expanded [v1.5.2]: Internal to reminder hook counter, no config impact

## v1.5.0–v1.5.1 (detected 2026-05-19)

全 entry が Serena-managed memory への移行または未使用言語の project activate を trigger とする dormant 判定だった。

- [ ] **`mem:<name>` inter-memory references** (v1.5.0): Reference other memories from body with `mem:<name>`, auto-propagates on rename. Option to align from handwritten `[[name]]` notation in `~/.claude/projects/.../memory/MEMORY.md` to official Serena notation — review at: 20+ existing user-assist memories are in `~/.claude/` direct, outside Serena `write_memory` path and not propagation targets. Value only if migrating to Serena-managed memories
- [ ] **`memory_maintenance` onboarding seed** (v1.5.0): Place seed memory for memory style rules at onboarding, shareable across all projects via `global/memory_maintenance` — review at: currently substituted by `~/.claude/CLAUDE.md` + `rules/plain-jp.md`. Consider integrating when migrating to Serena-managed memories
- ~~**`serena memories` CLI command group** (v1.5.0)~~ (obsolete 2026-06-08): CLI scope targets only `.serena/memories/`. Our `~/.claude/projects/.../memory/` is outside Serena management; `serena memories list` does not cover it. CLI migration for `/memory-save` consistency checks is a scope mismatch
- [ ] **CUE LSP** (v1.5.1): CUE language support via `cue lsp` — review at: only when activating a CUE project (none currently)
- [ ] **GDScript LSP** (v1.5.0): TCP connection to Godot editor's built-in LSP — review at: only when activating a Godot project (none currently)

## v1.3.0 (detected 2026-05-12)

- [ ] **`additional_workspace_folders`**: Cross-package reference support (TypeScript only as of v1.3.0). Enables symbol resolution for sibling packages in monorepos — review at: when activating a TypeScript monorepo or on extension to other languages. Current activated projects are go/bash/dart/terraform/python, out of scope
- [ ] **`added_modes`**: Cannot override `base_modes` in project.yml; add-only via `added_modes`. All projects currently have `added_modes:` empty, no impact — review at: each project's `.serena/project.yml` when adding custom modes
- ~~**`base_modes` default change** (`interactive`/`editing` moved from default_modes → base_modes)~~ (obsolete 2026-05-12): Global default behavior change only, no project-side awareness needed

## v1.0.0 (detected 2026-05-12, retroactive)

- [ ] **`project.local.yml` local override**: Separate personal/local settings from project.yml without git tracking — review at: when personal-specific settings (absolute paths in `ls_specific_settings` etc.) are needed per project
- [ ] **`ls_specific_settings` utilization**: Per-language-server settings (JDK path, custom binary, etc.) — review at: when activating Java/Scala/MATLAB etc. Currently only go/bash/dart/terraform/python, out of scope
- [ ] **monorepo / multi-language `project.yml`**: Define multiple languages in one project — review at: when a repo mixes go + typescript
