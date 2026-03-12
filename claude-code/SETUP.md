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

# ~/.env に SERENA_PATH を設定
echo "SERENA_PATH=$HOME/serena" >> ~/.env
```

### 自動生成された .mcp.json

`install.sh` を実行すると、`templates/.mcp.json.template` から `.mcp.json` が自動生成されます。環境変数 `SERENA_PATH` と `PROJECT_ROOT` が展開されます。

**生成例**:
```json
{
  "mcpServers": {
    "serena": {
      "type": "stdio",
      "command": "uv",
      "args": ["run", "--directory", "/Users/you/serena", "serena-mcp-server", "--project", "/Users/you/ai-tools"]
    }
  }
}
```

### モジュール式 MCP 設定

MCP 設定は `settings/mcp-servers/*.json.template` でモジュール化されています。将来的に他のMCPサーバーを追加する場合は、このディレクトリにテンプレートを追加してください。

### Codex（必須）

```bash
npm install -g @openai/codex
```

### JIRA/Confluence（オプション）

プロジェクト固有の `.mcp.json` で設定:

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
# ファイル配置確認
ls ~/.claude/commands/
ls ~/.claude/skills/
ls ~/.claude/guidelines/
ls ~/.claude/hooks/
ls ~/.claude/output-styles/  # スタイル切り替えは /config で

# MCP確認
cat ~/.claude.json | grep -A 5 "mcpServers"

# Hooks確認
jq '.hooks' ~/.claude/settings.json
```

**期待される出力**:
```json
{
  "SessionStart": { "command": "~/.claude/hooks/session-start.sh" },
  "UserPromptSubmit": { "command": "~/.claude/hooks/user-prompt-submit.sh" },
  "PreToolUse": { "command": "~/.claude/hooks/pre-tool-use.sh" },
  "PreCompact": { "command": "~/.claude/hooks/pre-compact.sh" },
  "Stop": { "command": "~/.claude/hooks/stop.sh" },
  "SessionEnd": { "command": "~/.claude/hooks/session-end.sh" }
}
```

## 4. Hooks 動作テスト（推奨）

新しいHooksが正しく動作することを確認:

```bash
# UserPromptSubmit テスト（最重要）
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh

# SessionEnd テスト
echo '{"session_id": "test", "workspace": {"current_dir": "$(pwd)"}, "total_tokens": 50000, "total_messages": 25, "duration": 1200}' | ~/.claude/hooks/session-end.sh

# PreCompact テスト
echo '{"session_id": "test", "workspace": {"current_dir": "$(pwd)"}, "current_tokens": 150000, "mcp_servers": {"serena": {}}}' | ~/.claude/hooks/pre-compact.sh
```

**期待される結果**:
- UserPromptSubmit: `🔍 Tech stack detected: go | Skills: go-backend`
- SessionEnd: `🔔 Notification sound played | Session logged...`
- PreCompact: `📦 Pre-compact backup saved...`

## 5. 通知音設定（オプション）

タスク完了時に音で通知:

```bash
# 任意のmp3ファイルを配置
cp /path/to/your/sound.mp3 ~/notification.mp3

# テスト
afplay ~/notification.mp3
```

**推奨サウンド**:
- macOS システムサウンド: `/System/Library/Sounds/`
- 短い音（1-2秒）を推奨

## 5. Serena オンボーディング

Claude Code で実行:

```
/serena オンボーディング
```

これにより:
- `.serena/` ディレクトリ作成
- プロジェクト構造の分析
- 初期メモリー作成

## 6. 定期更新

```bash
cd ~/ai-tools
git pull origin main
./claude-code/sync.sh
```

## 7. テスト実行（オプション）

Phase 2-3で追加された単体テスト（BATS）を実行:

```bash
# BATSインストール（未インストールの場合）
brew install bats-core

# 全テスト実行（9ファイル、151テスト）
cd ~/ai-tools/claude-code
bats tests/

# 期待結果: 135/151テスト成功（89.4%）
```

詳細は [tests/README.md](./tests/README.md) 参照。

---

## Serena 効率的な使い方

### 推奨フロー

```javascript
// 1. 概要から始める（軽量）
get_symbols_overview("file.ts")

// 2. 必要なシンボルのみ取得
find_symbol("Class/method", include_body=true)

// 3. ボディなしで構造確認
find_symbol("Class", depth=1, include_body=false)
```

### トークン削減のコツ

| 操作 | 非効率 | 効率的 | 削減率 |
|------|--------|--------|--------|
| ファイル確認 | 全体読み込み | 概要取得 | 93% |
| メソッド確認 | 全メソッド | 特定のみ | 85% |
| 構造確認 | ボディ付き | ボディなし | 93% |

### ベストプラクティス

**DO:**
- `include_body=false` をデフォルト
- `get_symbols_overview()` から始める
- 行範囲指定で一部のみ読む

**DON'T:**
- ファイル全体を読まない
- 複数ファイルを一度に読まない
- depth=2以上を避ける

---

## トラブルシューティング

### Serena が動作しない

```bash
cd ~/serena && uv sync
```

### Codex が動作しない

```bash
npm install -g @openai/codex
```

### ハードリンクエラー

```bash
cd ~/ai-tools/claude-code
./sync.sh
```

---

## 設定オプション

### Bash タイムアウト延長

`~/.claude/settings.json`:

```json
{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "300000"
  }
}
```

デフォルト2分 → 5分に延長。最大10分（600000）。

---

## チェックリスト

- [ ] install.sh 実行完了
- [ ] Serena MCP インストール
- [ ] Codex インストール
- [ ] 🆕 Hooks 動作確認（6つ全て）
- [ ] Output Styles 確認（`/config` でスタイル切替）
- [ ] 🆕 通知音設定（オプション）
- [ ] `/serena オンボーディング` 成功
