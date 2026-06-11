# claude -p Fan-out Recipes

Patterns for parallelizing large-scale file processing with `claude -p` (non-interactive mode).

## Applicability

- **10+ target files** (fewer than 10 → process directly inside agent)
- **Each file is independent** (no cross-references or only local ones)
- **Success criterion is machine-checkable** (lint/test/build/regex pass)
- **Haiku 4.5 sufficient** for simple transforms (type conversion, formatting, import rename, API migration)

Otherwise, use `/flow` with agent team.

## Basic structure

```bash
# 1. Generate target list
claude -p "list all .ts files importing 'oldLib' in src/" \
  --output-format json | jq -r '.files[]' > targets.txt

# 2. Loop execution (sequential)
for file in $(cat targets.txt); do
  claude -p "Migrate $file: replace 'oldLib' import with 'newLib'. Run 'npm run typecheck $file'. Return OK or FAIL:<reason>." \
    --allowedTools "Read,Edit,Bash(npm run typecheck:*)" \
    --model haiku \
    --output-format json \
    --fallback-model sonnet
done | tee results.log

# 3. Aggregate FAIL entries for manual handling
grep FAIL results.log
```

## Parallel execution (GNU parallel)

```bash
# 8 parallel; adjust for CPU load / API rate limits
cat targets.txt | parallel -j 8 '
  claude -p "Migrate {} from React class to hooks. Verify with npm run test -- {.}.test.tsx. Return OK/FAIL." \
    --allowedTools "Read,Edit,Bash(npm run test:*)" \
    --model haiku \
    --output-format json
' > results.jsonl
```

## Prompt tips

1. **Binary return**: `Return OK or FAIL:<reason>` for easy grep
2. **Restrict allowedTools strictly**: do not broadly allow Bash in unattended runs
3. **Dry run on 2-3 files first**: refine prompt before full set
4. **Specify model explicitly**: `--model haiku` for 1/10 cost
5. **--fallback-model sonnet**: auto-fallback on overload
6. **Always include a verify step**: run typecheck/test/lint inside Claude → return result

## Unattended execution (auto mode)

```bash
claude --permission-mode auto -p "fix all lint errors in $file"
```

Non-interactive (`-p`) + auto mode: classifier aborts on repeated blocks (avoids infinite loop).

## Typical use cases

| Case | Model | Parallelism | Notes |
|-------|-------|--------|------|
| Bulk type conversion (any → unknown) | Haiku | 8-16 | Verify with typecheck |
| Log format unification (console.log → logger) | Haiku | 8 | Regex verify also OK |
| Import path bulk rewrite | Haiku | 16 | Verify with build pass |
| React class → hooks migration | Sonnet | 4-8 | Verify with test pass; Haiku quality insufficient |
| SQL migration bulk generation | Sonnet | 2-4 | Needs schema read, low parallelism |
| i18n key extraction → JSON | Haiku | 8 | Verify with JSON schema |

## Notes

- **Always sample-verify results**: even OK returns may have quality issues — human review ~10%
- **Rate limits**: even Max plan has per-second request limits; increase `parallel -j` gradually
- **Decide commit granularity upfront**: per-file vs per-batch — tradeoff between revert ease and clean history
- **CI integration**: `claude -p` usable for auto lint fix in pre-commit hooks
