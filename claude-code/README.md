# Claude Code Hooks

**バージョン**: v2.1.71 | **最終更新**: 2026-03-07

Claude Code 1.0.82+ の Hooks 機能を活用した自動化スクリプト群。CLAUDE.md の 8原則を自動適用します。

## 実装済みフック

| フック | トリガー | 主な機能 |
|--------|---------|---------|
| `session-start.sh` | セッション開始時 | Serena MCP 確認、8原則リマインダー |
| `user-prompt-submit.sh` ★ | プロンプト送信時 | 技術スタック自動検出（Go/TS/React等）、スキル推奨 |
| `pre-tool-use.sh` | ツール実行前 | 危険コマンド検出、型安全リマインダー |
| `pre-compact.sh` | コンテキスト圧縮前 | Serena memory保存指示 |
| `stop.sh` | タスク完了時 | 完了通知音再生 |
| `session-end.sh` | セッション終了時 | セッション統計ログ、通知音再生 |

## セットアップ

```json
{
  "hooks": {
    "SessionStart": {"command": "~/.claude/hooks/session-start.sh"},
    "UserPromptSubmit": {"command": "~/.claude/hooks/user-prompt-submit.sh"},
    "PreToolUse": {"command": "~/.claude/hooks/pre-tool-use.sh"},
    "PreCompact": {"command": "~/.claude/hooks/pre-compact.sh"},
    "Stop": {"command": "~/.claude/hooks/stop.sh"},
    "SessionEnd": {"command": "~/.claude/hooks/session-end.sh"}
  }
}
```

## 動作確認

```bash
echo '{"mcp_servers": {"serena": {}}}' | ~/.claude/hooks/session-start.sh
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
echo '{"tool_name": "Bash", "tool_input": {"command": "npm run lint"}}' | ~/.claude/hooks/pre-tool-use.sh
echo '{}' | ~/.claude/hooks/stop.sh
```

## 8原則との対応

| 原則 | 担当フック |
|------|----------|
| 1. mem | UserPromptSubmit |
| 2. serena | SessionStart, UserPromptSubmit |
| 3. guidelines | UserPromptSubmit |
| 4. 自動処理禁止 | PreToolUse |
| 5. 完了通知 | Stop, SessionEnd |
| 6. 型安全 | PreToolUse, UserPromptSubmit |
| 7. コマンド提案 | UserPromptSubmit |
| 8. 確認済 | PreToolUse, UserPromptSubmit |

## 利用可能なイベント

`SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `PreCompact`, `UserPromptSubmit`, `PermissionRequest`

## カスタマイズ

各スクリプトは JSON 入力を受け取り、JSON 出力を返します。

```json
{
  "systemMessage": "ユーザーに表示されるメッセージ",
  "additionalContext": "AIに渡される追加コンテキスト（オプション）"
}
```

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| フックが実行されない | `chmod +x ~/.claude/hooks/*.sh` |
| settings.json が不正 | `jq . ~/.claude/settings.json` |
| 通知音が鳴らない | `ls ~/notification.mp3` → `afplay ~/notification.mp3` |

## 参考リンク

- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
