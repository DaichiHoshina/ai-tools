# ai-tools プロジェクト構造の包括的分析

**作成日**: 2026-02-08
**使用モデル**: Claude Opus 4.6
**分析対象**: /Users/daichi/ai-tools
**評価スコア**: 94/100

---

## 1. プロジェクト概要

`/Users/daichi/ai-tools` は、Claude Code (Anthropic) および Codex (OpenAI) の設定・スキル・ガイドライン・フックを一元管理し、複数PC間で環境を再現可能にするリポジトリ。AI支援開発ワークフローの最適化を主目的とする。

---

## 2. トップレベル構造

```
ai-tools/
├── claude-code/          # メインコンポーネント（Claude Code設定）
│   ├── agents/           # 8種類のエージェント定義
│   ├── commands/         # 20コマンド定義
│   ├── guidelines/       # 28+ガイドライン
│   ├── hooks/            # 12イベントフック
│   ├── lib/              # 9共有ライブラリ
│   ├── skills/           # 26スキル定義
│   └── tests/            # BATS単体テスト + 統合テスト
├── codex/                # Codex (OpenAI) 対応
├── docs/                 # ドキュメント・レポート
│   └── reports/          # 分析レポート（Phase 1で整理）
├── scripts/              # CI/テスト自動化
└── .github/workflows/    # CI/CD (5ジョブ並列実行)
```

---

## 3. コアコンポーネント詳細

### 3.1 エージェント体系（8種類）

```
po-agent (戦略決定)
  └── manager-agent (タスク分割)
       ├── developer-agent (実装1-4, 並列可)
       ├── explore-agent (読み取り専用探索)
       └── reviewer-agent (最終レビュー)
           └── code-simplifier (複雑度削減)
               └── verify-app (ビルド・テスト・lint)
```

**複雑度判定と実行パス**:
- Simple (ファイル<5, 行<300): 直接実行
- TaskDecomposition (ファイル≥5 OR 独立機能≥3): TaskCreate/TaskUpdate管理
- AgentHierarchy (複数プロジェクト横断): PO/Manager/Developer階層

### 3.2 コマンド体系（20コマンド）

**Tier 1 (Core 3)**:
- `/flow`: 万能ワークフロー自動判定（14種類ツール使用可）
- `/dev`: 実装専用（12種類ツール、--quickでhaikuモード）
- `/review`: 包括的コードレビュー

**Tier 2 (よく使う)**:
- `/commit`, `/commit-push-pr`, `/plan`, `/debug`

**Tier 3 (専門)**:
- `/test`, `/refactor`, `/quick-fix`, `/tdd`, `/explore`, `/retrospective`, etc.

### 3.3 スキル体系（26スキル → 14に統合予定）

**レビュー系 (5)**: code-quality-review, security-error-review, docs-test-review, uiux-review, comprehensive-review
**開発系 (6)**: go-backend, typescript-backend, react-best-practices, api-design, clean-architecture-ddd, grpc-protobuf
**インフラ系 (5)**: dockerfile-best-practices, kubernetes, terraform, microservices-monorepo, docker-troubleshoot
**ユーティリティ (6+)**: load-guidelines, ai-tools-sync, cleanup-enforcement, etc.

### 3.4 ガイドライン体系（28+ファイル、5カテゴリ）

| カテゴリ | ファイル数 | 説明 |
|---------|-----------|------|
| common/ | 15 | 全言語共通原則 |
| languages/ | 8 | Go, TS, React, Python, Rust等 |
| design/ | 2 | Clean Architecture, DDD |
| infrastructure/ | 5 | AWS (ECS, EKS, Lambda, EC2, Terraform) |
| summaries/ | 8 | トークン節約版（~2,500トークン） |

### 3.5 フック（自動化基盤、12種類）

| フック | タイミング | 責務 |
|--------|-----------|------|
| session-start.sh | セッション開始 | protection-mode適用、Serena memory提案 |
| user-prompt-submit.sh | プロンプト送信時 | 技術スタック検出、スキル推奨（最重要） |
| pre-tool-use.sh | ツール実行前 | protection-mode 3層分類（Safe/Boundary/Forbidden） |
| pre-skill-use.sh | スキル実行前 | ガイドライン自動読み込み |
| pre-compact.sh | コンパクション前 | Serena memory自動保存指示 |
| session-end.sh | セッション終了 | 統計ログ保存、通知音、Git変更検出 |

**特筆すべき設計**:
- user-prompt-submit.sh: bash4+連想配列で4層検出（ファイルパターン・キーワード・エラーログ・Git状態）
- pre-tool-use.sh: Guard関手による圏論的操作分類
- pre-compact.sh: Serena memoryへのリストアポイント強制保存

### 3.6 共有ライブラリ（9ファイル）

| ファイル | 責務 | 依存 |
|---------|------|------|
| security-functions.sh | OWASP対策、入力検証 | なし |
| colors.sh | ANSIカラーコード | なし |
| print-functions.sh | 出力ヘルパー | colors.sh |
| i18n.sh | 国際化（日英） | bash 4.2+ |
| hook-utils.sh | フック共通処理 | jq |
| detect-from-files.sh | ファイルパス検出 | git |
| detect-from-keywords.sh | キーワード検出+キャッシュ | jq, md5sum |
| detect-from-errors.sh | エラーログ検出 | なし |
| detect-from-git.sh | Git状態検出 | git |

