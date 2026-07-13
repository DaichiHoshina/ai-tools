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

## Execution pitfalls (green の誤認防止)

- `bats tests/` は再帰しない。直下に .bats がないと `1..0` (0 件実行) + exit 0 で gate が空振りする。常に `bats -r tests/` を使い、gate 化する前に単体実行で ok 件数を確認する
- bats を tail / grep / head に pipe すると exit code が末尾 command のものになり、fail を green と誤認する。判定は `grep -E "^not ok"` の出力有無か、pipe なし単独実行の exit code で行う
- hook の smoke は `bash hook.sh < /tmp/payload.json` の file 経由 stdin で行う。`echo '{...}' | bash hook.sh` は外側の pre-tool-use が dangerous literal に反応して打ち切られ、pipe 後の `$?` も hook でなく末尾 command の rc を拾う
- 新規 hook は bats と併せて ghq 実 path での smoke を 1 発実行する。symlink 表記 (`~/ai-tools/`) の fixture だけだと path prefix 誤りを検出できない (2026-06-08 social-hit block 半年不発の教訓)
- worktree 内で `pre-tool-use.bats` を走らせると cwd-guard が /tmp への Edit を block して 16 failure 出る。環境ノイズなので慌てず、hook bats の最終確認は main で行う

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
