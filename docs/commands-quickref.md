# コマンドクイックリファレンス

Claude Code で使用できる全スラッシュコマンドの一覧。

| コマンド | 説明 | 主要用途 |
|---------|------|---------|
| /aliases | コマンドエイリアス定義 | エイリアス管理 |
| /analytics | Claude Code利用状況を分析してインサイトを提示 | 分析・レポート |
| /brainstorm | 対話的設計精緻化（Superpowers統合） | 設計・ブレスト |
| /claude-update-fix | Claude Codeアップデート対応 - 差分検出・自動適用・未採用機能トラッキング | 設定・アップデート |
| /dashboard | Claude Code利用状況ダッシュボードを起動 | 分析・可視化 |
| /design-doc | チーム共有用の設計資料作成 - PRD→設計に落とす、md形式でローカル保存 | 設計・ドキュメント |
| /dev | 直接実装コマンド - Agent不使用で直接実行。--quickオプションでhaiku高速実行。Agent Teamが必要なら /flow を使用。 | 実装 |
| /diagnose | デバッグ支援 - エラーログ解析から原因特定・修正提案まで | デバッグ・分析 |
| /docs | ナレッジ蓄積 - コード分析→Notionページ作成/更新 | ドキュメント |
| /explore | 並列探索コマンド - 複数の観点から同時調査 | 分析・探索 |
| /flow-auto | 完全自律ワークフロー - /flow --auto のショートカット。質問なし・承認スキップ・自動push。 | ワークフロー・自動化 |
| /flow | ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行 | ワークフロー |
| /git-pull | Git pull --rebase の安全実行。未コミット変更を自動stash→pull→pop。 | Git操作 |
| /git-push | Git統合コマンド - commit → push → PR/MR作成を1コマンドで。モード自動判定。 | Git操作 |
| /groove | 軽量マルチエージェントオーケストレーター。YAMLワークフロー定義に従い、複数のAgentを協調実行する。外部依存なし。 | ワークフロー・オーケストレーション |
| /lint-test | CI相当のチェックをローカルで一括実行（build, lint, test, typecheck等） | テスト・検証 |
| /memory-save | Serena memoryへの簡易保存 - 現在の作業状態を即座にメモリに記録 | メモリ |
| /performance-issue | パフォーマンス改善issueの進行管理（計測→pprof分析→段階的改善→負荷試験） | パフォーマンス・最適化 |
| /plan | 設計・計画用コマンド - PO Agent で戦略策定（読み取り専用） | 計画・設計 |
| /prd | PRD作成 - 対話式で要件整理、数学的定式化（オプション）、10の専門家視点で厳格レビュー | 要件定義・PRD |
| /protection-mode | Protection Mode（操作保護モード）を読み込み - 操作チェッカー・安全性分類をセッションに適用 | 設定・安全性 |
| /refactor | リファクタリング用コマンド（言語ガイドライン自動読み込み） | リファクタリング |
| /reload | CLAUDE.mdを再読み込みしてcompaction後のコンテキストを復元 | 設定・コンテキスト |
| /retrospective | 振り返り - 過去のセッションを分析し、スキル・設定の改善案を提案 | 振り返り・改善 |
| /review-fix-push | レビュー→修正→プッシュを1コマンドで実行。/review + /dev 全修正 + /git-push --pr の統合。 | レビュー・自動化 |
| /review | コードレビュー用コマンド（comprehensive-reviewスキルで7観点統合レビュー） | レビュー |
| /serena-refresh | Serenaデータとメモリーを最新化・整理 | メモリ・整理 |
| /serena | Token-efficient Serena MCP command for structured app development and problem-solving | 開発支援 |
| /skills-manage | gh skill ベースのコミュニティスキル管理。検索・インストール・更新（tree SHA/pin/source tracking 付き）。 | スキル管理 |
| /test-local | ローカル動作確認→スクショ撮影→PRコメント投稿 | テスト・検証 |
| /test | テスト作成専用モード - 既存コードに対するテストを作成 | テスト |
| /ui | UI統合コマンド - テーマ・実装・レビュー・パフォーマンス・検証・監査を1コマンドで | UI・統合 |
| /update-guidelines | ガイドライン陳腐化チェック&自動修正 - バージョン/廃止機能/冗長性/AI可読性を3軸検査 | ガイドライン・保守 |
