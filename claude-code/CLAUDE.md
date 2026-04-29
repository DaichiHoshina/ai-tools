# claude-code ディレクトリ固有設定

**genshijinモード（通常）で応答すること。** 敬語不要、体言止め、助詞最小限、技術用語はそのまま維持。破壊的操作の確認時のみ通常日本語に戻す。

このディレクトリはClaude Code用の設定・スキル・フックを管理。

## 構造

```
claude-code/
├── commands/      スラッシュコマンド定義
├── skills/        スキル定義（レビュー、開発、インフラ等）
├── hooks/         イベントフック（session-start等）
├── guidelines/    言語・設計ガイドライン
├── agents/        エージェント定義
└── references/    参考資料（必要時参照）
```

## 編集時の注意

- `install.sh`/`sync.sh` を更新したら `~/.claude/` に同期必要
- 🔒 PROTECTED SECTION（CLAUDE.md内）は変更禁止
- frontmatter（---で囲まれた部分）は正確なYAML形式を維持
- **`claude-code/VERSION` は Claude Code CLI本体のバージョン追従用**。設定変更ごとに bump しない。CLI リリース取り込み時のみ更新（`/claude-update-fix` 担当）

## 定義ファイルのトークン節約原則

commands/, skills/, agents/ の.mdファイルはセッション中にトークンとして消費される。

**残す**: 判定表・ワークフロー定義・操作ガード・禁止事項・入出力フォーマット（1例のみ）
**削除**: サンプル実装コード・重複説明・詳細使用例・他ファイルと重複する内容
**目安**: agent 定義は300行以内、コマンド定義は150行以内

## 探索・調査の使い分け（濫用防止）

agent 起動コスト（中央値 数十秒〜数分）が最大コスト源。

| 調査規模 | ツール |
|---------|--------------|
| 1-2ファイル・特定シンボル | Bash grep/find または `mcp__serena__find_symbol` |
| 3-4クエリの広域探索 | `/explore`（explore-agent×4 並列） |
| Claude Code CLI/SDK/API の仕様質問 | claude-code-guide agent |
| それ以外で本当に広域分析が必要 | Explore（built-in、最終手段） |

**`general-purpose` agent は原則使わない**（実測で最大コスト源）。計測データ: `references/performance-insights.md`

## セッション効率化

- 単純修正（1-2ファイル）→ `/dev --quick` または直接実行
- 複雑実装（3ファイル以上）→ `/flow` でAgent階層使用
- 大量ファイル処理（20+）→ `claude -p` fan-out（`references/fanout-recipes.md`）
- **実装前の設計判断**: 軽量は `Shift+Tab` でネイティブ Plan Mode（read-only、`Ctrl+G` で plan 編集）。大規模戦略判断は `/plan`（PO agent）
- **長期タスク**: `/rename {type}-{scope}` で識別、`claude --resume` で再開（`references/session-management.md`）
- **軽い調査は agent 起動しない**: 1-2クエリなら直接 grep/find/serena（起動コスト 30秒〜数分）
- **成功基準原則**: 手順指示より「何が達成されれば成功か」を与える
- **検証ファースト**: 実装後は必ずテスト/lint/型チェック実行。検証できない変更は出荷しない（詳細: 後述「完了基準（DoD）」）
- **確認質問最小化**: 安全な操作（読み取り・検索・分析）は承認を求めず即実行。「〜してもいいですか？」型の質問禁止。判断必要なのはファイル削除・デプロイ・外部送信のみ
- **選択肢提示は最小限**: 軽微な選択は推奨案を直接実行（理由明記）。重要判断（アーキテクチャ、破壊的操作、費用発生、外部送信、不可逆変更）のみ2-3案提示
- **パス決め打ち禁止 / pwd 確認**: Read/Bash でパス指定前に `ls`/`find`/`Glob` で存在確認。`cd` や相対パス使用前は `pwd` を確認（既に対象ディレクトリ内で更に `cd subdir` を実行する誤りを防ぐ）。tool-failures.log の最頻エラー源
- **Task Diary**: `/memory-save` 提案は3ファイル以上変更・非自明リファクタ・インシデント対応時のみ（詳細: `references/memory-usage.md`）

## Rewind / Checkpoint

- **Esc**: Claude を途中停止（コンテキスト保持）
- **Esc + Esc** or `/rewind`: 会話・コード・両方を過去checkpointに復元
- 「試してダメならrewind」前提で risky 変更を走らせる方が計画より早い場合あり
- 詳細: `references/checkpoint-rewind.md`

## コンテキスト管理

- **コンテキスト使用率50%超えたら、次レスポンス冒頭で `/compact` 提案**
- 自動実行はしない（情報欠落リスク）。ユーザー承認後に実行
- compact時必須保持: 変更済みファイル一覧、現在のタスク状態、テストコマンド、アーキテクチャ決定事項
- 無関係タスク間は `/clear` でコンテキストリセット
- 汚染せず質問だけしたい時は `/btw`（オーバーレイ表示、履歴非保存）

## 自然言語トリガー（主要のみ）

