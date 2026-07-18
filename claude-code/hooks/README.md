# Claude Code Hooks

Claude Code の Hooks 機能を活用した自動化スクリプト群（19スクリプト）。

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
| `serena-hook.sh` | Serena 関連イベント | Serena reminder wrapper（activate / remind / auto-approve / cleanup） |
| `stop-verify.sh` | タスク完了時（opt-in） | `STOP_VERIFY_ENFORCE=1` 時のみ smoke test gate、失敗で block |
| `worktree-remove.sh` | worktree 削除後 | projects dir 掃除、dangling cwd の warn 通知 |

## Hook 出力経路の判定基準

- `systemMessage`: user 表示専用 (Claude には届かない)
- `additionalContext`: Claude に届く唯一の経路
- block: Forbidden + exit 2 のみ (stderr にも理由を出すと harness 側で読める)

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

## Hook 実装の path 解決 rule

- hook から参照する規範 file (PRINCIPLES.md 等) は **`$HOME/.claude/` 固定** で指す。source dir (`~/ghq/.../claude-code/`) 参照は sync 後の実行環境に不在で silent 不発火になる (AI 定型語 block が 2026-05-30〜06-20 無動作だった実例)。bats で「実 path 存在 + grep 出力 ≥1 行」を assert する
- ai-tools 配下の path prefix 判定は `_is_aitools_path` / `_aitools_relpath` (`lib/hook-utils.sh`) を経由する。literal prefix 直書きは symlink 表記と ghq 実 path の差で外れる (social-hit block が半年不発だった実例)
- 新規 hook は bats と併せて実 path smoke を 1 発実行する (`bash hooks/xxx.sh < payload.json; echo $?`。file 経由 stdin の理由: `references/bats-test-writing.md` § Execution pitfalls)

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

## pre-tool-use commit message 除外仕様 (v2.2.3 以降)

`pre-tool-use.sh` 内の `classify_bash_command` は、危険語マッチを実行する前に以下のパターンをコマンド文字列から除去する。

| 除外対象 | 例 |
|---------|-----|
| `git commit -m "..."` の double-quoted 引数 | `-m "rm -rf /"` |
| `git commit -m '...'` の single-quoted 引数 | `-m 'sudo rm'` |
| `git commit -F <file>` のファイルパス引数 | `-F /tmp/msg.txt` |
| HEREDOC 本文（v2.2.3, commit `4cd84c9`） | `<<EOF ... EOF` / `<<'EOF'` / `<<"EOF"` / `<<-EOF` 全対応 |

**運用ノート**: コミットメッセージに危険コマンドリテラル（`rm -rf /` / `git push --force` / `sudo rm` / fork bomb / `> /dev/X` 等）をそのまま書いてよい。HEREDOC 形式でも安全。文字を分離したり日本語に言い換えたりする回避策は不要。

ただし HEREDOC 終端マーカー（`EOF`）の後に追記された危険語は除外対象外（仕様通り。本物の危険コマンドを検出するため）。

### 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-27 | コミットメッセージ内 `rm -rf /` が誤発火 → `-m "..."` sed 除外を導入 |
| 2026-05-01 | HEREDOC 形式が貫通 → HEREDOC 本文除去（POSIX awk）を追加（v2.2.3） |

## 参考

- [Claude Code Hooks Guide](https://docs.anthropic.com/en/docs/claude-code/hooks)
