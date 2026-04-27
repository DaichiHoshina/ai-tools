# `/review` 詳細リファレンス

`commands/review.md` から外出しした詳細仕様（agent table・集約方針・コメント JSON 形式・レビュー方針）。コマンド本体はサマリのみで、参照はここから。

## Deep フロー詳細（agent table）

`pr-review-toolkit` の6 agent を **1 message 内 6 Agent tool 同時呼び出し** で並列起動。

| subagent_type | 観点 |
|---------------|------|
| `pr-review-toolkit:code-reviewer` | CLAUDE.md準拠・ベストプラクティス |
| `pr-review-toolkit:silent-failure-hunter` | エラー握りつぶし・空 catch |
| `pr-review-toolkit:type-design-analyzer` | 型による不変条件表現 |
| `pr-review-toolkit:comment-analyzer` | コメント正確性・comment rot |
| `pr-review-toolkit:pr-test-analyzer` | テストカバレッジ・edge case |
| `pr-review-toolkit:code-simplifier` | コード簡素化・可読性 |

各 agent prompt に対象 diff（`git diff` or `gh pr diff <N>`）を埋め込む。**コスト警告**: agent 起動コストが大きい（数十秒〜数分×6並列）。日常は `/review` で十分。

集約: 信頼度80未満は Warning 降格、同一ファイル:行で観点違いはマージ。

## Multi フロー集約方針

| 状態 | 扱い |
|------|------|
| 3手段以上で指摘 | Critical 確定 |
| 2手段で指摘 | Critical |
| 1手段のみ | Warning |
| 信頼度80未満（comprehensive側） | Warning 降格 |

**重複除去**: 同一ファイル:行±3行で同種指摘は1件にマージ、ソース手段を `[plugin][codex]` 等で併記。

`/review --plugin` の単独投稿機能は `--multi` に統合済み。plugin だけ使いたい場合は `/code-review:code-review <PR>` を直接呼び出し。

## レビュー方針

- **厳しめ**: 見逃しより過検出を優先
- **差分のみ**: 既存コードへの指摘は行わない
- **大量の差分**: 1ファイルずつ
- **優先度**: Critical → Warning
- **具体的な修正案**: 指摘 + 改善方法
- **並列実行**: 11観点を並列

レビュー対象に含める: 変更ファイル（git diff）、新規追加。除外: auto-generated、vendor/node_modules、lock ファイル。

## difit 連携: コメント JSON 形式

```json
{
  "type": "thread",
  "filePath": "src/domain/user.ts",
  "position": { "side": "new", "line": 45 },
  "body": "🔴 Critical: [設計] ...\n\n修正案: ..."
}
```

- body prefix: Critical → `🔴 Critical:` / Warning → `🟡 Warning:`
- 行番号不明時は `line: 1`
- 全 finding を1つの `--comment '<JSON配列>'` で `difit staged` or `difit .` に渡す
