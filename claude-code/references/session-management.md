# セッション管理

長期タスク（複数日、大型機能、複雑調査）でのClaude Codeセッション運用。

## コマンド

| コマンド | 用途 |
|---------|------|
| `claude --continue` | 直前セッション再開（最も高頻度） |
| `claude --resume` | 最近のセッションから選択再開。検索ボックスに PR URL 貼付で該当 PR を作成したセッションを検索（GitHub/GHE/GitLab/Bitbucket 対応、2.1.122+） |
| `/rename <name>` | 現在のセッションに名前付与 |
| `Esc + Esc` / `/rewind` | checkpoint復元（セッション終了後も永続） |
| `/clear` | コンテキスト完全リセット（別タスク切替時） |

## 権限モード方針

| モード | 用途 |
|------|------|
| 通常モード | デフォルト。重要操作は都度承認 |
| Auto Mode（Max/Team/Enterprise 限定） | `claude --help` の `auto-mode` subcommand 参照。許可リスト整備済み環境で都度承認を抑制 |
| `--dangerously-skip-permissions` | 常用非推奨。sandbox 等の隔離環境専用。2.1.126 以降は `.claude/`、`.git/`、`.vscode/`、shell 設定ファイルへの書き込みもバイパス対象（catastrophic 削除のみ確認継続） |

> 出典: Opus 4.7 リリース後の運用ガイド（[Qiita @ot12 2026-04-16](https://qiita.com/ot12/items/06420caf41a34a910c53)、二次情報）。Anthropic 公式 docs での明文化は未確認のため、運用判断材料として扱う。

`--dangerously-skip-permissions` を毎回付ける運用は廃止する。許可リスト不足が原因なら `/fewer-permission-prompts` で半自動整備し、実行後 `~/.claude/settings.json` の `permissions.allow` を確認、不足分は手動追記する。

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

## マルチセッション並列運用（Boris流）

複雑機能・独立タスク並走時の運用パターン。Boris Cherny の公開運用例（howborisusesclaudecode.com）では複数セッション並列を主回路として扱う。理由は単一セッションの待ち時間（thinking / tool 実行）が直列ボトルネックになるため、複数セッション同時走行で人間側の手待ちを解消する。

| 項目 | 推奨 |
|------|------|
| 同時セッション数 | 3〜5（Boris 公開運用例の上限。それ超で通知洪水と context 追跡破綻） |
| 作業ディレクトリ | 各セッション別 git worktree（`git worktree add`） |
| 識別 | ターミナルタブに番号 1〜5、`/rename {type}-{scope}` |
| 通知 | `hooks/teammate-idle.sh` で入力催促を OS 通知 |
| 用途 | 独立タスク（FE/BE/test）、A/B 試行、長時間 verify と並行実装 |

**worktree 自動化との使い分け:**

- 短期・自動独立タスク → `/flow --parallel` / `/flow --parallel --auto` / `/dev --parallel` の `isolation: "worktree"`（自動作成・自動クリーンアップ）
- 長期・人間判断介在 → 手動 `git worktree add` + 個別ターミナルセッション

判定式・適用条件・後片付け方針詳細: `references/PARALLEL-PATTERNS.md` 参照。

**避けるべきパターン:**

- 同一ファイル並列編集（衝突確定）
- セッション間で context を口頭共有（再現不能）
- 5 並列超え（人間が追えない、通知洪水）

上記3アンチパターンに共通する本質は「人間が状況を追えなくなる」こと。並列度より追跡可能性を優先する。

参考: [howborisusesclaudecode.com](https://howborisusesclaudecode.com/)
