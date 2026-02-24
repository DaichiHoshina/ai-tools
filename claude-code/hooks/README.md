# Claude Code Hooks

Claude Code 1.0.82+ の Hooks 機能を活用した自動化スクリプト群。CLAUDE.md の 8原則を自動適用します。

## 概要

Hooks は Claude Code のイベント（セッション開始、ツール実行前、完了時など）に自動的にスクリプトを実行できる機能です。

## JSON Schema 定義

### 入力スキーマ（stdin から受け取る JSON）

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "HookInput",
  "type": "object",
  "properties": {
    "session_id": {
      "type": "string",
      "description": "現在のセッションID"
    },
    "prompt": {
      "type": "string",
      "description": "ユーザーが入力したプロンプト（UserPromptSubmit時）"
    },
    "tool_name": {
      "type": "string",
      "description": "実行されるツール名（PreToolUse/PostToolUse時）"
    },
    "tool_input": {
      "type": "object",
      "description": "ツールへの入力パラメータ"
    },
    "mcp_servers": {
      "type": "object",
      "description": "有効なMCPサーバー情報（SessionStart時）"
    }
  }
}
```

### 出力スキーマ（stdout に出力する JSON）

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "HookOutput",
  "type": "object",
  "required": ["systemMessage"],
  "properties": {
    "systemMessage": {
      "type": "string",
      "minLength": 1,
      "description": "ユーザーに表示されるメッセージ（1行推奨）"
    },
    "additionalContext": {
      "type": "string",
      "description": "Claude AIに渡される追加コンテキスト（Markdown形式、改行区切りセクション）"
    }
  },
  "additionalProperties": false
}
```

