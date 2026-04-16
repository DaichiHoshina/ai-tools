# Claude Code Hooks

Claude Code の Hooks 機能を活用した自動化スクリプト群（16スクリプト）。

## 実装済みフック

| フック | トリガー | 主な機能 |
|--------|---------|---------|
| `session-start.sh` | セッション開始時 | Serena MCP確認、リマインダー |
| `user-prompt-submit.sh` ★ | プロンプト送信時 | 技術スタック自動検出、スキル推奨 |
| `pre-tool-use.sh` | ツール実行前 | 危険コマンド検出、型安全リマインダー |
| `post-tool-use.sh` | ツール実行後 | 自動フォーマット（Go: `gofmt`、TS/JS: `prettier`） |
| `post-tool-use-failure.sh` | ツール失敗後 | エラー対応 |
| `pre-compact.sh` | コンテキスト圧縮前 | Serena memory保存指示 |
| `post-compact-reload.sh` | compact後 | `compact-restore-*` メモリ自動復元 |
| `stop.sh` | タスク完了時 | 完了通知音 |
| `stop-failure.sh` | タスク失敗時 | 失敗通知 |
| `session-end.sh` | セッション終了時 | セッション統計ログ、通知音再生 |
| `setup.sh` | 初期設定 | 環境セットアップ |
| `permission-denied.sh` | 権限拒否時 | 権限エラー対応 |
| `subagent-start.sh` | サブエージェント開始 | サブエージェント管理 |
| `subagent-stop.sh` | サブエージェント終了 | サブエージェント管理 |
| `task-completed.sh` | タスク完了 | タスク完了処理 |
| `teammate-idle.sh` | チームメイトアイドル | アイドル検知 |

## セットアップ

### 1. Hooks を有効化

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]},
      {"matcher": "compact", "hooks": [{"type": "command", "command": "~/.claude/hooks/post-compact-reload.sh"}]}
    ],
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/user-prompt-submit.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Edit|Write|Bash", "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-tool-use.sh"}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "~/.claude/hooks/post-tool-use.sh", "async": true}]}
    ],
    "PostToolUseFailure": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/post-tool-use-failure.sh"}]}
    ],
    "PreCompact": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-compact.sh"}]}
    ],
    "Stop": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/stop.sh", "async": true}]}
    ],
    "StopFailure": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/stop-failure.sh", "async": true}]}
    ],
    "SubagentStart": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/subagent-start.sh", "async": true}]}
    ],
    "SubagentStop": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/subagent-stop.sh", "async": true}]}
    ],
    "TaskCompleted": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/task-completed.sh", "async": true}]}
    ],
    "SessionEnd": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/session-end.sh", "async": true}]}
    ]
  }
}
```

### 2. 通知音を配置（オプション）

```bash
cp /path/to/your/sound.mp3 ~/notification.mp3
```

### 3. 動作確認

```bash
echo '{"mcp_servers": {"serena": {}}}' | ~/.claude/hooks/session-start.sh
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
echo '{"tool_name": "Bash", "tool_input": {"command": "npm run lint"}}' | ~/.claude/hooks/pre-tool-use.sh
echo '{}' | ~/.claude/hooks/stop.sh
```

## 入出力スキーマ

**入力** (stdin JSON):

| フィールド | 型 | 説明 |
|----------|-----|------|
| `session_id` | string | セッションID |
| `prompt` | string | ユーザープロンプト（UserPromptSubmit時） |
| `tool_name` | string | ツール名（PreToolUse/PostToolUse時） |
| `tool_input` | object | ツール入力パラメータ |
| `mcp_servers` | object | 有効なMCPサーバー情報（SessionStart時） |

**出力** (stdout JSON):

```json
{
  "systemMessage": "ユーザーに表示されるメッセージ",
  "additionalContext": "AIに渡される追加コンテキスト（オプション）"
}
```

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| フックが実行されない | `chmod +x ~/.claude/hooks/*.sh` を確認 |
| settings.json が不正 | `jq . ~/.claude/settings.json` で検証 |
| jq が見つからない | `brew install jq` |
| 通知音が鳴らない | `ls ~/notification.mp3` → `afplay ~/notification.mp3` でテスト |
| lib/ が見つからない | `./claude-code/install.sh` を実行 |

## 利用可能なイベント

`SessionStart`, `SessionEnd`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Stop`, `StopFailure`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `PermissionRequest`, `TaskCompleted`, `TeammateIdle`

## 参考

- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
