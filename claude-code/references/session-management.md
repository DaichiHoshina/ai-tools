# セッション管理

長期タスク（複数日、大型機能、複雑調査）でのClaude Codeセッション運用。

## コマンド

| コマンド | 用途 |
|---------|------|
| `claude --continue` | 直前セッション再開（最も高頻度） |
| `claude --resume` | 最近のセッションから選択再開 |
| `/rename <name>` | 現在のセッションに名前付与 |
| `Esc + Esc` / `/rewind` | checkpoint復元（セッション終了後も永続） |
| `/clear` | コンテキスト完全リセット（別タスク切替時） |
| `/focus` | 途中プロセス非表示・結果のみ表示。長時間セッションを横で見守らない運用に |
| Recaps | 復帰時のサマリー自動表示（Opus 4.7 公式推奨）。離席→復帰前提の長時間タスクで活用 |

## 権限モード（Opus 4.7 以降の方針）

| モード | 用途 |
|------|------|
| 通常モード | デフォルト。重要操作は都度承認 |
| **Auto Mode**（Max/Team/Enterprise 限定） | `/fewer-permission-prompts` で許可リスト整備済み環境向け公式代替 |
| `--dangerously-skip-permissions` | **常用非推奨**（Opus 4.7 公式ガイダンス）。Auto Mode が使えない場合の最終手段のみ |

`--dangerously-skip-permissions` を毎回付ける運用は廃止。許可リスト不足が原因なら `/fewer-permission-prompts` で半自動整備する。

## 命名規約

セッション名は `{type}-{scope}` 形式を推奨。grep/一覧で識別しやすい。

| type | 例 |
|------|-----|
| `migration-` | `migration-oauth`, `migration-react-19` |
| `debug-` | `debug-memory-leak`, `debug-flaky-test` |
| `investigate-` | `investigate-latency-spike` |
| `feature-` | `feature-billing-v2` |
| `refactor-` | `refactor-auth-middleware` |

Jira/Linearチケット連動時: `{ID}-{brief}` 形式（例: `PROJ-1234-oauth-flow`）。ID で `--resume` リストから即座に見つけられる。

## 使い分け判断

| 状況 | 推奨 |
|------|------|
| 5分以下の単発タスク | 名前付け不要、`/clear` でリセット |
| 30分超の調査・実装 | `/rename` で命名、ターミナル閉じてもOK |
| 別マシン・翌日以降再開 | `--resume` で選択、`--continue` は直前のみ |
| 調査→実装フェーズ移行 | **fresh セッション起動**（`/clear` or 新ターミナル）で実装。調査コンテキストを残さない |
| 複数機能を並行 | ターミナル別タブで個別セッション、各々 `/rename` |

## fresh 起動パターン（公式推奨）

> 調査・計画完了後、SPEC.md 等に書き出してから fresh セッションで実装開始

**理由**: 調査フェーズの失敗アプローチ・無関係ファイル読み込みが context に残ると実装品質低下。SPEC.md に固めて新セッションで始める方が速い。

```bash
# フェーズ1: 調査（Plan Mode or /brainstorm で SPEC.md 作成）
claude --rename investigate-oauth-design

# フェーズ2: 実装（fresh セッション）
claude  # 新規起動、SPEC.md を @ で参照
```

## よくある失敗

- **kitchen sink session**: 1セッションに無関係タスクを混ぜる → context 汚染、性能低下
- **長引いた session の修正合戦**: 2回以上の修正失敗 → `/clear` して better prompt で再起動
- **名前なしで複数並行**: `--resume` リストが全て `Untitled` で識別不能

## checkpoint との関係

- checkpoint はセッション終了後も保持（ターミナル閉じても残る）
- セッションA で実装 → 別の日に `--resume` → `Esc+Esc` で checkpoint 復元可能
- ただし git commit は別レイヤー。checkpoint は Claude の変更のみ追跡
