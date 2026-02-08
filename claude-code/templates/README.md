# Templates - テンプレートファイル一覧

Claude Code設定に使用されるテンプレートファイルの説明。

## 自動使用されるテンプレート（install.sh/sync.shで処理）

| ファイル | 用途 | 自動処理 |
|---------|------|---------|
| **settings.json.template** | ~/.claude/settings.json のテンプレート | install.sh で自動生成 |
| **.mcp.json.template** | プロジェクト固有のMCP設定 | install.sh で envsubst により自動生成 |
| **gitlab-mcp.sh.template** | GitLab MCP統合スクリプト | install.sh で自動生成 |
| **.env.example** | 環境変数テンプレート | install.sh で ~/.env にコピー |

### MCP設定のモジュール化

`settings/mcp-servers/` ディレクトリに MCP サーバー設定がモジュール化されています:

- **serena.json.template**: Serena MCP設定（envsubst形式）

将来的に他の MCP サーバーを追加する場合は、このディレクトリに `*.json.template` を追加してください。

## 手動使用テンプレート（必要に応じてコピー）

### keybindings.json.template

Claude Codeのキーボードショートカット設定テンプレート。

**使い方**:
```bash
cp ~/.claude/templates/keybindings.json.template ~/.claude/keybindings.json
# 必要に応じて編集
```

**定義済みショートカット**:
- `Ctrl+Shift+F`: `/flow`
- `Ctrl+Shift+C`: `/commit-push-pr`
- `Ctrl+Shift+R`: `/review`
- `Ctrl+Shift+T`: `/test`

### settings-ghq.json.template

ghq（Goリポジトリ管理ツール）を使用する環境向けのsettings.json。

**使い方**:
```bash
# ghq環境の場合、こちらを使用
cp ~/.claude/templates/settings-ghq.json.template ~/.claude/settings.json
```

**通常のsettings.json.templateとの違い**:
- リポジトリパスがghq構造に最適化

### workflow-config.yaml.template

カスタムワークフロー設定テンプレート（実験的機能）。

**使い方**:
```bash
cp ~/.claude/templates/workflow-config.yaml.template ~/.claude/workflow-config.yaml
# プロジェクト固有のワークフローを定義
```

**用途**:
- プロジェクト固有のビルド・テスト・デプロイ手順
- カスタムコマンドチェーン

## Serena MCPメモリーテンプレート

### serena-memories/

Serena MCPで使用するメモリーテンプレート（プロジェクト知識の初期構造）。

| ファイル | 用途 |
|---------|------|
| **common-tasks.template.md** | よく使うタスクの記録テンプレート |
| **development-guidelines.template.md** | プロジェクト固有の開発ガイドライン |
| **project-overview.template.md** | プロジェクト概要・アーキテクチャ |
| **troubleshooting.template.md** | トラブルシューティング・FAQ |

**使い方**:
```bash
# 新規プロジェクトでSerenaメモリーを初期化する場合
cp ~/.claude/templates/serena-memories/*.template.md ~/.serena/memories/
# .template.md サフィックスを削除して使用
```

**メモリー管理**:
- `/serena` コマンドでメモリー操作
- `mcp__serena__write_memory` でプログラム的に更新

---

## テンプレート追加ガイドライン

新しいテンプレートを追加する場合：

1. **命名規則**: `<name>.template` または `<name>.template.<ext>`
2. **説明追加**: このREADME.mdに用途と使い方を記載
3. **自動処理**: install.sh/sync.shで自動処理する場合は、スクリプトを更新

---

## 参照

- [install.sh](../install.sh): 自動セットアップスクリプト
- [sync.sh](../sync.sh): 双方向同期スクリプト
- [Serena MCP](https://github.com/serena-mcp/serena): Serena MCPドキュメント
