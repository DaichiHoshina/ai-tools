# モデル選択指針

デフォルト: **Sonnet 4.6**（`claude-sonnet-4-6`）

## 手動切替

| タスク | 推奨モデル | モデルID | 切替 |
|--------|-----------|---------|------|
| バッチ処理、型変換、フォーマット整形、大量ファイル処理 | Haiku 4.5 | `claude-haiku-4-5-20251001` | `/model` → haiku |
| 単純修正、調査、コード読解、通常開発 | **Sonnet 4.6**（デフォルト） | `claude-sonnet-4-6` | そのまま |
| 根本原因分析、設計判断、複雑バグ解析、セキュリティ監査 | Opus 4.7 | `claude-opus-4-7` | `/model` → opus |
| タスク難易度が不明、動的な使い分け | Auto（Max subscribers限定） | - | `/model` → auto |

**モデル切替は明示 `/model` を推奨**（自然語トリガーは誤判定リスクのため不使用）。

**Auto Mode**（v2.1.111〜）: Max subscribers は Opus 系ベースで利用可能。`--enable-auto-mode` フラグ不要化。タスク難易度に応じて Claude が自動でモデル切替。

## エージェント別自動割り当て

各 agent の frontmatter で指定済み。

**方針**: parent (chat) を Opus 4.7 で指揮、subagent は判断系=Opus 4.7 / 実行系=Sonnet 4.6 に分離 (2026-06-05〜、判断品質向上のため subagent 統一方針から分離方針に変更)。

- **Opus 4.7 (判断系 subagent)**: po-agent (戦略 / 設計判断), manager-agent (task decomp / 並列度算定), reviewer-agent (12 観点 review / 品質判定), root-cause-analyzer (複雑バグ解析 / 5 Why)
- **Sonnet 4.6 (実行系 subagent)**: developer-agent (impl / refactor), explore-agent (read-only 探索), verify-app (build / test 実行)

## effortレベル

`--effort`フラグまたは`/effort`でセッション単位の思考深度を制御。

| レベル | 用途 | 例 |
|--------|------|-----|
| `low` | 単純な質問、フォーマット修正 | `claude --effort low -p "fix typo"` |
| `medium` | 軽めの開発・調査（コスト抑えめ） | `claude --effort medium` |
| `high` | 通常開発 | `claude --effort high` |
| `xhigh` | 高難度タスク・設計判断・深い分析（Opus 系で利用可能） | `claude --effort xhigh` |
| `max` | 最難デバッグ・大規模RCA。常用非推奨（overthinking で逆効果になる報告あり） | `claude --effort max` |

> `xhigh` は Opus 系限定（v2.1.111〜、`claude --help` の `--effort` choices で確認可）。Opus 4.7 では `effort` default が `high`。他モデルでは `high` にフォールバック。
> 運用方針の出典: Opus 4.7 リリース後の運用ガイド（[Qiita @ot12 2026-04-16](https://qiita.com/ot12/items/06420caf41a34a910c53)、二次情報）。Anthropic 公式 docs での明文化は未確認、コミュニティ知見として参照する。

スクリプトで`--print`使用時は`--fallback-model sonnet`で過負荷時の自動フォールバックも指定可能。