---

## 4. 技術スタック

| 技術 | 用途 | ファイル数 |
|------|------|----------|
| Bash | フック、インストーラー、同期、テスト | ~30 |
| JavaScript (Node.js) | ステータスライン | 1 |
| Markdown | コマンド、スキル、ガイドライン、エージェント | ~120 |
| YAML | CI/CD、frontmatter | ~3 |
| JSON | 設定、MCP | ~5 |
| Python | skill-creator/installer内スクリプト | ~5 |

**フレームワーク・ツール**:
- Claude Code (メインのAI CLI)
- Serena MCP (シンボリックコード分析 + プロジェクトメモリ)
- Context7 (ライブラリドキュメント取得)
- BATS (Bashテストフレームワーク)
- ShellCheck (静的解析)
- GitHub Actions (CI/CD、5ジョブ並列)

---

## 5. CI/CD構成

### .github/workflows/ci.yml（5ジョブ並列）

1. **shellcheck**: 全.shファイルの静的解析
2. **markdownlint**: 全.mdファイルのリンティング
3. **bats-test**: BATS単体テスト
4. **install-test**: install.shの動作確認
5. **sync-test**: sync.shの動作確認

---

## 6. 同期メカニズム

### install.sh（初回セットアップ）

```
ai-tools/claude-code/ ===[cp]===> ~/.claude/
```

1. ディレクトリ構造作成
2. ファイルコピー（CLAUDE.md, guidelines/, commands/, agents/, skills/, scripts/, lib/, statusline.js）
3. settings.json テンプレートからの生成（環境変数置換）
4. MCP サーバーインストール（オプション）

### sync.sh（双方向同期）

```
sync.sh to-local    : ai-tools/ → ~/.claude/
sync.sh from-local  : ~/.claude/ → ai-tools/
sync.sh diff        : 差分表示のみ
```

**セキュリティ対策**:
- `$HOME` パスを `__HOME__` に変換
- `.env` のトークン・キーをプレースホルダーに変換（ホワイトリスト方式）

---

## 7. 現状の強み（7点）

1. **包括的な自動化基盤**: 12種類のイベントフックで一貫した自動化
2. **トークン効率の最適化**: guidelines/summaries/ による2段階読み込み、Safe射のメッセージ省略
3. **セキュリティ意識の高さ**: OWASP対策、トークンマスキング、3層分類（Safe/Boundary/Forbidden）
4. **拡張性の高い設計**: スキル・ガイドライン・フックの疎結合
5. **マルチツール対応**: Claude Code + Codex（リソース共有）
6. **CI/CD統合**: ShellCheck, markdownlint, BATS, install/syncテスト
7. **コンテキスト保護**: Serena memoryへの自動バックアップ

---

## 8. 潜在的な課題（10点）

1. **skill.md / SKILL.md の不統一** → Phase 1で解決 ✅
2. **shebang 環境依存** → Phase 1で解決 ✅
3. **ドキュメント肥大化** → Phase 1で解決 ✅
4. **detect関数の重複** → Phase 2で対応予定
5. **スキル数の増加傾向（25 → 14に統合計画）** → Phase 2で対応予定
6. **Codex対応の不完全さ** → Phase 3で対応予定
7. **settings.json テンプレートのハードコード** → Phase 2で対応予定
8. **テストカバレッジの偏り** → Phase 2で対応予定
9. **guidelines-archive 管理** → Phase 3で対応予定
10. **共有ライブラリの依存チェーン** → Phase 2で対応予定

---

## 9. 命名規則・パターン

| パターン | 例 | 用途 |
|---------|---|------|
| kebab-case.md | code-quality-review | スキル名、ガイドライン名 |
| kebab-case.sh | session-start.sh | フックスクリプト |
| UPPER-CASE.md | CLAUDE.md, SKILLS-MAP.md | プロジェクトレベルドキュメント |
| skill.md / SKILL.md | 各スキルディレクトリ内 | スキル定義（統一予定） |

---

## 10. 総括

ai-tools は、Claude Code を中心としたAI支援開発環境の構成管理を体系的に実現したプロジェクトである。12種類のイベントフック、26スキル、28ガイドライン、20コマンド、8エージェントという豊富なコンポーネントを持ち、技術スタック自動検出 → スキル推奨 → ガイドライン適用 → エージェント階層実行 → 検証 → PR作成 という一貫したパイプラインを構築している。

設計思想として「Guard関手」(圏論的概念の操作分類)、「Progressive Disclosure」(トークン段階的読み込み)、「Boris流」(最小指示で最大成果) が一貫しており、単なる設定ファイル集を超えたAI開発ワークフローのフレームワークとなっている。

**評価スコア**: 94/100
**改善の方向性**: Phase 1 (完了) → Phase 2 (実装中) → Phase 3 (長期) により100点到達を目指す

---

**関連レポート**:
- PHASE1-3-IMPROVEMENT-PROPOSAL.md（改善提案書）
- PHASE2-3-IMPLEMENTATION-PLAN.md（詳細実装計画）
