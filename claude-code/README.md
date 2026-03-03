# Claude Code Hooks

**バージョン**: v2.1.63 | **最終更新**: 2026-03-03

Claude Code 1.0.82+ の Hooks 機能を活用した自動化スクリプト群。CLAUDE.md の 8原則を自動適用します。

## 概要

Hooks は Claude Code のイベント（セッション開始、ツール実行前、完了時など）に自動的にスクリプトを実行できる機能です。

## 実装済みフック

### 1. session-start.sh
**トリガー**: セッション開始時

**機能**:
- Serena MCP の有効状態を確認
- 8原則のリマインダーを表示
- 利用可能なMCPサーバー情報を提供

**出力例**:
```json
{
  "systemMessage": "📋 Serena MCP is active. Use /serena to access project memory.",
  "additionalContext": "# Available Tools\n- Serena MCP: ...\n# 8 Principles Reminder\n..."
}
```

### 2. user-prompt-submit.sh ⭐️ 最重要
**トリガー**: ユーザープロンプト送信時（全プロンプト）

**機能**:
- プロンプトから技術スタック自動検出（Go, TypeScript, React等）
- 適切なスキルを自動推奨（go-backend, react-nextjs等）
- 8原則チェックリストの表示
- Serena memory検索の推奨

**検出パターン**:
- **言語**: Go, TypeScript, React, Next.js
- **インフラ**: Docker, Kubernetes, Terraform
- **レビュー**: security, performance, architecture
- **設計**: clean-architecture, DDD

**出力例**:
```json
{
  "systemMessage": "🔍 Tech stack detected: go | Skills: go-backend",
  "additionalContext": "# Auto-Detected Configuration\n\n**Languages**: go\n**Recommendation**: Run `/load-guidelines`..."
}
```

### 3. pre-tool-use.sh
**トリガー**: ツール実行直前

**機能**:
- 危険な自動整形コマンドの検出（8原則: 自動処理禁止）
- ファイル編集時の型安全性リマインダー
- Serena MCP 使用時のメモリ更新リマインダー

**検出パターン**:
- `npm run lint`, `prettier`, `eslint --fix`, `go fmt` など

**出力例**:
```json
{
  "systemMessage": "⚠️  Auto-formatting detected. 8原則: 自動処理禁止 - User confirmation recommended."
}
```

### 4. pre-compact.sh
**トリガー**: コンテキスト圧縮前

**機能**:
- セッション情報の自動バックアップ
- Serena memoryへの保存推奨
- 圧縮後のリカバリー手順表示

**出力例**:
```json
{
  "systemMessage": "📦 Pre-compact backup saved: ~/.claude/pre-compact-backups/...",
  "additionalContext": "## 🧠 Serena Memory Recommendation\n\n**Action Required**: Save important information..."
}
```

### 5. stop.sh
**トリガー**: タスク完了時

**機能**:
- 完了通知音の再生（8原則: 完了通知）
- `~/notification.mp3` を afplay で再生

**出力例**:
```json
{
  "systemMessage": "🔔 Task completed. Notification sound played."
}
```

### 6. session-end.sh
**トリガー**: セッション終了時

**機能**:
- セッション統計の自動ログ保存
- 完了通知音の再生（Stop hookより確実）
- 長時間セッション時のSerena memory保存推奨

**出力例**:
```json
{
  "systemMessage": "🔔 Notification sound played | Session logged to ~/.claude/session-logs/...",
  "additionalContext": "# Session Summary\n\n- **Messages**: 25\n- **Tokens**: 50000..."
}
```

## セットアップ

### 1. Hooks を有効化

`~/.claude/settings.json` に以下を追加:

```json
{
  "hooks": {
    "SessionStart": {
      "command": "~/.claude/hooks/session-start.sh"
    },
    "UserPromptSubmit": {
      "command": "~/.claude/hooks/user-prompt-submit.sh"
    },
    "PreToolUse": {
      "command": "~/.claude/hooks/pre-tool-use.sh"
    },
    "PreCompact": {
      "command": "~/.claude/hooks/pre-compact.sh"
    },
    "Stop": {
      "command": "~/.claude/hooks/stop.sh"
    },
    "SessionEnd": {
      "command": "~/.claude/hooks/session-end.sh"
    }
  }
}
```

