# Changelog

このリポジトリの主要な変更履歴。[Conventional Commits](https://www.conventionalcommits.org/) に準拠。

## [2.1.39] - 2026-02-23

### Fixed

- CI: shellcheckのmacOSインストール分岐を追加
- README/SKILLS-MAP: 数値を実態に合わせて更新
- stop.sh: macOS専用→クロスプラットフォーム対応
- sync.sh: `sync_from_local()` のDRY化、`.env` sourceのセキュリティ修正

### Changed

- CLAUDE.md: ログ設計基準・RCA原則をガイドラインに外部化（150→96行、36%削減）
- Git pushコマンド3つ（commit-push-main/pr, branch-push-mr）を `/git-push` に統合
- po-agent: model を opus → sonnet に変更（コスト最適化）
- spec-agent: 未使用のためアーカイブに移動

### Added

- `guidelines/common/logging-standards.md` - ログ設計ガイドライン
- `commands/git-push.md` - 統合Gitコマンド
- `CHANGELOG.md` - 変更履歴
- hooks連携の統合テスト追加

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
