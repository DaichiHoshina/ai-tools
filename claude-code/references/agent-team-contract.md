# Agent Team Contract

`/flow` Team path (PO → Manager → Developer×N → Reviewer) で agent 間 interface を canonical 定義する。各 agent file はこの contract を参照、独自定義禁止。

## 共通用語

- **parent**: Claude Code 本体 (Opus)。subagent spawn は parent のみ実行可
- **field 名**: snake_case 統一
- **path**: 絶対 path 必須 (`~` 不可、`$HOME` 展開済み)

## Interface schema

### 1. PO → parent (decision)

PO は parent に decision を返す。Markdown でなく **field 構造化** で返す。

```yaml
execution_mode: team  # /flow 経由は team 固定、PO 判断対象外。direct は legacy schema のみ (未使用)
decision_reason: "<1 行>"
worktree:
  path: <absolute path>
  branch: <branch name>
  base_branch: <main | etc>
reviewer_qa_criteria:
  p0: [type-safety, security, data-integrity]  # 配列
  p1: [performance, test-coverage]
  refix_loop_limit: 1
manager_instruction:
  goal: "<1 行>"
  constraints: ["<制約 1>", "<制約 2>"]
  priority: ["<top task>", "<next>"]
```

### 2. parent → Manager (input)

parent は PO decision の `manager_instruction` + `worktree` + `reviewer_qa_criteria` をそのまま Manager prompt に埋め込む。

### 3. Manager → parent (allocation)

Manager は parent に allocation を返す。**Markdown でなく field 構造化**。

```yaml
execution_mode: parallel  # parallel | staged | sequential
parallelism: 4  # N
worktree_required: true
impl_notes:
  dir: <absolute path>  # ~/.claude/plans/impl-notes/YYYY-MM-DD_HHMMSS_<feature-slug>/
tasks:
  - developer_id: dev1
    task:
      id: task-001
      title: "<1 行>"
      description: "<3 行以内>"
      files: ["<path>"]
      dependencies: []
    verify:  # NEW: parent が subagent prompt に埋め込み必須
      lint: "<lint cmd>"
      typecheck: "<typecheck cmd>"
      test: "<test cmd>"
    dod: "<1 行 success criteria>"  # NEW: 必須
  - developer_id: dev2
    ...
stages:  # staged execution の場合のみ
  - stage: 1
    devs: [dev1, dev2]
  - stage: 2
    devs: [dev3]
```

### 4. parent → Developer (context)

parent は Manager allocation 1 task 分を Developer prompt に埋め込み、**1 message 内 N tool_use** で並列発火。

```json
{
  "developer_id": "dev1",
  "worktree": {
    "path": "<absolute path>",
    "branch": "<branch name>",
    "base_branch": "main"
  },
  "task": {
    "id": "task-001",
    "title": "<1 行>",
    "description": "<3 行以内>",
    "files": ["<path>"],
    "dependencies": []
  },
  "verify": {
    "lint": "<cmd>",
    "typecheck": "<cmd>",
    "test": "<cmd>"
  },
  "dod": "<1 行>",
  "constraints": {
    "timeout_minutes": 30,
    "max_retries": 2
  },
  "impl_notes": {
    "dir": "<absolute path>"
  }
}
```

### 5. Developer → parent (completion report)

300 words 以内、checkbox は `✓` (完了) / `✗` (失敗) / `—` (N/A) 統一 (`[ ]` 禁止)。

```yaml
status: success  # success | partial | failure | dep_unresolved
task_id: task-001
changed_files:
  - path: <path>
    change: "<add | modify | delete>"
verification:
  lint: ✓
  typecheck: ✓
  test: ✓
impl_notes_path: <absolute path>  # Team flow のみ、それ以外 omit
```

失敗時は `remaining` + `manager_decision_required` field 追加。

### 6. parent → Reviewer (input)

```yaml
diff_target: <git diff command or file paths>
change_summary: "<Manager integration result の要約、1 段落>"
po_qa_criteria:
  p0: [...]
  p1: [...]
merged_md_path: <absolute path>  # Team flow のみ
review_mode: default  # default | codex | adversarial | deep
is_reverify: false  # boolean (旧 "re-verify or first-time flag" を明示)
```

### 7. Reviewer → parent (review result)

P0/P1/P2/P3 集計、format は `agents/reviewer-agent.md` Output template に準拠 (この contract では schema のみ規定)。

```yaml
p0:
  - viewpoint: type-safety
    location: <file:line>
    issue: "<1 行>"
    fix: "<提案>"
p1: [...]
p2: [...]
codex_available: true  # false なら fallback で WARN line 同伴
```

## Field name 統一

| 旧表記 | canonical |
|--------|-----------|
| `Reviewer QA criteria` / `Reviewer criteria` | `reviewer_qa_criteria` |
| `Worktree info` / `Worktree path` / `worktree.path` | `worktree.path` (JSON / YAML 構造) |
| `IMPL_NOTES dir` / `impl_notes.dir` | `impl_notes.dir` |
| `re-verify flag` / `re-verify or first-time flag` | `is_reverify` (boolean) |

## Markdown 出力との関係

各 agent file の Markdown 出力 template (PO Return format / Manager Allocation plan format / Dev Completion report / Reviewer Output template) は **human readable form**。Contract の YAML/JSON は **machine readable schema**。両者は等価で、parent は YAML を内部 state として保持し、必要時に Markdown 化する。

## 改訂時の手順

1. この file (`agent-team-contract.md`) を先に編集
2. 各 agent file の該当 section を contract に合わせる
3. `/flow` で smoke test (PO → Manager → Dev×1 で 1 task 流す)
