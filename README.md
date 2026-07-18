# AI Tools

**Claude Codeの設定を一元管理し、複数マシンで同じ開発体験を再現するためのツールキット。**

コマンド、スキル、ガイドライン、Hooksを組み合わせて、AI支援開発のワークフローを構築・共有できます。

---

## できること

```
/prd ユーザー認証機能を追加したい   → 対話式で要件整理、10視点レビュー、PRD生成
/dev 上記PRDで実装                  → 技術スタック自動検出、ガイドライン適用、実装
/review                             → 変更内容を分析し、適切な観点で統合レビュー
/diagnose この認証エラーを修正      → ログ解析、原因特定、修正提案
/git-push                           → コミット→push→PR/MR作成を1コマンドで
```

他にも `/test`, `/refactor`, `/docs`, `/flow` などのコマンドを収録。

---

## クイックスタート

```bash
git clone https://github.com/DaichiHoshina/ai-tools.git ~/ghq/github.com/DaichiHoshina/ai-tools
ln -s ~/ghq/github.com/DaichiHoshina/ai-tools ~/ai-tools
cd ~/ai-tools && ./claude-code/install.sh
claude
```

clone 先は owner 階層 `~/ghq/github.com/DaichiHoshina/CLAUDE.md` の `@ai-tools/CLAUDE.repo.md` import が前提とする path で、`~/ai-tools` は symlink として運用する。

MCP連携（Serena等）を使う場合:

```bash
cp .mcp.json.example .mcp.json
# パスを自分の環境に合わせて編集
```

---

## 構成

```
ai-tools/
├── claude-code/
│   ├── commands/        # スラッシュコマンド（/dev, /review, /plan ...）
│   ├── skills/          # スキル（レビュー、開発、インフラ、ユーティリティ）
│   ├── agents/          # エージェント（PO, Manager, Developer ...）
│   ├── guidelines/      # ガイドライン（言語・設計・インフラ・運用）
│   ├── hooks/           # イベントHook
│   ├── output-styles/   # 返信フォーマット定義
│   ├── scripts/         # ユーティリティスクリプト
│   ├── templates/       # テンプレート
│   ├── install.sh       # インストール
│   └── sync.sh          # 設定同期
├── codex/               # Codex CLI 連携設定（plugin manifest 等）
├── cursor/              # Cursor IDE 設定同期（rules / User 設定）
├── dashboard/           # 利用状況ダッシュボード（analytics 可視化）
├── docs/                # repo 全体ドキュメント（ADR、レポート等）
└── AGENTS.md            # リポジトリのビルド・開発ガイドライン
```

---

## 仕組み

### Hooks による自動化

Hooksがプロンプトやツール呼び出しに応じて、適切な設定を自動適用します。

| Hook | タイミング | 動作 |
|------|-----------|------|
| UserPromptSubmit | プロンプト送信時 | 技術スタック検出、スキル推奨 |
| PreToolUse | ツール実行前 | 危険操作の検出・ブロック |
| PreCompact | コンパクション前 | コンテキストの自動バックアップ |
| SessionEnd | セッション終了時 | 統計ログ、完了通知 |

```
プロンプト: "Go APIのバグを修正してください"
↓ UserPromptSubmit Hook
🔍 Tech stack detected: go | Skills: go-backend

プロンプト: "SLOのburn rateアラート対応"
↓ UserPromptSubmit Hook
🔍 Skills: incident-response
```

### Claude Code 2.1.123 取り込み

直近の CLI アップデート連動機能（`/claude-update-fix` で追従、未採用機能は [`claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md`](./claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md) で追跡）:

- **statusline**: `effort=high`/`low` バッジと thinking 💭 の視覚化
- **`/resume`**: 検索ボックスに PR URL 貼付で該当セッション復元（GitHub/GHE/GitLab/Bitbucket）
- **`claude ultrareview <PR>`**: 非対話 subcommand を CI 連携用に [`commands/review.md`](./claude-code/commands/review.md) に追記（`--json` 出力でゲート化）
- **`comprehensive-review` skill**: `${CLAUDE_EFFORT}` 連動で信頼度閾値が変動（low: 90+ / medium: 80+ / high: 70+）
- **serena MCP**: tool-search deferred (default)。schema 約 10KB を先頭 load しない (2026-07-16 に `alwaysLoad: true` から転換、token 固定費 > 初回 1 hop のレイテンシ)

### スキルとガイドライン

