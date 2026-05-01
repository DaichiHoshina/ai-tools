---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: 構造変更・hook・agent 定義の変更を1回で確定検証（syntax → unit → integration → 実挙動）
---

# /verify-once - 1回で確定させる検証

構造変更（hooks/, agents/, lib/, settings.json等）の挙動を1回で確定。二重検証・やり直しを防ぐ。

## いつ使う

| 変更対象 | 使う | 使わない |
|---------|------|---------|
| hooks/*.sh | ✓ | |
| agents/*.md frontmatter | ✓ | |
| lib/*.sh | ✓ | |
| settings.json.template | ✓ | |
| commands/*.md 本文のみ | | ✓（`/dev --quick`で十分） |
| skills/*/skill.md 本文のみ | | ✓ |

## フロー（順次実行、失敗で停止）

1. **syntax**: 変更された `.sh` 全件に `bash -n`、`.json` 全件に `jq empty`
2. **unit**: `tests/bats/*.bats` 該当テスト実行（変更ファイルに応じて絞り込み）
3. **integration**: `hooks-integration.bats` 等の統合テスト
4. **invariants**: `agent-frontmatter.bats`（agents 変更時のみ）
5. **実挙動**: 変更した hook をダミーJSON入力で実行、期待出力確認
6. **install 反映**: `~/.claude/` への sync.sh 同期 → 再実行で回帰なし確認

## 出力

```
1. syntax      : ✓ (3 files)
2. unit        : ✓ (12 tests)
3. integration : ✓ (39 tests)
4. invariants  : ✓ (7 tests)
5. 実挙動       : ✓ (hook returned expected JSON)
6. install     : ✓ (sync完了、再テストもPASS)

Result: VERIFIED. 再検証不要。
```

失敗時は該当ステップで停止し、エラー原因を根本修正提案（対症療法禁止）。

## 注意

- **1回で終わらせる**: 検証後に「もう一回確認したい」を発生させない。検証観点を最初に全部列挙
- 既存の `/lint-test` はCI一括実行、`/verify-once` は構造変更専用の **挙動検証**
- 統合テスト未整備なら先にテスト追加してから本検証（ADR 0001 方式）

## 失敗時の挙動

| 状況 | 動作 |
|------|------|
| `bash` / `jq` / `bats` 不在 | 該当 step を skip、Result に「skipped (tool not found)」記載 |
| 統合テスト未整備 | ADR 0001 方式に従い、先にテスト追加要求して停止 |
| install 反映後の再テスト失敗 | rollback 提案、原因を Phase 別に切り分け（syntax/unit/integration） |

失敗時の出力例:

```
1. syntax      : ✗ (1 file: hooks/foo.sh)
2. unit        : - skipped (syntax failed)
...

Result: FAILED at step 1
Root cause: hooks/foo.sh:42 - bash syntax error 'unexpected EOF'
```

ARGUMENTS: $ARGUMENTS
