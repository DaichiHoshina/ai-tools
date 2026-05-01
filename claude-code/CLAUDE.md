# claude-code ディレクトリ固有設定

**genshijinモード（通常）で応答すること。** 敬語不要、体言止め、助詞最小限、技術用語はそのまま維持。破壊的操作の確認時のみ通常日本語に戻す。

このディレクトリはClaude Code用の設定・スキル・フックを管理。

## 構造

```
claude-code/
├── commands/      スラッシュコマンド定義
├── skills/        スキル定義
├── hooks/         イベントフック
├── guidelines/    言語・設計ガイドライン
├── agents/        エージェント定義
└── references/    参考資料（必要時参照）
```

## 編集時の注意

- `install.sh`/`sync.sh` 更新後は `~/.claude/` に同期必要
- 🔒 PROTECTED SECTION（CLAUDE.md内）は変更禁止
- frontmatter（---で囲まれた部分）は正確なYAML形式を維持
- **`claude-code/VERSION` は Claude Code CLI本体のバージョン追従用**。CLI リリース取り込み時のみ更新（`/claude-update-fix` 担当）

## 定義ファイルのトークン節約原則

commands/, skills/, agents/ の.mdファイルはセッション中にトークン消費される。

**残す**: 判定表・ワークフロー定義・操作ガード・禁止事項・入出力フォーマット（1例のみ）
**削除**: サンプル実装コード・重複説明・詳細使用例・他ファイルと重複する内容
**目安**: agent定義 300行以内、コマンド定義 150行以内、skill 100-130行

## 探索・調査の使い分け（濫用防止）

agent 起動コスト（中央値 数十秒〜数分）が最大コスト源。

| 調査規模 | ツール |
|---------|--------------|
| 1-2ファイル・特定シンボル | Bash grep/find または `mcp__serena__find_symbol` |
| 3-4クエリの広域探索 | `/explore`（曖昧時 2 並列、領域 3 つ以上で全 4 並列） |
| Claude Code CLI/SDK/API の仕様質問 | claude-code-guide agent |
| それ以外で本当に広域分析が必要 | Explore（built-in、最終手段） |

**`general-purpose` agent は原則使わない**（実測で最大コスト源）。計測: `references/performance-insights.md`

## セッション効率化

- 単純修正（1-2ファイル）→ `/dev --quick` または直接実行
- 複雑実装（3ファイル以上）→ `/flow` でAgent階層使用
- 大量ファイル処理（20+）→ `claude -p` fan-out（`references/fanout-recipes.md`）
- **設計判断**: 軽量は `Shift+Tab` ネイティブ Plan Mode、大規模戦略は `/plan`（PO agent）
- **長期タスク**: `/rename {type}-{scope}` で識別、`claude --resume` で再開（`references/session-management.md`）
- **軽い調査は agent 起動しない**: 1-2クエリなら直接 grep/find/serena
- **成功基準原則**: 手順指示より「何が達成されれば成功か」を与える
- **検証ファースト**: 実装後は必ずテスト/lint/型チェック実行（DoD 後述）
- **確認質問最小化**: 安全な操作は承認求めず即実行。確認必要はファイル削除・デプロイ・外部送信のみ
- **選択肢提示は最小限**: 軽微な選択は推奨案を直接実行。重要判断（アーキテクチャ・破壊・費用・外部送信・不可逆）のみ2-3案
- **パス決め打ち禁止 / pwd 確認**: Read/Bash 前に存在確認、`cd` 前に `pwd` 確認
- **Task Diary**: `/memory-save` 提案は3ファイル以上変更・非自明リファクタ・インシデント対応時のみ

## Rewind / Checkpoint

- **Esc**: 途中停止（コンテキスト保持）
- **Esc + Esc** or `/rewind`: 会話・コード・両方を過去checkpointに復元
- 詳細: `references/checkpoint-rewind.md`

## コンテキスト管理

