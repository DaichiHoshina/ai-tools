# Plugin Marketplace Caveats

## Warning: marketplace deletion causes cascading uninstall

Deleting a marketplace from `/plugin marketplace` removes all plugins linked to that marketplace from `installed_plugins.json` (cascading uninstall).

Restarting Claude Code alone does not recover them. Individual reinstallation is required.

## Past incident (2026-04-27)

During marketplace update, `claude-plugins-official` was accidentally deleted. 11 plugins disappeared simultaneously:

| Plugin | Purpose |
|--------|---------|
| typescript-lsp | TypeScript language server |
| frontend-design | Frontend assistance |
| code-review | Code review |
| commit-commands | Commit helpers |
| claude-md-management | CLAUDE.md management |
| code-simplifier | Code simplification |
| security-guidance | Security guidance |
| pr-review-toolkit | PR review |
| gopls-lsp | Go language server |
| rust-analyzer-lsp | Rust language server |
| pyright-lsp | Python language server |

`coderabbit` survived as it was managed under a separate marketplace.

## Prevention

Run before any marketplace operation (remove / re-add / update):

```bash
claude plugin list > ~/plugin-backup-$(date +%Y%m%d).txt
```

Before proposing marketplace remove / re-add, confirm cascading impact on linked plugins and warn user.

## Recovery

If cache remains, immediate reinstall is possible:

```bash
# Individual reinstall
claude plugin install <name>@claude-plugins-official

# Bulk recovery from list
for p in typescript-lsp frontend-design code-review commit-commands \
  claude-md-management code-simplifier security-guidance pr-review-toolkit \
  gopls-lsp rust-analyzer-lsp pyright-lsp; do
  claude plugin install "${p}@claude-plugins-official"
done
```

## Related

- `references/coderabbit-plugin.md` (CodeRabbit uses separate marketplace, no cascading impact)