| 入力 | 実行 |
|------|------|
| "push", "pushして" | `/git-push --pr` |
| "main push" | `/git-push --main` |
| "全自動で", "autoで", "おまかせ" | `/flow-auto` |
| "横並びで", "同じ修正を" | 複数リポジトリ作業（`references/multi-repo-workflow.md`） |
| "レビュー", "レビューして" | `/review`（モード自動推定） |
| "PR<番号>レビュー" | `/review <PR>` |
| "codexでレビュー" | `/review --codex` |
| "設計レビュー", "敵対レビュー", "アーキテクチャレビュー" | `/review --adversarial` |
| "深掘りレビュー", "厳しめレビュー", "徹底レビュー" | `/review --deep` |
| "リリース前レビュー", "全部入りレビュー" | `/review --multi <PR>` |
| "クラウドでレビュー" | `/ultrareview` |
| "レビュー→修正→push", "まとめてレビュー対応" | `/review-fix-push`（review + dev 全修正 + 再review + push） |
| "ブレスト", "設計検討" | `/brainstorm` |
| "{strict\|fast\|normal} mode" | `/session-mode {強度}` |

上記以外は自然語解釈しない。明示コマンドを使う（誤判定・トークン消費回避）。全リスト: `references/natural-language-triggers.md`

## Git マージ禁止ルール

| 操作 | ルール |
|------|--------|
| PRブランチのマージ（`gh pr merge`等） | **絶対禁止**。PR URL出力してブラウザ案内 |
| git merge（ローカル） | ユーザー確認必須 |
| MR/PRマージ（リモート） | ユーザー確認必須 |
| リベース | ユーザー確認必須 |
| ブランチ削除 | ユーザー確認必須 |

## 完了基準（DoD）

「検証ファースト」（前述）の具体化。**対象プロジェクトに該当する基準のみ適用、N/A な項目は skip**。
変更規模に応じてスケール（典型: 1行 typo は項目 6 のみ、新機能は全項目）。

1. 型: 0 エラー（型システムを持つ言語のみ。bash/md は N/A）
2. テスト: 関連範囲が全 Pass。カバレッジ計測ツール導入済みなら **行カバレッジ ≥ 80%**（プロジェクト基準があればそれに従う）
3. Lint: 0 違反（lint 設定があるリポジトリのみ）
4. セキュリティ: audit クリア（依存関係・シークレット）
5. ビルド: 成功（ビルド工程があるプロジェクトのみ）
6. **実挙動: 手動 or smoke test で1回確認**（全プロジェクト必須）

束ね: `/lint-test`（CI 相当一括）/ `/verify-once`（構造変更時）。未達なら完了報告禁止。

## 根本原因分析

対症療法（エラーを隠す）ではなく根本治療（原因を取り除く）。**再現→原因特定→設計判断→検証** の4ステップ必須。詳細: `/root-cause` skill, `/protection-mode` 品質ガード。

## Compounding Engineering（複利的改善）

Claude の誤動作・非自明な成功は設定（CLAUDE.md / skill / hook / auto-memory）に未反映の判断が残っているサイン。ユーザーまたは Claude 自身が即追記することで、同種ケースが翌セッション以降は自動回避される（Boris流）。実例として、本リポジトリでは「最優先」評価語の根拠不足指摘が3 commit 連続で発生 → writing self-check hook 化で commit 前検知に切替、以後同種指摘ゼロ。1回の設定追記で N 件の修正手間を消すため改善が積み上がる。

- **誤動作**: CLAUDE.md / skill / hook に追記して再発防止。auto-memory は Claude 自動判断ゆえ陳腐化しやすく、設定側のほうが再現可能性が高いため設定優先
- **非自明な成功**: 同様に CLAUDE.md / skill 化で再現可能な「ルール」として固定（詳細: `references/memory-usage.md` §記録対象）
- 修正指示の末尾にユーザーが「CLAUDE.md か該当 skill を更新して同じ判断を再現できるように」と付け加えれば、Claude が同会話で設定追記まで実行する
- 補助記憶として auto-memory（Claude 自動判断で書き込み）と Serena memory（`/memory-save` 手動）あり。書き込み経路の整理は `references/memory-usage.md` 参照
- 参考: [howborisusesclaudecode.com](https://howborisusesclaudecode.com/)

実運用は「誤動作 → 即 CLAUDE.md/skill 追記 → 翌セッションで自動回避」を1サイクルとして回す。

## 詳細リファレンス

| トピック | ファイル |
|---------|---------|
| モデル選択・effortレベル | `references/model-selection.md` |
| 自然言語トリガー全リスト | `references/natural-language-triggers.md` |
| レビューコマンド使い分け | `references/review-commands.md` |
| メモリ使い分け（auto-memory/Serena） | `references/memory-usage.md` |
| 複数リポジトリ横並び・PR分割 | `references/multi-repo-workflow.md` |
| UIデフォルト設定 | `references/ui-defaults.md` |
| インシデント対応フロー | `references/incident-flow.md` |
| Checkpoint / Rewind 活用 | `references/checkpoint-rewind.md` |
| セッション管理（rename/resume/命名規約） | `references/session-management.md` |
| claude -p Fan-out レシピ | `references/fanout-recipes.md` |
| Agent コスト実測 | `references/performance-insights.md` |
| 設計フェーズ遷移（brainstorm→prd→design-doc→plan→dev→docs） | `references/design-phase-flow.md` |
| /flow vs /groove 使い分け | `references/flow-vs-groove.md` |
| 主要コマンド × リソース対応表 | `references/command-resource-map.md` |
| DesignDoc 書き方の実践ノウハウ | `references/design-doc-writing-guide.md` |
| DesignDoc 粒度・テンプレ選択 | `references/design-doc-scope-guide.md` |
| PRD レビュー観点（人間レビュアー用） | `references/prd-review-checkpoints.md` |
| パフォーマンス改善 issue 進め方 | `references/performance-issue-template.md` |
| レビュー指摘パターン集（汎用） | `references/review-patterns-universal.md` |
| ドキュメント書き直しのフェーズ進行 | `references/document-iteration-patterns.md` |
