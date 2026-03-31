# Claude Code Hooks

Claude Code 1.0.82+ の Hooks 機能を活用した自動化スクリプト群。CLAUDE.md の 8原則を自動適用します。

## 実装済みフック

| フック | トリガー | 主な機能 |
|--------|---------|---------|
| `session-start.sh` | セッション開始時 | Serena MCP 確認、8原則リマインダー |
| `user-prompt-submit.sh` ★ | プロンプト送信時 | 技術スタック自動検出、スキル推奨、Serena memory検索推奨 |
| `pre-tool-use.sh` | ツール実行前 | 危険コマンド検出、型安全リマインダー |
| `post-tool-use.sh` | ツール実行後 | 自動フォーマット（Go: `gofmt`、TS/JS: `prettier`） |
| `pre-compact.sh` | コンテキスト圧縮前 | Serena memory保存指示（`compact-restore-YYYYMMDD_HHMMSS`） |
| `post-compact-reload.sh` | compact後の SessionStart | `compact-restore-*` メモリ自動復元 |
| `stop.sh` | タスク完了時 | 完了通知音（`afplay ~/notification.mp3`） |
| `session-end.sh` | セッション終了時 | セッション統計ログ保存、通知音再生 |

## 8原則との対応

| 原則 | 担当フック |
|------|----------|
| 1. mem | UserPromptSubmit |
| 2. serena | SessionStart, UserPromptSubmit |
| 3. guidelines | UserPromptSubmit（技術スタック自動検出） |
| 4. 自動処理禁止 | PreToolUse |
| 5. 完了通知 | Stop, SessionEnd |
| 6. 型安全 | PreToolUse, UserPromptSubmit |
| 7. コマンド提案 | UserPromptSubmit |
| 8. 確認済 | PreToolUse, UserPromptSubmit |

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
    "PreCompact": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-compact.sh"}]}
    ],
    "Stop": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "afplay ~/notification.mp3", "async": true}]}
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

`SessionStart`, `SessionEnd`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `PreCompact`, `UserPromptSubmit`, `PermissionRequest`, `WorktreeCreate`, `WorktreeRemove`, `ConfigChange`（v2.1.47+）

## 参考

- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