技術スタックに応じたガイドラインが自動で適用されます。

- **言語**: Go / TypeScript / Python / Rust / React
- **設計**: クリーンアーキテクチャ、DDD、マイクロサービス、非同期ジョブ設計
- **インフラ**: Docker / Kubernetes / Terraform / AWS
- **運用**: 監視・SLO/Burn Rate対応、リリース管理、Runbookテンプレート
- **品質**: Flakyテスト防止、ドキュメント分類・AI対応ライティング

---

## 使い方の例

### バグ修正

```bash
/diagnose この認証エラーを修正
```

技術スタック検出 → 言語ガイドライン適用 → エラー分析 → 原因特定 → 修正提案 → テスト作成まで一貫して実行。

### 新機能開発

```bash
/prd ユーザー認証機能を追加したい
# → 対話式で要件整理、PRD生成
/dev 上記PRDで実装
# → アーキテクチャ・セキュリティ・言語ガイドラインを自動適用
```

### コードレビュー

```bash
/review                  # 12観点 + 信頼度80フィルタ（日常）
/review --deep           # pr-review-toolkit 6 専門agent並列（観点深掘り）
/review --multi <PR>     # comprehensive + codex + plugin + coderabbit 4手段並列
/review --plugin <PR>    # 公式 code-review plugin 委譲（PR comment 自動投稿）
```

変更ファイルを分析し、12観点（architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design / db-concurrency）を自動判定してレビュー。各 finding に信頼度0-100を付与、80未満は Warning 降格。

レビュー履歴は `<repo>/.claude/review-history.jsonl` に jsonl で蓄積、同一箇所3回以上の指摘を 🔁 として検出。`/analytics` で観点別件数・信頼度分布・時系列推移が見える。

`/review-fix-push` で「レビュー → 修正 → 再レビュー → push」が1コマンド（修正で新たな問題を作らない regression loop 付き）。

`/git-push --pr --auto-review` で PR 作成と同時に code-review plugin と coderabbit を並列起動（opt-in）。

ファイル編集時は機密リテラル（AWS Key / GitHub PAT / sk- / Slack token / Private key block）を hook が自動ブロック、SSRF クラウドメタデータ・SQL文字列連結も警告。

### インフラ構築

```bash
/dev Terraform で ECS 環境構築
```

Terraform・ECS・Dockerfileのガイドラインが自動適用され、一式を生成。

### 障害対応

```bash
/diagnose SLOのburn rateアラートが発火した
```

監視Runbook・インシデント対応ガイドラインが自動適用。アラート種別→原因切り分け→対処→エスカレーション判断まで一貫対応。

---

## 同期

```bash
# 別のPCに最新設定を反映
cd ~/ai-tools && git pull && ./claude-code/install.sh

# ローカルの変更をリポジトリに反映
cd ~/ai-tools/claude-code && ./sync.sh from-local
```

---

## Codex対応

OpenAI Codexにも対応しています。詳細は [CODEX-SETUP.md](./CODEX-SETUP.md) を参照。

---

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [claude-code/README.md](./claude-code/README.md) | claude-code 配下の構成・コマンド・スキル一覧 |
| [claude-code/hooks/README.md](./claude-code/hooks/README.md) | Hooks詳細 |
| [claude-code/output-styles/README.md](./claude-code/output-styles/README.md) | Output Styles詳細 |
| [docs/commands-quickref.md](./docs/commands-quickref.md) | コマンドクイックリファレンス |
| [docs/editorless-dev-setup.md](./docs/editorless-dev-setup.md) | エディタレス開発環境のセットアップ |

### 継続課題

Claude Code CLI の未採用機能・取り込み待ち事項をまとめています。

[claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md](./claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md)

---

## Attribution

- **[Claude Code Superpowers](https://github.com/anthropics/claude-code-superpowers)** - Apache License 2.0
  - `claude-code/skills/.system/skill-installer/`
  - `claude-code/skills/.system/skill-creator/`
  - （上記 `.system/` 配下は実行環境で取得されるもので、gitignore 済みのため本リポジトリには含まれない）

## ライセンス

非商用ライセンスで公開しています。個人利用・研究・教育目的で自由に利用・改変・配布できます。商用利用は禁止です。

詳細: [LICENSE](./LICENSE)

サードパーティコンポーネントは各自のライセンスに従います。

> 本リポジトリは研究・実験目的で提供されています。本番環境での利用は自己責任でお願いします。
