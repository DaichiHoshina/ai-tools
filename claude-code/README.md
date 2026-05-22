# Claude Code 設定

Claude Code 用のコマンド・スキル・エージェント・ガイドライン・Hooks を一元管理するディレクトリ。`install.sh` で `~/.claude/` に同期して使用する。

変更履歴: [CHANGELOG.md](CHANGELOG.md) / 固有指示: [CLAUDE.md](CLAUDE.md) / CLI 追従: [VERSION](VERSION)

## クイックスタート

```bash
# 初回 (~/ai-tools 配下に clone 済前提)
./claude-code/install.sh

# 同期
./claude-code/sync.sh from-local      # ~/.claude → repo (取り込み)
./claude-code/sync.sh to-local --yes  # repo → ~/.claude (反映)
```

詳細セットアップ手順は [#セットアップ詳細](#セットアップ詳細) 参照。

## Core 3 コマンド

迷ったらこの3つだけ。

| コマンド | 用途 | 使い分け |
|---|---|---|
| `/flow` | 万能・自動判定 | 3+file / 不明確 / 多段 |
| `/dev` | 実装直行 | 1-2file / 明確 |
| `/review` | レビュー (内部: `comprehensive-review` skill / Team path 時 `reviewer-agent`) | コード変更後 |

### Tier 2 (常用)

| コマンド | 用途 |
|---|---|
| `/git-push` | commit→push→PR/MR 一括 |
| `/plan` | 設計・計画のみ (PO agent) |
| `/diagnose` | エラー解析・修正提案 |
| `/review-fix-push` | レビュー→修正→push 一括 |

### Tier 3 (専門)

- **開発**: `/test` (`--tdd`) / `/refactor` / `/lint-test`
- **設計フェーズ**: `/brainstorm`→`/prd`→`/design-doc`→`/plan` (順序: `references/design-phase-flow.md`)
- **ドキュメント**: `/docs`
- **調査**: `/analytics` (`--ui`) / `/retrospective`
- **ユーティリティ**: `/reload` / `/memory-save` / `/protection-mode` / `/claude-update-fix` / `/serena-refresh`

全コマンド一覧: `commands/` ディレクトリ。

## 構成

| ディレクトリ / ファイル | 内容 | 詳細 |
|---|---|---|
| `commands/` | 34 のスラッシュコマンド | `commands/*.md` |
| `skills/` | 22 のスキル | `skills/<name>/skill.md` |
| `agents/` | 7 エージェント (po/manager/developer/explore/reviewer/verify-app/root-cause-analyzer) | [agents/README.md](agents/README.md) |
| `guidelines/` | 67 ガイドライン (言語/設計/インフラ/運用/品質) | カテゴリ別 |
| `hooks/` | 18 イベント Hook | [hooks/README.md](hooks/README.md) |
| `templates/` | settings / MCP / keybindings / workflow テンプレ | [templates/README.md](templates/README.md) |
| `output-styles/` | 返信フォーマット定義 | [output-styles/README.md](output-styles/README.md) |
| `references/` | 詳細リファレンス | `references/*.md` |
| `rules/` | 全プロジェクト共通の出力ルール | |
| `scripts/` | analytics / dashboard / cleanup 補助 | |
| `lib/` | shell ユーティリティ | [lib/README.md](lib/README.md) |
| `tutorials/` | チュートリアル | [tutorials/README.md](tutorials/README.md) |
| `tests/` | hook / lib のテスト | [tests/README.md](tests/README.md) |
| `settings/` | MCP server 設定 | |
| `config/` | shell utility 設定 | |
| `githooks/` | repo 用 git hooks | |
| `CLAUDE.md` | claude-code 固有のグローバル指示 | |
| `VERSION` | CLI 追従バージョン (手動更新: `/claude-update-fix`) | |

## スキル (22)

ほとんどのスキルは **自動選択**される。明示指定不要。`UserPromptSubmit Hook` が技術スタック検出、`/review` が問題タイプに応じてスキル選択、`requires-guidelines` で関連ガイドライン自動読込。

### カテゴリ別

| 種別 | スキル |
|---|---|
| レビュー | comprehensive-review / uiux-review / ui-skills |
| 開発 | backend-dev / react-best-practices / api-design / clean-architecture-ddd / grpc-protobuf |
| インフラ | container-ops / terraform / microservices-monorepo |
| ユーティリティ | load-guidelines / cleanup-enforcement / mcp-setup-guide / session-mode / context7 / data-analysis / techdebt / incident-response / root-cause / architecture-diagram |

### 推奨組み合わせ

| シーン | スキル |
|---|---|
| フルレビュー | `comprehensive-review --focus=all` |
| Go バックエンド | `backend-dev --lang=go` + `clean-architecture-ddd` + `api-design` |
| TypeScript バックエンド | `backend-dev --lang=typescript` + `api-design` |
| React/Next.js | `react-best-practices` + `ui-skills` + `uiux-review` |
| コンテナ調査 | `container-ops --mode=troubleshoot` |
| インシデント | `incident-response` + `root-cause` |

### 品質検証

- `scripts/skill-lint.sh` — frontmatter 検証 (`--strict` で push 前 hook 用)
- `scripts/skill-eval.sh` — 発火率計測、死蔵スキル可視化
- `/skill-add <name>` — skill-creator → lint → 同期 一括

## エージェント (7)

| エージェント | 役割 |
|---|---|
| `po-agent` | 戦略決定・Worktree 管理 |
| `manager-agent` | タスク分割・配分計画 |
| `developer-agent` | 実装担当 (dev1-4 並列) |
| `explore-agent` | 探索・分析 (explore1-4) |
| `reviewer-agent` | レビュー担当 |
| `verify-app` | ビルド・テスト検証 |
| `root-cause-analyzer` | 根本原因分析 |

詳細・コスト・コマンド対応: [agents/README.md](agents/README.md)

## 用語集

- **Agent**: `Task` tool で起動する役割実行者
- **MCP** (Model Context Protocol): 外部ツール連携プロトコル (serena / context7 / codex 等)
- **Hook**: 特定イベント自動実行スクリプト (全 18 件、詳細: [hooks/README.md](hooks/README.md))
- **Skill**: 特定技術領域の専門知識セット、`/skill-name` で呼出
- **Command**: `/command` 形式のショートカット
- **Guideline**: 言語/フレームワーク固有のベストプラクティス (on-demand load)
- **Worktree**: Git 機能、複数作業ディレクトリで並列開発
- **additionalContext**: Hook からモデルへ追加情報を提供する JSON 仕組み (v2.1.9+)
- **protection-mode**: 操作の安全性 3 層分類 (安全/要確認/禁止)

## セットアップ詳細

### 前提

Git / Node.js v20+ / Python 3.x / uv

### 初期セットアップ

```bash
cd ~
git clone https://github.com/DaichiHoshina/ai-tools.git
cd ai-tools && ./claude-code/install.sh
```

### MCP サーバー

**Serena (必須)**

```bash
cd ~ && git clone https://github.com/clippy-ai/serena.git
cd serena && uv sync
echo "SERENA_PATH=$HOME/serena" >> ~/.env
```

`install.sh` 実行後、`templates/.mcp.json.template` から `.mcp.json` が自動生成 (`SERENA_PATH` / `PROJECT_ROOT` 展開)。

**Codex (必須)**

```bash
npm install -g @openai/codex
```

**CodeRabbit CLI (推奨、`/review --multi` / `/git-push --auto-review` 使用時)**

```bash
brew install coderabbitai/tap/coderabbit
coderabbit auth login
```

未認証なら自動レビュー skip。

### レビュー強化 Plugin (推奨)

`/review --multi` `/review --deep` `/git-push --pr --auto-review` で使用。

| Plugin | 役割 | 必須度 |
|---|---|---|
| `code-review` | 5並列 Sonnet+Haiku 信頼度80フィルタ→PR comment 自動投稿 | `--multi`/`--auto-review` 必須 |
| `security-guidance` | Edit/Write 時の eval/exec 系セキュリティ警告 hook | 推奨 |
| `pr-review-toolkit` | 6専門 agent (code-reviewer / silent-failure-hunter 等) | `--deep` 必須 |
| `coderabbit` | 40+ 静的解析、PR コメント自動投稿 | `--multi`/`--auto-review` 使用 |

```bash
claude plugin install code-review@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install coderabbit@claude-plugins-official
```

### 動作確認

```bash
ls ~/.claude/commands/ ~/.claude/skills/ ~/.claude/hooks/
jq '.hooks' ~/.claude/settings.json

# Hook テスト
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
```

期待結果: `Tech stack detected: go | Skills: go-backend`

### 設定オプション

Bash タイムアウト延長 (`~/.claude/settings.json`):

```json
{"env": {"BASH_DEFAULT_TIMEOUT_MS": "300000"}}
```

デフォルト2分 → 5分 (最大10分: 600000)

UX 調整環境変数: `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` でフルスクリーン renderer 無効化 (CLI 2.1.132+、長セッションで scrollback 参照可)。

### Serena 効率化

`get_symbols_overview()` から始める / `include_body=false` をデフォルトに / 行範囲指定で一部のみ読む。

### トラブルシューティング

| 問題 | 対処 |
|---|---|
| Serena が動作しない | `cd ~/serena && uv sync` |
| Codex が動作しない | `npm install -g @openai/codex` |
| ハードリンクエラー | `./claude-code/sync.sh` |
| プロジェクト state 破損 / 巨大化 | `claude project purge --dry-run` → `claude project purge -y` (CLI 2.1.126+) |

## バージョン管理

- `VERSION` は **CLI 本体追従バージョン**。設定変更ごとに bump しない
- CLI リリース取り込み: [`/claude-update-fix`](commands/claude-update-fix.md)
- 未採用機能追跡: [references/CLAUDE-CODE-OPPORTUNITIES.md](references/CLAUDE-CODE-OPPORTUNITIES.md)

## 運用ドキュメント

| トピック | リファレンス |
|---|---|
| モデル選択・effort レベル | [references/model-selection.md](references/model-selection.md) |
| 自然言語トリガー全リスト | [references/natural-language-triggers.md](references/natural-language-triggers.md) |
| レビューコマンド使い分け | [references/review-commands.md](references/review-commands.md) |
| メモリ使い分け (auto-memory / Serena) | [references/memory-usage.md](references/memory-usage.md) |
| セッション管理 (rename / resume) | [references/session-management.md](references/session-management.md) |
| Agent コスト実測 | [references/performance-insights.md](references/performance-insights.md) |
| 設計フェーズ遷移 | [references/design-phase-flow.md](references/design-phase-flow.md) |
| 主要コマンド × リソース対応 | [references/command-resource-map.md](references/command-resource-map.md) |

トップ概要は [../README.md](../README.md) 参照。
