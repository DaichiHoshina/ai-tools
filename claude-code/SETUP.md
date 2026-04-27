# Claude Code セットアップガイド

## 前提条件

- Git, Node.js v20+, Python 3.x, uv

## 1. 初期セットアップ

```bash
cd ~
git clone https://github.com/DaichiHoshina/ai-tools.git
cd ai-tools
chmod +x ./claude-code/install.sh
./claude-code/install.sh
```

## 2. MCP サーバーセットアップ

### Serena MCP（必須）

```bash
cd ~
git clone https://github.com/clippy-ai/serena.git
cd serena && uv sync
echo "SERENA_PATH=$HOME/serena" >> ~/.env
```

`install.sh` 実行後、`templates/.mcp.json.template` から `.mcp.json` が自動生成されます（`SERENA_PATH`・`PROJECT_ROOT` を展開）。

### Codex（必須）

```bash
npm install -g @openai/codex
```

### CodeRabbit CLI（推奨、`/review --multi` / `/git-push --auto-review` 使用時）

```bash
brew install coderabbitai/tap/coderabbit
coderabbit auth login
```

未認証なら自動レビューは skip される。詳細・料金: `~/.claude/projects/.../memory/reference_coderabbit_plugin.md`

## 2.5 レビュー強化用 Plugin（推奨）

`/review --multi` `/review --deep` および `/git-push --pr --auto-review` で使用する Anthropic 公式 plugin 群。`claude plugin install` で導入。

| Plugin | 役割 | 必須度 |
|--------|------|--------|
| `code-review` | 5並列Sonnet+Haiku信頼度80フィルタ→PR comment 自動投稿 | `--multi`/`--auto-review` で必須 |
| `security-guidance` | Edit/Write 時の eval/exec 系セキュリティ警告 hook | 推奨（既存自作 hook と相補） |
| `pr-review-toolkit` | code-reviewer / silent-failure-hunter / type-design-analyzer / comment-analyzer / pr-test-analyzer / code-simplifier の6専門agent | `--deep` で必須 |
| `coderabbit` | 40+ 静的解析、PR コメント自動投稿 | `--multi`/`--auto-review` で使用 |

**導入コマンド**:

```bash
claude plugin install code-review@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install coderabbit@claude-plugins-official
```

**動作確認**:

```bash
# 利用可能 skill 一覧から確認
ls ~/.claude/plugins/cache/claude-plugins-official/ | grep -E "code-review|security-guidance|pr-review-toolkit|coderabbit"
# 動作確認は単体プラグイン呼び出しで（コスト最小）
# /code-review:code-review <PR番号>
# 本番運用時のみ /review --multi <PR番号>（4手段並列、コスト最大）
```

### JIRA/Confluence（オプション）

プロジェクト固有の `.mcp.json` に追記:

```json
{
  "mcpServers": {
    "jira": {
      "command": "node",
      "args": ["/path/to/jira-mcp/build/index.js"],
      "env": {
        "JIRA_API_TOKEN": "[TOKEN]",
        "JIRA_BASE_URL": "https://your.atlassian.net",
        "JIRA_USER_EMAIL": "[EMAIL]"
      }
    }
  }
}
```

## 3. 動作確認

```bash
ls ~/.claude/commands/ ~/.claude/skills/ ~/.claude/hooks/
jq '.hooks' ~/.claude/settings.json
```

## 4. Hooks 動作テスト

```bash
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
echo '{"session_id": "test", "total_tokens": 50000, "total_messages": 25, "duration": 1200}' | ~/.claude/hooks/session-end.sh
echo '{"session_id": "test", "current_tokens": 150000, "mcp_servers": {"serena": {}}}' | ~/.claude/hooks/pre-compact.sh
```

期待結果: `Tech stack detected: go | Skills: go-backend`

## 5. 通知音設定（オプション）

```bash
cp /path/to/your/sound.mp3 ~/notification.mp3
afplay ~/notification.mp3  # テスト
```

## 6. Serena オンボーディング

- Serena MCP サーバーは `claude mcp` 登録済みなら起動時に自動接続される（`claude mcp list` で確認）
- オンボーディング自体は手動: `mcp__serena__check_onboarding_performed` で確認、未実施なら `mcp__serena__onboarding` を呼ぶ
- 旧 `/serena オンボーディング` は廃止（`/dev` 等で Serena MCP を既定利用）

## 7. 定期更新

```bash
cd ~/ai-tools
git pull origin main
./claude-code/sync.sh
```

## 8. テスト実行（オプション）

```bash
brew install bats-core
cd ~/ai-tools/claude-code
bats tests/
```

詳細は [tests/README.md](./tests/README.md) 参照。

## Serena 効率化のコツ

| 操作 | 非効率 | 効率的 | 削減率 |
|------|--------|--------|--------|
| ファイル確認 | 全体読み込み | 概要取得 | 93% |
| メソッド確認 | 全メソッド | 特定のみ | 85% |

- `get_symbols_overview()` から始める
- `include_body=false` をデフォルトに
- 行範囲指定で一部のみ読む

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| Serena が動作しない | `cd ~/serena && uv sync` |
| Codex が動作しない | `npm install -g @openai/codex` |
| ハードリンクエラー | `./claude-code/sync.sh` |

## 設定オプション

Bash タイムアウト延長（`~/.claude/settings.json`）:

```json
{"env": {"BASH_DEFAULT_TIMEOUT_MS": "300000"}}
```

デフォルト2分 → 5分（最大10分: 600000）

### デバッグ専用環境変数（通常運用では設定しない）

| 変数 | 用途 | リスク |
|------|------|--------|
| `OTEL_LOG_RAW_API_BODIES` | OpenTelemetry ログに API request/response body 全文を出力 | token・credential・PII 漏洩。本番環境禁止 |

API 呼び出しの詳細デバッグが必要な時のみ一時的に `"1"` を設定。作業後必ず削除。

## チェックリスト

- [ ] install.sh 実行完了
- [ ] Serena MCP インストール
- [ ] Codex インストール
- [ ] CodeRabbit CLI インストール（自動レビュー使用時）
- [ ] レビュー強化 plugin 導入（code-review / security-guidance / pr-review-toolkit / coderabbit）
- [ ] Hooks 動作確認（主要Hook）
- [ ] 通知音設定（オプション）
- [ ] Serena オンボーディング成功（`mcp__serena__check_onboarding_performed` で確認）
