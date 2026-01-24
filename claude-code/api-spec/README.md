# API仕様書

Claude Code の Hooks と Agents の OpenAPI 3.0 仕様書。

## 閲覧方法

### オンライン（Swagger Editor）

1. [Swagger Editor](https://editor.swagger.io/) を開く
2. `swagger.yaml` の内容を貼り付け
3. 右側にドキュメントが表示される

### ローカル（Swagger UI）

```bash
# Docker で Swagger UI を起動
docker run -p 8080:8080 \
  -e SWAGGER_JSON=/api-spec/swagger.yaml \
  -v $(pwd)/claude-code/api-spec:/api-spec \
  swaggerapi/swagger-ui

# ブラウザで開く
open http://localhost:8080
```

### VS Code拡張

```bash
# Swagger Viewer 拡張をインストール
code --install-extension Arjun.swagger-viewer

# swagger.yaml を開いて Shift+Alt+P で プレビュー表示
```

## API 概要

### Hooks API

Claude Code のライフサイクルイベントに応答するスクリプト。

| Hook | トリガー | 用途 |
|------|---------|------|
| SessionStart | セッション開始時 | MCP確認、8原則リマインダー |
| UserPromptSubmit | プロンプト送信時 | 技術スタック自動検出（35パターン、90%精度） |
| PreToolUse | ツール実行前 | 危険操作検出、自動整形警告 |
| PreCompact | 圧縮前 | バックアップ保存 |
| SessionEnd | セッション終了時 | 統計ログ、通知音 |

### Agents API

タスクを自律的に実行する専用エージェント。

| Agent | 役割 | Serena MCP使用 |
|-------|------|---------------|
| workflow-orchestrator | タスクタイプ自動判定、ワークフロー実行 | ✅ 必須 |
| verify-app | ビルド・テスト・lint検証 | ✅ 必須 |
| code-simplifier | コード簡素化（複雑度削減・重複統合） | ✅ 必須 |
| po-agent | 戦略決定、Worktree管理 | ✅ 必須 |
| manager-agent | タスク分割、配分計画 | ✅ 必須 |
| developer-agent | 実装担当 | ✅ 必須 |
| explore-agent | 探索・分析（読み取り専用） | ✅ 必須 |
| reviewer-agent | Writer/Reviewer並列パターンレビュー | ✅ 必須 |

## JSON Schema

仕様書内の `components/schemas` セクションに以下を定義：

### Hook Schemas
- `SessionStartInput` / `HookOutput`
- `UserPromptSubmitInput` / `HookOutput`
- `PreToolUseInput` / `HookOutput`
- `PreCompactInput` / `HookOutput`
- `SessionEndInput` / `HookOutput`

### Agent Schemas
- `AgentInput` / `AgentOutput`
- `VerifyAppOutput` (拡張)

## 使用例

### UserPromptSubmit Hook

**リクエスト**:
```json
{
  "prompt": "Go言語でREST APIを実装してください",
  "hook_event_name": "UserPromptSubmit"
}
```

**レスポンス**:
```json
{
  "systemMessage": "🔍 Tech stack detected: golang | Skills: go-backend",
  "additionalContext": "# Auto-Detected Configuration\n\n**Languages**: golang\n**Skills**: go-backend\n**Recommendation**: Run `/load-guidelines`"
}
```

### Workflow Orchestrator Agent

**リクエスト**:
```json
{
  "prompt": "タスク: ユーザー認証機能を追加, タイプ: feature, 複雑度: TaskDecomposition",
  "mode": "plan"
}
```

**レスポンス**:
```json
{
  "status": "success",
  "summary": "ワークフロー完了: PRD → Plan → Dev → Test → Review → Verify → PR",
  "files_created": ["src/auth/login.ts", "src/auth/middleware.ts"],
  "files_modified": ["src/routes/index.ts"]
}
```

## バリデーション

```bash
# OpenAPI 仕様書のバリデーション
npm install -g @apidevtools/swagger-cli
swagger-cli validate claude-code/api-spec/swagger.yaml
```

## 参考

- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Swagger Editor](https://editor.swagger.io/)
- [claude-code/hooks/README.md](../hooks/README.md) - Hooks詳細
- [claude-code/agents/](../agents/) - Agents詳細
