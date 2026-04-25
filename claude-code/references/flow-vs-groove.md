# /flow vs /groove 使い分け

両方ともマルチエージェント/コマンド連鎖を駆動するが、構成方法と用途が異なる。

## 本質的違い

| 観点 | `/flow` | `/groove` |
|------|---------|-----------|
| 構成方法 | **命令的判定型**（タスクキーワード→判定表でワークフロー固定） | **宣言的YAML型**（`.groove/workflows/*.yaml` で明示定義） |
| 自由度 | 判定表に列挙された 12 タスクタイプから自動選択 | 任意の Step/分岐/loop/parallel/aggregate を書ける |
| 学習コスト | ゼロ（タスク文を渡すだけ） | YAML スキーマ理解必要（`~/.groove/schema.md`） |
| 再利用性 | 判定表は session 内固定 | YAML は git 管理・チーム共有可 |
| Agent 階層 | PO → manager → developer×N → reviewer の固定階層 | Step 単位で任意の Agent 起動・並列・retry/error 分岐 |
| Provider | Claude のみ | Claude + codex（`provider: codex`） |
| 自動 push | `--auto` で /git-push --pr | `--auto` で COMPLETE 後に /git-push --pr |

## 使い分け基準

### `/flow` を使う

- 判定表（バグ修正/新機能/リファクタ/インシデント等）に該当する **典型タスク**
- ワークフロー設計に時間をかけたくない
- PO Agent 経由の戦略判断を活用したい
- Team 階層（po → manager → dev → reviewer）の標準パターンで十分

### `/groove` を使う

- 判定表に当てはまらない **独自フロー**（例: VSDD の spec → test → impl → verify ループ）
- 同じワークフローを **繰り返し実行** したい（YAML を共有資産化）
- codex とのアンサンブル（複数 LLM provider 並列）が欲しい
- retry/error 分岐や aggregate priority など **細かい制御** が要る
- ワークフロー定義そのものをレビュー対象にしたい

## 境界が曖昧なケース

| ケース | 推奨 | 理由 |
|------|------|------|
| 「テスト先・実装後・レビュー」固定パターン | `/groove tdd` | YAML テンプレあり、再利用可 |
| 「typo 修正してテストして push」単発 | `/flow` | 判定表「修正」マッチで十分 |
| 大型機能で多 Step、毎回少しずつ違う | `/flow` | 判定で柔軟、毎回 YAML 書くコスト不要 |
| チーム標準ワークフローを徹底したい | `/groove` | YAML を git 共有・PR レビュー可 |

## 既存 YAML

`/groove list` で一覧。標準: `vsdd`、`tdd`、`spec-driven`。

## 制約

- `/flow`: subagent は subagent を spawn 不可（各層は親が起動）
- `/groove`: parallel 時の edit mode は worktree 自動付与、変更ありはマージ統合必要
