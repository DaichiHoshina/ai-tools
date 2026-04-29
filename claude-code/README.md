# Claude Code 設定

Claude Code 用のコマンド・スキル・エージェント・ガイドライン・Hooks を一元管理するディレクトリ。`install.sh` で `~/.claude/` に同期して使用する。

## 構成

| ディレクトリ / ファイル | 内容 | 詳細 |
|------------------------|------|------|
| `commands/` | 37 のスラッシュコマンド（`/dev`, `/review`, `/plan` 等） | [docs/commands-quickref.md](../docs/commands-quickref.md) |
| `skills/` | 21 のスキル（comprehensive-review, ui-skills, terraform 等） | 各 `skills/<name>/skill.md` |
| `agents/` | 7 のエージェント（po-agent, manager-agent, developer-agent 等） | [agents/README.md](agents/README.md) |
| `guidelines/` | 61 ガイドライン（言語 / 設計 / インフラ / 運用 / 品質） | カテゴリ別ディレクトリ |
| `hooks/` | 16 のイベント Hook（UserPromptSubmit, PreToolUse, SessionEnd 等） | [hooks/README.md](hooks/README.md) |
| `templates/` | settings / MCP / keybindings / workflow テンプレート | [templates/README.md](templates/README.md) |
| `output-styles/` | 返信フォーマット定義 | [output-styles/README.md](output-styles/README.md) |
| `references/` | 詳細リファレンス（model-selection、performance-insights、command-resource-map 等） | `references/*.md` |
| `rules/` | 全プロジェクト共通の出力ルール（markdown、ai-output、enterprise-security 等） | |
| `scripts/` | Analytics / dashboard / cleanup の補助スクリプト | |
| `lib/` | shell ユーティリティ（hook 共通関数等） | [lib/README.md](lib/README.md) |
| `tutorials/` | チュートリアル | [tutorials/README.md](tutorials/README.md) |
| `tests/` | hook / lib のテスト | [tests/README.md](tests/README.md) |
| `CLAUDE.md` | claude-code ディレクトリ固有のグローバル指示 | |
| `VERSION` | Claude Code CLI 本体の追従バージョン（現在 2.1.123） | |

## セットアップ

```bash
# 初回
./install.sh

# 別マシンへ複製
git pull && ./install.sh
```

詳細は [QUICKSTART.md](QUICKSTART.md)（5分で動かす）と [SETUP.md](SETUP.md)（フル手順）を参照。

## 同期

```bash
./sync.sh from-local      # ローカルの ~/.claude → リポジトリ（変更を取り込む）
./sync.sh to-local --yes  # リポジトリ → ローカルの ~/.claude（変更を反映）
```

`sync.sh` は `gh skill` 管理スキルとテストファイルを自動除外。詳細は `./sync.sh --help`。

## バージョン管理

- `VERSION` は **Claude Code CLI 本体の追従バージョン**。設定変更ごとに bump しない
- CLI リリース取り込みは [`/claude-update-fix`](commands/claude-update-fix.md) コマンドで実行
- 未採用機能の追跡: [references/CLAUDE-CODE-OPPORTUNITIES.md](references/CLAUDE-CODE-OPPORTUNITIES.md)
- 変更履歴: [CHANGELOG.md](CHANGELOG.md)

## 運用ドキュメント

| トピック | リファレンス |
|---------|-------------|
| モデル選択・effort レベル | [references/model-selection.md](references/model-selection.md) |
| 自然言語トリガー全リスト | [references/natural-language-triggers.md](references/natural-language-triggers.md) |
| レビューコマンド使い分け | [references/review-commands.md](references/review-commands.md) |
| メモリ使い分け（auto-memory / Serena） | [references/memory-usage.md](references/memory-usage.md) |
| セッション管理（rename / resume） | [references/session-management.md](references/session-management.md) |
| Agent コスト実測 | [references/performance-insights.md](references/performance-insights.md) |
| 設計フェーズ遷移 | [references/design-phase-flow.md](references/design-phase-flow.md) |
| 主要コマンド × リソース対応表 | [references/command-resource-map.md](references/command-resource-map.md) |

トップ概要は [../README.md](../README.md) を参照。
