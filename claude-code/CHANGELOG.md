# Changelog

このリポジトリの主要な変更履歴。[Conventional Commits](https://www.conventionalcommits.org/) に準拠。

## [Unreleased] - 2026-04-30

### Added: 並列実行リファクタ（境界 1-4）

#### 4 Developer 上限と worktree 責務統一（境界 1-2b）

- `PARALLEL-PATTERNS.md` を単一ソース化、並列実行の適用条件・worktree 隔離フロー・メモリ上限の根拠を一元管理
- `/flow --parallel` と `/dev --parallel` を分離：worktree は `/flow` 側（PO 管理）、`/dev` は通常実行に統一
- po-agent, manager-agent, developer-agent の worktree 責務を再設計：isolation 属性で自動化、PO 確認 → Manager task 分割 → Developer 並列実行

#### Manager 出力形式拡張 + 自然言語トリガー固定化（境界 3）

- Manager の出力に「並列実行 4 句のいずれか」を自然言語判定（`/flow --parallel`, `並列実行で`, `Developer 並列で`, `worktree 分けて`, `wt 分けて`）
- `/explore` 4 並列を最大許容としたトークンコスト最適化、曖昧な大規模探索は agent team 並列に統一
- 自然言語トリガー 4 句を `natural-language-triggers.md` に固定化、其他の曖昧トリガーは削除

#### 4 Developer 上限根拠・anchor テスト完全化（境界 4）

- `tests/integration/test_parallel_boundary.bats` に4 Developer上限anchor追加：同時セッション上限 5（親 + Dev×4）がメモリ実測根拠、PARALLEL-PATTERNS.md の判定式と同期
- bats 18 項目全 PASS、4 Developer 並列の safety assertion 実装完了

### Added: レビュー強化フルパッケージ

#### Phase 1: comprehensive-review 11観点化 + 信頼度フィルタ

- 観点を 9→11 に拡張: `silent-failure`（エラー握りつぶし）/`type-design`（型不変条件）追加
- 各 finding に **信頼度0-100** を付与、80未満は Warning 降格・25未満は破棄
- False positive チェックリスト導入（`code-review` plugin の rubric 準拠）
- `/review --deep`（pr-review-toolkit 6専門agent並列）/ `--multi <PR>`（4手段並列+PR fetch）/ `--plugin <PR>`（公式委譲） オプション追加

#### Phase 2: PR作成時の自動レビュー（opt-in）

- `/git-push --pr --auto-review` で PR 作成完了後に `code-review:code-review` + `coderabbit:code-review` を `Bash run_in_background:true` で並列起動
- `BashOutput` で各プロセスのエラー集約、失敗時は exit code・stderr 末尾10行を表示
- デフォルト OFF（CodeRabbit 課金影響配慮）、GitHub 限定

#### Phase 3: regression loop + 履歴蓄積 + 繰り返し検出

- `/review-fix-push` に Step 4 regression check 追加（修正後再レビュー、最大3回）
- レビュー履歴を `<repo>/.claude/review-history.jsonl` に jsonl 形式で蓄積
- 起動時に過去90日履歴をロード、同一 file:line±3+focus が3回以上で 🔁 繰り返し指摘マーク

#### Phase 4: analytics 履歴統計 + hook 危険パターン検出

- `/analytics` の `--mode full` に「レビュー履歴」セクション追加（観点TOP5・信頼度分布・繰り返し TOP5・前期比トレンド）
- `pre-tool-use.sh` に `detect_dangerous_patterns` 追加: AWS Key/PAT/sk-/Slack/Private key リテラルを Forbidden 昇格でブロック、SSRFクラウドメタデータ・SQL文字列連結・credential ハードコードを Boundary 警告

#### テスト

- `pre-tool-use.bats` に detect_dangerous_patterns 12件追加（hook 自身の検出を避けるため bash 隣接連結でリテラル分割）
- `tests/unit/scripts/test_analytics_review_history.py` 新設（stdlib unittest 12件）

#### 既存 bats 修正

- Forbidden 系8テストの `result=$(...)` で exit 2 を捕捉できない既存問題を `run bash -c` パターンへ移行
- 結果: 50/58 pass → **70/70 全 pass**

#### ドキュメント

- `references/command-resource-map.md` 新設（主要4コマンド × skill/guideline/agent/hook/rule 対応マップ）
- `references/review-commands.md` 全モード使い分け表に再構成

## [2.1.39] - 2026-02-23

### Fixed

- CI: shellcheckのmacOSインストール分岐を追加、bats globパターンをfind方式に修正
- CI: integrationテスト用ジョブ追加
- README/SKILLS-MAP: 数値を実態に合わせて更新
- stop.sh: macOS専用→クロスプラットフォーム対応
- sync.sh: `sync_from_local()` のDRY化、`.env` sourceのセキュリティ修正
- pre-compact.sh: `\n`リテラル→実改行に修正、保存内容を4項目に具体化
- CLAUDE.md: 旧コマンド名残存を修正

### Changed

- CLAUDE.md: ログ設計基準・RCA原則をガイドラインに外部化（150→96行、36%削減）
- Git pushコマンド3つ（commit-push-main/pr, branch-push-mr）を `/git-push` に統合
- po-agent: model を opus → sonnet に変更（コスト最適化）
- spec-agent: 未使用のためアーカイブに移動
- reload.md: compact-restore復元の優先順位と蓄積防止を明確化

### Added

- `guidelines/common/logging-standards.md` - ログ設計ガイドライン
- `commands/git-push.md` - 統合Gitコマンド（auto-sync、stash popエラーハンドリング含む）
- `CHANGELOG.md` - 変更履歴
- hooks連携の統合テスト9件追加
- CLAUDE.md: 自然言語トリガー追加（sync push、ブランチ切って修正等）

## [2.1.38] - 2026-02-18

### Changed

- PreToolUse を Boundary ツール限定に変更し、ログ系フックを async 化
- レビュー方針追加（厳しめ・差分のみ）

### Fixed

- review: 並列実行の記載が脱落していたのを復元

## [2.1.37] - 2026-02-15

### Added

- ログ設計基準を拡充（構造化ログ・必須フィールド・NotFound判断・禁止事項）
- logging 観点を7番目のレビュー観点として追加
- root-cause 観点をレビューに追加

### Changed

- ログレベルを error/warn/info の3段階に変更（debug 廃止）
- protection-mode/review/CLAUDE.md のトークン削減

## [2.1.36] - 2026-02-14

### Added

- retrospective: セッション分析に基づく改善を実施
- statusline.js: 型安全性強化 + Jest 31テスト追加
- 全フック統合テスト追加

### Changed

- flow: Agent Team起動を2段階方式に再設計
- エージェント・コマンド定義のトークン節約（2,947→667行、77%削減）

## [2.1.35] - 2026-02-08

### Added

- `/ui` コマンドをUI統合入口に拡張（6アクション対応）
- hooks: TeammateIdle / TaskCompleted フック追加

### Changed

- flow: 実態に合わせて整理（344→132行、62%削減）
- コマンド品質改善（allowed-tools統一・依存グラフ）

## [2.1.0] - 2026-01-24 (Phase 2)

### Added

- BATS単体テスト 151件追加（9ファイル）
- envsubst 全面移行（テンプレート生成の統一）
- detect 関数統合（user-prompt-submit.sh で技術スタック自動検出）

### Changed

- スキル統合: 24→20スキル（レビュー系5個を1個に統合、パラメータ化）
- 8原則の自動化（UserPromptSubmit Hook が最重要）

## [1.0.0] - 2026-01-02

### Added

- Initial commit: Claude Code 設定リポジトリ
- コマンド、スキル、ガイドライン、エージェントの基本構造
- install.sh / sync.sh による環境同期
- Hooks（SessionStart, PreToolUse, UserPromptSubmit 等）
- MCP統合（Serena, Context7）
