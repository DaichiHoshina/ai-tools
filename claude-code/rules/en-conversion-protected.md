# EN 化保護対象 file (英語化禁止)

`/claude-update-fix` / EN 化系 refactor / developer-agent 委譲 で **絶対に英語化してはいけない** file・section リスト。違反すると規約破壊・bats test 破壊・JP user input trigger 不一致が発生する。

## File 単位 (body 全文 JP 維持)

- `rules/genshijin.md` — 規約 file 自体が JP、EN 化で規約と矛盾
- `commands/jp-writing.md` — JP writing 例示が規範 (frontmatter は EN OK、body のみ保護)
- `commands/post-comment.md` — 同上
- `commands/design-doc.md` — 同上
- `commands/prd.md` — 同上
- `guidelines/writing/*.md` (全 9 file) — 執筆規約・NG 辞書 56K chars、JP 文体規範

## Section 単位 (file 内一部のみ JP 維持)

- `CLAUDE.md` "## Genshijin Boundary" section (現在 L134-136 付近) — genshijin 規約説明本文
- `CLAUDE.md` "## Natural Language Triggers (major only)" section (現在 L86-100 付近) — table 内 JP trigger ("pushして" / "全自動で" / "レビュー" 等) は user 入力 pattern なので literal 維持必須
- `CLAUDE.md` 冒頭注 (現在 L3) — genshijin mode 説明
- `references/PARALLEL-PATTERNS.md` `forbidden_phrases` section (現在 L162-166 付近) — bats test が exact-match で検証する JP literal

> 上記 line 番号は参考値。CLAUDE.md は頻繁更新されるため section heading 名で grep して位置確認すること。

## Literal 維持 (技術的理由)

- 全 Go code block — technical idiom、コメントは JP のまま
- bats test の expected output / fixture 内 JP literal — test assertion 破壊回避

## 違反時の影響

| 対象 | 違反時症状 |
|------|----------|
| `rules/genshijin.md` | 規約 file が EN だと genshijin モード自体が矛盾 |
| `commands/{text,post-comment,...}.md` body | JP writing 例示が EN になり command の本来用途破壊 |
| `guidelines/writing/*` | NG 辞書の JP literal 消失で執筆検証不能 |
| CLAUDE.md Natural Language Triggers | "pushして" 等の trigger 不一致で `/git-push --pr` 自動発火失敗 |
| `PARALLEL-PATTERNS.md` forbidden_phrases | `tests/integration/parallel-consistency.bats` が exact-match 失敗 |

## 参照元

- `CLAUDE.md` "## Definition File Token Saving" section の末尾
- developer-agent / `/claude-update-fix` 委譲 prompt template (将来追加)