### エラーレスポンススキーマ

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "HookError",
  "type": "object",
  "required": ["error"],
  "properties": {
    "error": {
      "type": "string",
      "description": "エラーメッセージ"
    }
  }
}
```

### 出力例

**成功時**:
```json
{
  "systemMessage": "🔍 Tech stack detected: go | Skills: go-backend",
  "additionalContext": "# Auto-Detected Configuration\n\n**Languages**: go"
}
```

**エラー時**:
```json
{
  "error": "jq not installed. Please run: brew install jq"
}
```

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

**Phase 2での技術的改善**:

user-prompt-submit.shは、複数の検出関数を統合して技術スタックを自動検出します:
- `detect-from-keywords.sh`: プロンプト内のキーワードから検出
- `detect-from-errors.sh`: エラーログから検出
- `detect-from-context.sh`: git diffや作業ディレクトリから検出

この統合により、単一のフック内で複数の観点から技術スタックを判断し、より正確なスキル推奨が可能になりました。各detect関数は独立してテスト可能で、保守性も向上しています（BATS単体テスト151件中、detect関数関連14件）。

**出力例**:
```json
{
  "systemMessage": "🔍 Tech stack detected: go | Skills: go-backend",
  "additionalContext": "# Auto-Detected Configuration\n\n**Languages**: go\n**Recommendation**: Run `/load-guidelines`..."
}
```

$1### 4. post-tool-use.sh
**トリガー**: ツール実行後

**機能**:
- 編集後の自動フォーマット（Go/TypeScript/JavaScript）
- CIでフォーマットエラー防止
- Boris: "最後の10%を仕上げる"

**対象ツール**:
- `Edit`, `Write`

**フォーマッタ**:
- **Go** (`.go`): `gofmt -w $FILE_PATH`
- **TypeScript/JavaScript** (`.ts`, `.tsx`, `.js`, `.jsx`): `npx prettier --write $FILE_PATH`

**エラーハンドリング**:
- フォーマット失敗は無視（警告のみ、non-blocking）

**出力例**:
```json
{
  "systemMessage": "✅ Auto-formatted (Go): /path/to/file.go"
}
```

### 5. pre-compact.sh
**トリガー**: コンテキスト圧縮前（`PreCompact` イベント）

**機能**:
- Serena memoryへの保存を指示（`compact-restore-YYYYMMDD_HHMMSS` 形式）
- 保存内容（タスク・進捗・ファイル・次アクション）を指定
- compact後は `post-compact-reload.sh` が自動復元することを通知

**出力例**:
```json
{
  "systemMessage": "◉ COMPACT検出 - Serena memoryに保存してください",
  "additionalContext": "**必須**: `mcp__serena__write_memory` で `compact-restore-...` に保存\n..."
}
```

### 5a. post-compact-reload.sh
**トリガー**: compact後のセッション再開時（`SessionStart` の `"compact"` matcher）

> **注意**: Claude CodeにはPostCompact hookが未実装のため、SessionStart compact matcherで代替。

**機能**:
- compact後に自動で `/reload` 相当の復元処理を実行するよう指示
- `compact-restore-*` メモリを読み込み → 削除 → サマリー報告

**出力例**:
```json
{
  "systemMessage": "✓ COMPACT完了 - コンテキスト自動復元を開始",
  "additionalContext": "**自動実行（必須）**: compact後の復元手順\n1. `mcp__serena__list_memories` で..."
}
```

### 6. stop.sh
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

### 7. session-end.sh
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
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/session-start.sh"}]
      },
      {
        "matcher": "compact",
        "hooks": [{"type": "command", "command": "~/.claude/hooks/post-compact-reload.sh"}]
      }
    ],
    "UserPromptSubmit": [
      {"matcher": "*", "hooks": [{"type": "command", "command": "~/.claude/hooks/user-prompt-submit.sh"}]}
    ],
    "PreToolUse": [
      {"matcher": "Edit|Write|Bash|...", "hooks": [{"type": "command", "command": "~/.claude/hooks/pre-tool-use.sh"}]}
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
echo '{\"tool_name\": \"Bash\", \"tool_input\": {\"command\": \"npm run lint\"}}' | ~/.claude/hooks/pre-tool-use.sh

# ツール実行後フックのテスト（PostToolUse）
echo '{\"tool_name\": \"Write\", \"tool_input\": {\"file_path\": \"/tmp/test.go\"}}' | ~/.claude/hooks/post-tool-use.sh
echo '{\"tool_name\": \"Edit\", \"tool_input\": {\"file_path\": \"/tmp/test.ts\"}}' | ~/.claude/hooks/post-tool-use.sh

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
- **SessionEnd**: セッション終了時
- **PreToolUse**: ツール実行前
- **PostToolUse**: ツール実行後
- **Stop**: タスク完了時
- **SubagentStop**: サブエージェント完了時
- **PreCompact**: コンパクション前
- **UserPromptSubmit**: ユーザープロンプト送信時
- **PermissionRequest**: 権限リクエスト時
- **WorktreeCreate**: git worktree作成時（v2.1.47+）
- **WorktreeRemove**: git worktree削除時（v2.1.47+）
- **ConfigChange**: 設定変更時（v2.1.47+）

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

## エラーケース一覧

各フックで発生する可能性のあるエラーケースと対処方法を一覧化。

### session-start.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `security-functions.sh not found` | lib/ ディレクトリ不在 | install.sh を実行 |
| `jq not installed` | jq コマンド不在 | `brew install jq` |
| JSON パースエラー | 不正な JSON 入力 | 入力形式を確認 |
| 出力なし | MCP サーバー未検出（正常） | 問題なし（検出時のみ出力） |

### user-prompt-submit.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `detect-from-*.sh not found` | lib/ ディレクトリ不在 | install.sh を実行、または chmod +x 確認 |
| `Input size exceeds limit (1MB)` | プロンプトサイズ超過 | プロンプトを分割 |
| JSON パースエラー | 不正な JSON 入力 | 入力形式を確認 |
| git diff エラー | git リポジトリ外 | git init または無視 |
| 出力なし | 技術スタック未検出（正常） | 問題なし（検出時のみ出力） |

### pre-tool-use.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `security-functions.sh not found` | lib/ ディレクトリ不在 | install.sh を実行 |
| JSON パースエラー | 不正な JSON 入力 | 入力形式を確認 |
| `tool_name` 不在 | 入力に `tool_name` フィールドなし | 入力形式を確認 |
| 危険なコマンド検出 | `rm -rf /` などを検出 | 警告メッセージを表示（正常動作） |

### post-tool-use.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| フック未実装 | post-tool-use.sh がない | 将来実装予定（現時点では任意） |

### pre-compact.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `security-functions.sh not found` | lib/ ディレクトリ不在 | install.sh を実行 |
| バックアップディレクトリ作成失敗 | 権限エラー | `mkdir -p ~/.claude/pre-compact-backups` |
| JSON パースエラー | 不正な JSON 入力 | 入力形式を確認 |

### stop.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `afplay` コマンド失敗 | notification.mp3 不在 | `~/notification.mp3` を配置 |
| 通知音再生できない | macOS 以外の OS | Linux/Windows 用コマンドに変更 |

### session-end.sh

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `security-functions.sh not found` | lib/ ディレクトリ不在 | install.sh を実行 |
| ログディレクトリ作成失敗 | 権限エラー | `mkdir -p ~/.claude/session-logs` |
| `afplay` コマンド失敗 | notification.mp3 不在 | `~/notification.mp3` を配置 |
| JSON パースエラー | 不正な JSON 入力 | 入力形式を確認 |

### 共通エラー

| エラーケース | 原因 | 対処方法 |
|------------|------|---------|
| `bash: command not found` | Bash バージョン不一致 | shebang を `/usr/bin/env bash` に変更 |
| 実行権限エラー | chmod +x されていない | `chmod +x ~/.claude/hooks/*.sh` |
| JSON 出力が壊れる | jq エラー | jq の `-n` と `--arg` を使用 |
| パフォーマンス低下 | 検出ロジックが遅い | Phase 3 のキャッシング実装を適用 |

---

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
