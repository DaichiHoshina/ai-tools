---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TodoWrite, Task, AskUserQuestion, mcp__serena__check_onboarding_performed, mcp__serena__delete_memory, mcp__serena__find_file, mcp__serena__find_referencing_symbols, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__insert_after_symbol, mcp__serena__insert_before_symbol, mcp__serena__list_dir, mcp__serena__list_memories, mcp__serena__onboarding, mcp__serena__read_memory, mcp__serena__remove_project, mcp__serena__replace_regex, mcp__serena__replace_symbol_body, mcp__serena__restart_language_server, mcp__serena__search_for_pattern, mcp__serena__switch_modes, mcp__serena__think_about_collected_information, mcp__serena__think_about_task_adherence, mcp__serena__think_about_whether_you_are_done, mcp__serena__write_memory, mcp__context7__resolve-library-id, mcp__context7__get-library-docs
description: 実装用コマンド - Agent階層で実行（複雑なタスク）または直接実行（単純なタスク）
---

## /dev - 実装モード

## 思考モード（重要）

**always ultrathink** - 複雑な実装では必ず深く思考してから実行。安易な実装を避け、設計意図を理解した上でコードを書く。

## Step 0: ガイドライン自動読み込み（必須）

実装開始前に `load-guidelines` スキルを実行:

```
/load-guidelines

→ プロジェクト技術スタック自動検出
→ 必要なガイドラインのみ読み込み（トークン節約）
```

**検出例:**
- TypeScript → `typescript.md`, `eslint.md`
- Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md`
- Go → `golang.md`

**読み込み結果:**
`guidelines(ts,react,tailwind,shadcn,eslint)` をステータスラインに表示

**Skill連携:**
選択されたSkillの `requires-guidelines` に基づき未読ガイドラインを自動読み込み

## Agent 使用判断（重要）

### Agent 階層を使用（PO → Manager → Developer）

- 新機能実装
- 複数ファイルの修正
- リファクタリング
- テスト実装
- 複雑な調査・分析

### 直接実行（Agent なし）

- 1-2ファイルの単純な修正
- 1行程度の変更
- 単純な質問への回答

## Agent 階層フロー

```
1. PO Agent 起動（Task tool, subagent_type: "po-agent"）
   - 戦略決定
   - Worktree 要否判断（ユーザー確認）
   ↓
2. Manager Agent 起動（Task tool, subagent_type: "manager-agent"）
   - タスク分割
   - 依存関係分析
   - Developer 配分計画
   ↓
3. Developer Agents 並列起動（Task tool, subagent_type: "developer-agent"）
   - dev1-4 を並列で起動（重要：1メッセージで複数Task）
   - 実装実行
```

## Developer 並列起動手順（Claude Code実行）

Manager Agent完了後、以下の手順でDeveloperを並列起動:

1. **配分計画の確認**
   - Manager Agentの「実行指示」セクションを確認
   - 各Developerのタスク詳細とWorktree情報を把握

2. **並列起動（重要：1メッセージで全Task呼び出し）**
   - 指定されたDeveloper数だけTask toolを同時呼び出し
   - 各Task toolのパラメータ:
     - `subagent_type`: "developer-agent"
     - `prompt`: Developer ID（dev1-4）+ タスク詳細 + Worktree情報

3. **完了待機**
   - 全Developerの完了を待機
   - エラー発生時は該当Developerのログを確認

4. **結果集約**
   - 全Developerの成果物を確認
   - 統合テスト実施（必要に応じて）
   - ユーザーに完了報告

## 直接実行フロー

1. ガイドライン読込
2. Serena MCP でコード分析
3. TodoWrite で計画
4. ユーザー確認
5. 実装
6. lint/test 実行

## 優先順位

1. **型安全性** - any/as 禁止
2. **ガイドライン準拠**
3. **アーキテクチャパターン**
4. **テスタビリティ**

## 実装後の自動品質チェック（必須）

実装完了後、以下を自動実行:

```bash
# 言語別の静的解析
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...

# Python
ruff check . && mypy .
```

**チェック結果の対応:**
- エラー 0件 → ユーザーに完了報告
- エラーあり → 自動修正を試行、修正不可なら報告

## 次のアクション

- 成功 → `/test` or `/review`
- エラー → `/debug`

**実装前はユーザー確認必須。Serena MCP でコード操作。**
