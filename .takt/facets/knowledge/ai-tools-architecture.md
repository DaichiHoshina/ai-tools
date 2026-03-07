# ai-tools アーキテクチャ知識

## リポジトリ構造

```
ai-tools/
├── claude-code/
│   ├── hooks/          # Claudeイベントフック（session-start, session-end, post-tool-use等）
│   ├── lib/            # Bash共有ライブラリ
│   ├── commands/       # スラッシュコマンド定義（.md）
│   ├── skills/         # スキル定義（.md）
│   ├── agents/         # エージェント定義（.md）
│   ├── settings/       # 設定ファイル
│   ├── scripts/        # Bashスクリプト・Pythonスクリプト
│   ├── guidelines/     # 言語・設計ガイドライン
│   ├── install.sh      # ~/.claude/への初回インストール
│   └── sync.sh         # ~/.claude/との同期
├── dashboard/          # Claude Code利用状況Webダッシュボード
│   ├── server.py       # Python標準ライブラリのHTTPサーバー
│   └── index.html      # バニラHTML/JS + Chart.js
└── .takt/              # TAKTワークフローエンジン設定
    ├── pieces/         # ワークフロー定義YAML
    └── facets/         # カスタムペルソナ・ナレッジ・インストラクション
```

## lib/ ライブラリ規約

全フックは `source lib/common.sh` で以下を自動取得:
- `lib/colors.sh` - ターミナル色定数（CYAN, GREEN, YELLOW, RED等）
- `lib/print-functions.sh` - print_info, print_success, print_warning, print_error
- `lib/security-functions.sh` - 入力値検証・サニタイズ
- `lib/hook-utils.sh` - フックユーティリティ

### analytics-writer.sh の使用
SQLite利用状況記録は必ずこのライブラリを経由する:
```bash
source "${_LIB_DIR}/analytics-writer.sh"
analytics_insert_tool_event "$SESSION_ID" "$PROJECT" "$TOOL_NAME"
analytics_insert_session "$SESSION_ID" "$PROJECT" "$MODEL" ...
analytics_insert_agent_start "$AGENT_ID" "$AGENT_TYPE" "$PROJECT"
analytics_update_agent_stop "$AGENT_ID"
```

## フック規約

### JSON出力フォーマット
全フックはJSON形式で標準出力に返す（`jq -n`を使用）:
```bash
jq -n \
  --arg sm "メッセージ" \
  --arg ac "追加コンテキスト" \
  '{systemMessage: $sm, additionalContext: $ac}'
```

### パス解決
フック内でのlibパスは `BASH_SOURCE[0]` から解決:
```bash
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_HOOK_DIR}/../lib"
source "${_LIB_DIR}/common.sh"
```

### フック一覧
| フック | 用途 |
|--------|------|
| session-start.sh | セッション初期化、analyticsブリーフ表示 |
| session-end.sh | セッション統計をSQLiteに記録 |
| post-tool-use.sh | ツール使用後処理（フォーマット、analytics記録） |
| pre-tool-use.sh | ツール使用前チェック（セキュリティ等） |
| subagent-start.sh | エージェント開始をSQLiteに記録 |
| subagent-stop.sh | エージェント終了をSQLiteに記録 |
| user-prompt-submit.sh | ユーザー入力前処理 |
| stop.sh | セッション停止時処理 |

## コマンド/スキル定義規約

フロントマター必須のMarkdown形式:
```markdown
---
description: 1行の説明
allowed-tools: Bash, Read, Edit  # オプション
---

## コマンド内容
...
```

## スキル一覧（主要）

| スキル | 用途 |
|--------|------|
| /flow | PO→Manager→Dev並列の自動ワークフロー |
| /dev | 直接実装（Agent不使用）|
| /git-push | commit→push→PR作成を統合 |
| /analytics | 利用状況分析・インサイト提示 |
| /takt | TAKTワークフロー実行 |
| /plan | PO Agentで戦略策定 |
| /review | comprehensive-reviewで7観点レビュー |
| /test | テスト作成専用 |
| /refactor | リファクタリング |
| /lint-test | CI相当のローカルチェック |
| /diagnose | デバッグ支援 |
| /protection-mode | 操作保護モード読み込み |

## エージェント一覧

| エージェント | 用途 |
|------------|------|
| po-agent | 戦略決定・Worktree管理 |
| manager-agent | タスク分割・配分計画 |
| developer-agent | 実装担当（Serena MCP必須） |
| explore-agent | 探索・分析（読み取り専用） |
| root-cause-analyzer | 根本原因分析 |
| reviewer-agent | コードレビュー |
| workflow-orchestrator | /flowコマンドの実行エンジン |

## Serena MCP 使用規約

コード変更には必ずSerena MCP toolを優先使用:
```
探索: mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__search_for_pattern
読込: mcp__serena__read_file, mcp__serena__list_dir
編集: mcp__serena__replace_symbol_body, mcp__serena__replace_content
     mcp__serena__insert_after_symbol, mcp__serena__insert_before_symbol
実行: mcp__serena__execute_shell_command
```

ファイル全体を読む前にシンボル検索を試みる。必要な部分のみ取得。

## Analytics DB

SQLite: `~/.claude/analytics/analytics.db`

| テーブル | 内容 |
|----------|------|
| tool_events | ツール使用イベント（tool_name, project, timestamp） |
| sessions | セッション統計（tokens, model, duration） |
| agent_events | エージェント実行ログ（agent_type, duration） |

## 同期フロー

```bash
# 変更をローカルに反映
./claude-code/sync.sh to-local   # リポジトリ→~/.claude/

# ローカルからリポジトリに取り込み
./claude-code/sync.sh from-local  # ~/.claude/→リポジトリ
```

## コーディング規約

### Bash
- shebang: `#!/usr/bin/env bash`
- `set -e` は使わない（フックでは特に）
- エラーは `|| true` で無視するか `|| return 1`
- 変数は `${VAR:-default}` でデフォルト値設定
- 関数名: snake_case

### Python
- 標準ライブラリのみ（pip不要）
- 型ヒント使用
- DB書き込みエラーは stderr に warn して継続

### ログ基準
- error: 継続不可・到達不能パス
- warn: 異常だが継続可
- info: 正常系
- debug使用禁止

### 禁止事項
- ハードコードされたパス（/Users/daichi等）→ `$HOME` 使用
- TODOコメント（今やるか削除するか）
- 後方互換ハック
- 秘匿情報のコード内埋め込み
