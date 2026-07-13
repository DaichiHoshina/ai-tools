# Hook Payload Map

Canonical: Claude Code 公式 hook event の JSON 入力 field 一覧と、`hooks/` 配下で extract / 未 extract の対応表。

source: https://code.claude.com/docs/en/hooks (確認日: 2026-06-19)

## Common fields (全 event)

| field | type | 備考 |
|---|---|---|
| `session_id` | string | session 識別子 |
| `transcript_path` | string | 会話 JSONL の絶対 path |
| `cwd` | string | hook 起動時の cwd |
| `permission_mode` | string | `default` / `plan` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` (一部 event は無) |
| `effort` | object | `{ level: "low"\|"medium"\|"high"\|"xhigh"\|"max" }` (tool-use context 内のみ) |
| `hook_event_name` | string | event 名 |
| `agent_id` | string | subagent 内 hook のみ |
| `agent_type` | string | subagent 内 hook のみ |

## Event 別追加 field

### PreToolUse

- `tool_name`, `tool_input`

### PostToolUse (成功)

- `tool_name`, `tool_input`, `tool_output`

### PostToolUseFailure

| field | type | 備考 |
|---|---|---|
| `tool_name` | string | 失敗したツール名 |
| `tool_input` | object | 引数 |
| `error` | string | 失敗 message |
| `duration_ms` | number | 失敗までの ms |

### SubagentStart / SubagentStop

- Common fields のみ (`agent_id` / `agent_type` 経由で subagent 識別可)
- **重要**: `status` / `verdict` / `exit_code` / `stop_reason` 等の **完了状態 field は一切渡らない**

### Stop / StopFailure

- Stop: Common fields のみ
- StopFailure: `error` (`rate_limit` / `overloaded` / `authentication_failed` / `oauth_org_not_allowed` / `billing_error` / `invalid_request` / `model_not_found` / `server_error` / `max_output_tokens` / `unknown`)

## hooks/ extract 状況

| hook | 現状 extract | 不足 field | 改修 |
|---|---|---|---|
| `subagent-start.sh` | `agent_id`, `agent_type`, `cwd` | - (公式無) | `agent_type=unknown` block (別件) |
| `subagent-stop.sh` | `agent_id`, `agent_type`, `cwd` | - (公式無) | **直接 failure 検知不能** → 後述 |
| `post-tool-use-failure.sh` | `tool_name`, `session_id`, `cwd`, `duration_ms`, `error` | OK | parent 通知 path 追加 (Phase 3 dev2) |
| `stop-failure.sh` | `cwd` | `error` (拾えるが未 read) | StopFailure 用 (現状 API error 通知済、OK) |

## Subagent failure 検知 設計方針

公式 SubagentStop event は failure 系 field を渡さない。よって subagent-stop.sh だけで `status: failure` を判定する path は実装不可能。代替案 2 つ:

### 案 A: parent inline 受取 gate (採用)

Task() の返り値を parent 側で受け取った時点で trailer の `status` field (取りうる値: `success` / `partial` / `failure` / `dep_unresolved` / `blocked`) を確認する。subagent-stop.sh は触らず、各 agent md の **Output schema** で trailer 必須化 + callsite の commands/agents md で gate 化する。

→ Phase 1 (agent-output-schema.md canonical 化) + Phase 2 (callsite gate 記載) で対応

### 案 B: subagent-stop.sh で transcript_path tail read (不採用)

transcript_path から last Task result を tail read して trailer 抽出。技術的に可能だが:
- transcript JSONL の schema が docs 未公開 → 不安定
- hook latency 増 (read + parse)
- hook 経由で parent に通知する path が systemMessage のみ = inline 受取より遅延

→ 採用しない。

## Under-parallel 検知の設計制約

PreToolUse hook は単一 tool_use の静的内容しか観測できない。前 Task の完了状態も turn 境界も渡らず、時間差でも「1 message 内の同時並列」と「逐次発火」は分離できない (並列は hook が N 回ほぼ同時起動して差分 ≒0 秒、逐次も短間隔になりうる)。under-parallel (Agent を少なく呼ぶ不作為) の機械 block は原理的に不可能で、Task 発火時の self-review reminder inject (`pre-tool-use.sh` `"Task")` branch) が技術上限になる。時間差ベースで並列 / 逐次を判別する hook 設計は最初から却下する。

## Phase 3 hook 改修方針 (Plan 更新)

- **subagent-stop.sh**: failure 検知は実装せず、`agent_type` 別 completion log の保持 + 起動間隔監視のみ強化 (current logic 維持 + 改良)
- **post-tool-use-failure.sh**: `error` 200 chars を `additionalContext` で親通知 (Plan 通り)
- **bats test**: subagent-stop は既存 test 維持、post-tool-use-failure 用に新規 test 1 件