### 2. 通知音を配置（オプション）

```bash
# 任意の mp3 ファイルを配置
cp /path/to/your/sound.mp3 ~/notification.mp3
```

### 3. 動作確認

```bash
# セッション開始フックのテスト
echo '{"mcp_servers": {"serena": {}}}' | ~/.claude/hooks/session-start.sh

# プロンプト送信フックのテスト（最重要）
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
echo '{"prompt": "TypeScriptとReactでコンポーネントを作成"}' | ~/.claude/hooks/user-prompt-submit.sh

# ツール実行前フックのテスト
echo '{"tool_name": "Bash", "tool_input": {"command": "npm run lint"}}' | ~/.claude/hooks/pre-tool-use.sh

# コンパクション前フックのテスト
echo '{"session_id": "test", "workspace": {"current_dir": "/Users/daichi/ai-tools"}, "current_tokens": 150000, "mcp_servers": {"serena": {}}}' | ~/.claude/hooks/pre-compact.sh

# タスク完了フックのテスト
echo '{}' | ~/.claude/hooks/stop.sh

# セッション終了フックのテスト
echo '{"session_id": "test", "workspace": {"current_dir": "/Users/daichi/ai-tools"}, "total_tokens": 50000, "total_messages": 25, "duration": 1200}' | ~/.claude/hooks/session-end.sh
```

## 8原則との対応

| 原則 | フック | 実装内容 |
|------|--------|----------|
| 1. mem | **UserPromptSubmit** ⭐️ | プロンプトからSerena memory検索を推奨 |
| 2. serena | SessionStart, **UserPromptSubmit** | /serena コマンド利用を促す |
| 3. guidelines | **UserPromptSubmit** ⭐️ | 技術スタック自動検出 → load-guidelines推奨 |
| 4. 自動処理禁止 | PreToolUse | 自動整形コマンドを検出・警告 |
| 5. 完了通知 | Stop, **SessionEnd** ⭐️ | afplay で通知音再生（SessionEndがより確実） |
| 6. 型安全 | PreToolUse, **UserPromptSubmit** | ファイル編集時・プロンプト時にリマインダー |
| 7. コマンド提案 | **UserPromptSubmit** ⭐️ | 技術スタック検出 → 適切なスキル推奨 |
| 8. 確認済 | PreToolUse, **UserPromptSubmit** | 実行前・プロンプト時に確認を促す |

**新規追加の効果**:
- **UserPromptSubmit**: 8原則中5つを自動化（最重要）
- **SessionEnd**: 完了通知の確実性向上 + 統計ログ
- **PreCompact**: コンテキスト消失防止

## 利用可能な Hooks イベント

- **SessionStart**: セッション開始時
- **PreToolUse**: ツール実行前
- **PostToolUse**: ツール実行後
- **Stop**: タスク完了時
- **SubagentStop**: サブエージェント完了時
- **PreCompact**: コンパクション前
- **UserPromptSubmit**: ユーザープロンプト送信時
- **PermissionRequest**: 権限リクエスト時

## カスタマイズ

各スクリプトは JSON 入力を受け取り、JSON 出力を返します。

**入力例**:
```json
{
  "tool_name": "Bash",
  "tool_input": { "command": "ls -la" },
  "mcp_servers": { "serena": {} },
  "hook_event_name": "PreToolUse"
}
```

**出力フォーマット**:
```json
{
  "systemMessage": "ユーザーに表示されるメッセージ",
  "additionalContext": "AI に渡される追加コンテキスト（オプション）"
}
```

## トラブルシューティング

### フックが実行されない

1. スクリプトに実行権限があるか確認:
```bash
chmod +x ~/.claude/hooks/*.sh
```

2. settings.json の JSON 構文を確認:
```bash
jq . ~/.claude/settings.json
```

3. フックのログを確認:
```bash
tail -f ~/.claude/debug/*.log
```

### 通知音が再生されない

1. ファイルの存在確認:
```bash
ls -la ~/notification.mp3
```

2. afplay の動作確認:
```bash
afplay ~/notification.mp3
```

## 参考リンク

- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [ai-tools リポジトリ](https://github.com/yourusername/ai-tools)
