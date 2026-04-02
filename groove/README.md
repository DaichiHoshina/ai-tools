# groove - 軽量マルチエージェントオーケストレーター

YAMLでワークフローを定義し、複数のAgentを協調実行する仕組み。外部依存なし（Claude Code内で完結）。

## 構成

```text
groove/
├── workflows/     ワークフロー定義（YAML）
├── agents/        各ステップで使うAgent定義（Markdown）
├── config.yaml    プロバイダー設定
└── tests/         テスト
```

## 使い方

```text
/groove <task>                # ワークフロー自動選択
/groove <workflow> <task>     # ワークフロー指定
/groove --auto <task>         # 自動モード（完了後にcommit+push）
/groove list                  # ワークフロー一覧
```

## ワークフロー

| 名前 | 流れ | 選択キーワード |
|------|------|---------------|
| spec-driven | 仕様レビュー → Codexレビュー → 実装 → 受入検査 → 修正 → 簡素化 | デフォルト |
| tdd | テスト作成 → 実装 → レビュー → 修正 | テスト, TDD, test |
| vsdd | 仕様レビュー → テスト → 実装 → 敵対的レビュー → 修正 → 簡素化 | VSDD, 品質重視 |

## 配置と同期

このディレクトリはGit管理用のソース。実行時は `~/.groove/` が読み込まれる。

```text
ai-tools/groove/  ──(sync.sh to-local)──>  ~/.groove/
  (Git管理)                                   (実行時に参照)

ai-tools/groove/  <──(sync.sh from-local)──  ~/.groove/
                                              (ローカル編集の回収)
```

同期コマンド:

```bash
./claude-code/sync.sh to-local    # リポジトリ → ~/.groove/
./claude-code/sync.sh from-local  # ~/.groove/ → リポジトリ
./claude-code/sync.sh diff        # 差分確認
```

## パス解決（実行時）

| 優先度 | パス |
|--------|------|
| 1st | `.groove/`（プロジェクトローカル） |
| 2nd | `~/.groove/`（ホーム） |

プロジェクト固有のワークフローが必要な場合は、そのプロジェクト直下に `.groove/` を作れば優先される。
