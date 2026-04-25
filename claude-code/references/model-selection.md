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

**Auto Mode**（v2.1.111〜）: Max subscribers は Opus 4.7 ベースで利用可能。`--enable-auto-mode` フラグ不要化。タスク難易度に応じて Claude が自動でモデル切替。

## エージェント別自動割り当て

各 agent の frontmatter で指定済み。

- **Opus 4.7**: reviewer-agent, root-cause-analyzer（深い分析）
- **Sonnet 4.6**: po-agent（戦略判断）, manager-agent（タスク分割・Developer並列配分判断）
- **Haiku 4.5**: developer-agent, explore-agent, verify-app（低コスト処理、実時間はタスク範囲依存）

## effortレベル

`--effort`フラグまたは`/effort`でセッション単位の思考深度を制御。

| レベル | 用途 | 例 |
|--------|------|-----|
| `low` | 単純な質問、フォーマット修正 | `claude --effort low -p "fix typo"` |
| `medium` | 軽めの開発・調査（コスト抑えめ） | `claude --effort medium` |
| `high` | 通常開発 | `claude --effort high` |
| `xhigh` | 高難度タスク・設計判断・深い分析（Opus 4.7 で利用可能） | `claude --effort xhigh` |
| `max` | 最難デバッグ・大規模RCA。常用非推奨（overthinking で逆効果になる報告あり） | `claude --effort max` |

> `xhigh` は Opus 4.7 限定（v2.1.111〜、`claude --help` の `--effort` choices で確認可）。他モデルでは `high` にフォールバック。
> 運用方針の出典: Opus 4.7 リリース後の運用ガイド（[Qiita @ot12 2026-04-16](https://qiita.com/ot12/items/06420caf41a34a910c53)、二次情報）。Anthropic 公式 docs での明文化は未確認、コミュニティ知見として参照する。

スクリプトで`--print`使用時は`--fallback-model sonnet`で過負荷時の自動フォールバックも指定可能。