- **コンテキスト50%超え → 次レスポンス冒頭で `/compact` 提案**（自動実行はしない）
- 無関係タスク間は `/clear` でコンテキストリセット
- 汚染せず質問だけしたい時は `/btw`（オーバーレイ表示、履歴非保存）

## 自然言語トリガー（主要のみ）

| 入力 | 実行 |
|------|------|
| "push", "pushして" | `/git-push --pr` |
| "全自動で", "autoで", "おまかせ" | `/flow-auto` |
| "レビュー", "レビューして" | `/review`（モード自動推定） |
| "{strict\|fast\|normal} mode" | `/session-mode {強度}` |
| "並列実行で", "wt 分けて" | `/flow --parallel` |

上記以外は自然語解釈しない（誤判定・トークン消費回避）。全リスト: `references/natural-language-triggers.md`

## Git マージ禁止ルール

| 操作 | ルール |
|------|--------|
| PRブランチのマージ（`gh pr merge`等） | **絶対禁止**。PR URL出力してブラウザ案内 |
| git merge / リベース / ブランチ削除 | ユーザー確認必須 |

## 完了基準（DoD）

「検証ファースト」の具体化。**該当する基準のみ適用、N/A は skip**。変更規模に応じてスケール（typo は項目6のみ、新機能は全項目）。

1. 型: 0 エラー（型システム言語のみ）
2. テスト: 関連範囲が全 Pass。カバレッジ ≥ 80%（プロジェクト基準優先）
3. Lint: 0 違反
4. セキュリティ: audit クリア
5. ビルド: 成功
6. **実挙動: 手動 or smoke test で1回確認**（必須）

束ね: `/lint-test`（CI 相当）/ `/verify-once`（構造変更時）。未達なら完了報告禁止。

## 根本原因分析

対症療法でなく根本治療。**再現→原因特定→設計判断→検証** の4ステップ必須。詳細: `/root-cause` skill, `/protection-mode`。

## Compounding Engineering（複利的改善）

Claude の誤動作・非自明な成功は設定（CLAUDE.md / skill / hook）に未反映の判断が残っているサイン。即追記で翌セッション以降は自動回避（Boris流）。1回の追記で N 件の修正手間を消すため改善が積み上がる。

- **誤動作**: CLAUDE.md / skill / hook に追記して再発防止
- **非自明な成功**: 同様にルール化して再現可能化
- 修正指示末尾に「CLAUDE.md か該当 skill を更新して再現できるように」と付け加えれば設定追記まで実行
- 詳細: `references/compounding-engineering-cycle.md`、`references/memory-usage.md`

## 詳細リファレンス

| トピック | ファイル |
|---------|---------|
| モデル選択・effort | `references/model-selection.md` |
| 自然言語トリガー全リスト | `references/natural-language-triggers.md` |
| レビューコマンド使い分け | `references/review-commands.md` |
| メモリ使い分け | `references/memory-usage.md` |
| 複数リポジトリ横並び | `references/multi-repo-workflow.md` |
| UIデフォルト設定 | `references/ui-defaults.md` |
| インシデント対応フロー | `references/incident-flow.md` |
| Checkpoint / Rewind | `references/checkpoint-rewind.md` |
| セッション管理 | `references/session-management.md` |
| claude -p Fan-out | `references/fanout-recipes.md` |
| Agent コスト実測 | `references/performance-insights.md` |
| 設計フェーズ遷移 | `references/design-phase-flow.md` |
| /flow vs /groove 使い分け | `references/flow-vs-groove.md` |
| コマンド × リソース対応 | `references/command-resource-map.md` |
| DesignDoc 書き方・粒度 | `references/design-doc-writing-guide.md`, `references/design-doc-scope-guide.md` |
| PRD レビュー観点 | `references/prd-review-checkpoints.md` |
| パフォーマンス改善 issue | `references/performance-issue-template.md` |
| レビュー指摘パターン集 | `references/review-patterns-universal.md` |
| ドキュメント書き直し | `references/document-iteration-patterns.md` |
| Compounding Engineering | `references/compounding-engineering-cycle.md` |
| Private 設定の保管規約 | `references/private-config-convention.md` |
