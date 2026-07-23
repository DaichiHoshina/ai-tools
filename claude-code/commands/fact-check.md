---
allowed-tools: Bash, Read, Grep, Glob, Task, mcp__serena__*
description: 提案 (brainstorm/agent report/plan の候補 list) の主張を wc/grep で実物と突き合わせて採否判定し、reviewer-agent で第 3 者 review する 1 pass loop
argument-hint: "[proposal file path / plan file / chat 直貼りの item list]"
---

# /fact-check - 提案の実物突き合わせ + 改善 + review

> **Goal**: brainstorm / explore-agent / plan の「候補 item list」を実装に流す前に、主張と実物を突き合わせて採否判定する。「cost S 見積 → 実物 37 行 = ROI 不足で見送り」のような判断を明示的な pattern として回す。

## When to use (棲み分け)

| Command / skill | Use |
|---|---|
| `/brainstorm` | 発散、複数案を出す |
| **`/fact-check`** | brainstorm / agent 出力を実物と突き合わせて採否判定する (本 command) |
| `/grill` | 設計案の穴を炙る (前提監査、read-only、質問生成のみ) |
| `/plan` | verified な案を Phase 分解する |
| `/verify-once` | 実装後の syntax / test 通し (別 layer) |

順序: `/brainstorm` → **`/fact-check`** → `/plan` → `/dev` → `/verify-once`

`/grill` との差: grill は「前提が正しいか」を質問で炙る (read-only)、fact-check は「見積が実物と一致するか」を grep/wc で測る (実測)。両者は補完関係で、grill → fact-check の順で流すと厚みが出る。

## Flow (3 phase、fail = 途中結果を出して stop)

### Phase 1: verify (実物突き合わせ)

1. 入力 (file path / chat 貼付) から item list を抽出する。bullet / 番号 list / 表の 1 行 = 1 item と扱う
2. 各 item の主張から検証対象を推定し、下記表の command で実測する

| 主張 pattern | 実測 command |
|---|---|
| 「cost S/M/L」「LOC N 行」 | `wc -l <file>`、関数数は `grep -c '^[a-z_]*() *{' <file>` |
| 「参照 N 件」「未使用」 | `grep -rc "<symbol>" <search-scope> \| awk -F: '{s+=$2} END{print s}'` |
| 「重複」 | `diff -q <a> <b>` / `comm -12 <(sort a) <(sort b)`、一致率は行数比較 |
| 「肥大化」 | `wc -l <sibling-dir>/* \| sort -rn` で分布内順位を出す |
| 「参照 0 件」 | `rg -l "<name>" -g '!<name-itself>'` で 0 行を確認 |
| 「gitignore 対象」 | `git check-ignore -v <path>` で ignore rule を出す |

3. 主張と実測の乖離を 3 段階で判定する:
   - **verified**: 主張と実測が一致 → 採用推奨
   - **adjusted**: 乖離小 (cost 見積が 1 段ずれる程度) → 実測値で再見積
   - **rejected**: 乖離大 (前提が崩れる) → 見送り or 代替案

### Phase 2: improve (改善案)

- rejected item に対し、狙いを達成する代替案を 1 つ提案する。代替不能なら「見送り」で終える
- adjusted item は再見積後の推奨アクションを 1 行で示す
- verified item はそのまま採用推奨

### Phase 3: review (reviewer-agent で第 3 者 check)

Phase 1-2 の結果を reviewer-agent に渡す。以下の 3 観点を prompt に含める:

1. verify の突き合わせ観点は網羅的か (実測から漏れた前提はないか)
2. adjusted / rejected 判定の根拠は実測値と一致するか
3. improve の代替案は本来の狙いを外していないか

reviewer-agent の trailer (status / confidence / issues_blocking) を必ず読む (canonical: `references/agent-output-schema.md`)。判定:

- P0 / P1 finding が残っている → 「実装 hold、改善案の再検討要」
- P2 以下のみ → 「実装 go、Next command は `/plan` or `/dev`」
- reviewer-agent trailer 不足 → status: failure 扱い、user escalate

## 出力形式

```
# /fact-check result

## Item 1: <主張の 1 行要約>
- 主張: <cost / LOC / 参照数 等>
- 実測: <wc -l / grep -c の値>
- 判定: verified / adjusted / rejected
- 根拠: <1 行、実測値と主張の突き合わせ結果>
- 改善案 (adjusted / rejected のみ): <1 行>

## Item N: ...

## Review (reviewer-agent)
- status / confidence / issues_blocking
- 見落とし観点: ...
- 判定根拠の妥当性: ...
- 代替案の妥当性: ...

## Verdict
- 実装 go: [item 番号 list]
- 改善後再検討: [item 番号 list]
- 見送り: [item 番号 list]

## Next command
[実装 go 分を渡す `/plan --go <task>` or `/dev <task>` を copy-paste 可能な 1 行]
```

## Failure Handling

| Situation | Behavior |
|---|---|
| 入力に item が抽出できない | 入力形式 (bullet / 番号 list / 表) を指定して再実行を促す |
| 実測 command が実行不能 (path 不存在等) | その item を「実測不能」として adjusted 扱いにし、user に確認 |
| reviewer-agent 起動失敗 | Phase 1-2 の結果のみ出力、「review 未実施」を明記して user escalate |
| reviewer-agent trailer 欠落 | status: failure 扱い、reviewer 再起動を推奨 |

## Notes

- **1 pass 固定**: max 1 iteration。review で hold が出た場合の再 loop は `/fact-check` を user が手で再発火する (auto 循環は goal drift を招くため入れない)
- **dogfooding 前提**: 本 command 自体も、brainstorm 出力に対して回して「Phase 4 skip 判断」相当を再現できるかを update 時に確認する
- **reviewer-agent の subagent_type 固定**: `Task(subagent_type="reviewer-agent")` を使う。`general-purpose` 禁止 (CLAUDE.md Discovery Routing)

ARGUMENTS: $ARGUMENTS
