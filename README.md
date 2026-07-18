# AI Tools

Claude Code の設定 (コマンド / スキル / ガイドライン / Hooks) を一元管理し、複数マシンで同じ開発体験を再現するためのツールキット。

## できること

```
/prd ユーザー認証機能を追加したい   → 対話式で要件整理、10視点レビュー、PRD生成
/dev 上記PRDで実装                  → 技術スタック自動検出、ガイドライン適用、実装
/review                             → 12観点の統合レビュー（信頼度80未満は Warning 降格）
/diagnose この認証エラーを修正      → ログ解析、原因特定、修正提案
/git-push                           → コミット→push→PR/MR作成を1コマンドで
```

他にも `/test`、`/refactor`、`/docs`、`/flow` などのコマンドを収録している。一覧は [docs/commands-quickref.md](./docs/commands-quickref.md) を参照する。

## クイックスタート

```bash
git clone https://github.com/DaichiHoshina/ai-tools.git ~/ghq/github.com/DaichiHoshina/ai-tools
ln -s ~/ghq/github.com/DaichiHoshina/ai-tools ~/ai-tools
cd ~/ai-tools && ./claude-code/install.sh
claude
```

clone 先は owner 階層 `~/ghq/github.com/DaichiHoshina/CLAUDE.md` の `@ai-tools/CLAUDE.repo.md` import が前提とする path で、`~/ai-tools` は symlink として運用する。

MCP 連携（Serena 等）を使う場合は example をコピーして、path を自分の環境に合わせて編集する。

```bash
cp .mcp.json.example .mcp.json
```

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

## 仕組み

### Hooks による自動化

Hooks がプロンプトやツール呼び出しに応じて、適切な設定を自動適用する。

| Hook | タイミング | 動作 |
|------|-----------|------|
| UserPromptSubmit | プロンプト送信時 | 技術スタック検出、スキル推奨 |
| PreToolUse | ツール実行前 | 危険操作・機密リテラルの検出・ブロック |
| PreCompact | コンパクション前 | コンテキストの自動バックアップ |
| SessionEnd | セッション終了時 | 統計ログ、完了通知 |

例えば「Go API のバグを修正して」と送ると、UserPromptSubmit Hook が Go スタックを検出して `go-backend` スキルを推奨する。ファイル編集時は機密リテラル（AWS Key / GitHub PAT / Slack token 等）を PreToolUse Hook が自動ブロックする。

### スキルとガイドライン

技術スタックに応じたガイドラインを自動で適用する。

- **言語**: Go / TypeScript / Python / Rust / React
- **設計**: クリーンアーキテクチャ、DDD、マイクロサービス、非同期ジョブ設計
- **インフラ**: Docker / Kubernetes / Terraform / AWS
- **運用**: 監視・SLO/Burn Rate 対応、リリース管理、Runbook テンプレート
- **品質**: Flaky テスト防止、ドキュメント分類・AI 対応ライティング

### レビューの拡張

- `/review --deep` は 6 専門 agent 並列で観点を深掘りし、`/review --multi <PR>` は外部レビュアー 4 手段を並列実行する
- レビュー履歴は `<repo>/.claude/review-history.jsonl` に蓄積し、同一箇所 3 回以上の指摘を検出する。`/analytics` で観点別件数・信頼度分布が見える
- `/review-fix-push` で「レビュー → 修正 → 再レビュー → push」を 1 コマンドで実行できる

## 同期

```bash
# 別のPCに最新設定を反映
cd ~/ai-tools && git pull && ./claude-code/install.sh

# ローカルの変更をリポジトリに反映
cd ~/ai-tools/claude-code && ./sync.sh from-local
```

## Codex 対応

OpenAI Codex にも対応している。詳細は [CODEX-SETUP.md](./CODEX-SETUP.md) を参照する。

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [claude-code/README.md](./claude-code/README.md) | claude-code 配下の構成・コマンド・スキル一覧 |
| [claude-code/hooks/README.md](./claude-code/hooks/README.md) | Hooks 詳細 |
| [claude-code/output-styles/README.md](./claude-code/output-styles/README.md) | Output Styles 詳細 |
| [docs/commands-quickref.md](./docs/commands-quickref.md) | コマンドクイックリファレンス |
| [docs/editorless-dev-setup.md](./docs/editorless-dev-setup.md) | エディタレス開発環境のセットアップ |
| [claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md](./claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md) | Claude Code CLI の未採用機能・取り込み待ち事項 |

## Attribution

- **[Claude Code Superpowers](https://github.com/anthropics/claude-code-superpowers)** - Apache License 2.0
  - `claude-code/skills/.system/skill-installer/`
  - `claude-code/skills/.system/skill-creator/`
  - 上記 `.system/` 配下は実行環境で取得するもので、gitignore 済みのため本リポジトリには含まれない

## ライセンス

非商用ライセンスで公開している。個人利用・研究・教育目的で自由に利用・改変・配布できる。商用利用は禁止する。

詳細: [LICENSE](./LICENSE)

サードパーティコンポーネントは各自のライセンスに従う。

> 本リポジトリは研究・実験目的で提供している。本番環境での利用は自己責任でお願いしたい。
