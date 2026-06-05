# bats test writing standard

Developer agent (Sonnet) が bats 編集時に参照する canonical rule。CI detects violations.

## Forbidden patterns (pass-by-coincidence)

Test passing even with implementation deleted = worthless. Absolute prohibitions:

| Pattern | Reason |
|---------|--------|
| `[ -f "${LIB_FILE}" ]` alone | File existence only, no function call |
| `grep "^funcname()" "$LIB_FILE"` | Definition check only |
| `[ "$status" -eq 0 ] \|\| [ "$status" -eq 1 ]` | Binary assert, all results pass |
| `grep -q ... \|\| true` | Swallow grep failure |
| `echo 'ok'` at end | Always succeeds unless abort |
| `unset PATH` teardown | Later mktemp/rm fail |

## Required patterns

- ✅ **Actual function call**: `run bash -c "source '$LIB_FILE' && <function> <args>"`
- ✅ **Actual value assert**: Verify exit code, stdout, files, env vars, nameref output
- ✅ **External command verify**: stub script via PATH for real invocation
- ✅ **teardown safety**: `export PATH="$ORIG_PATH"` (save in setup)
- ✅ **Output verify**: `[[ "$output" =~ "<string>" ]]` or `[[ "$result" -ge N ]]`

## Self-verify (required)

After new/modified bats: temp no-op target function with `return 0` → rerun bats → **confirm tests turn red** → `git checkout` restore.

Non-red tests = pass-by-coincidence confirmed, rewrite required.

## Report format enforcement

bats task completion **must include**:

```
## bats self-verify result
- Old / new test count: XX / YY
- Function A deleted → red: ✓ (N tests)
- Function B deleted → red: ✓ (N tests)
- Full run: ✓ (YY tests)
```

Missing self-verify → reviewer suspects pass-by-coincidence, returns diff.
