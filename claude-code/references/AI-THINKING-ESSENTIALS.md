# AI 思考法のエッセンス

Claude 等の AI エージェントが従うべき思考法の核心。

## 3つの核心コンセプト

### 1. 操作ガード（3層分類）

すべての操作を安全性で分類: `Guard : Action → {Allow, AskUser, Deny}`

| 層 | 処理 | 例 |
|----|------|-----|
| **安全操作** | 即実行 | ファイル読取、git status、分析、提案 |
| **要確認操作** | 確認後実行 | git commit/push、ファイル編集/削除、設定変更 |
| **禁止操作** | 実行不可 | rm -rf /、secrets 漏洩、git push --force、YAGNI 違反 |

確認フロー: 検出 → afplay（通知音）→ 承認待ち → 実行 or キャンセル。

### 2. 複雑度判定

`ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}`

| 条件 | 判定 | アクション |
|------|------|----------|
| ファイル数<5 AND 行数<300 | Simple | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 OR 行数≥300 | TaskDecomposition | Tasks + 5 フェーズ |
| 複数プロジェクト横断 OR 戦略判断 | AgentHierarchy | PO/Manager/Developer 階層 |

Tasks 連携: TaskCreate/TaskUpdate/TaskList/TaskGet。`addBlockedBy`/`addBlocks` で順序管理。`CLAUDE_CODE_TASK_LIST_ID` でセッション間共有可。詳細は `commands/flow.md`。

### 3. 5フェーズワークフロー（実行強制版）

TaskDecomposition 判定時の必須プロセス。

| Phase | 目的 | 不変条件 |
|-------|------|---------|
| 0. 要求分析 | 作業漏れ防止 | 必須要件に説明・受入条件あり |
| 1. タスク分解 | カバレッジ保証 | カバレッジ = 100% |
| 2. ファイル作成 | トレーサビリティ | 完全 |
| 3. 依存整理 | 並列実行計画 | 循環依存なし |
| 4. Agent 起動 | 並列実行 | 全タスク成功 |
| 5. 統合検証 | 完全性 | 未実装要件 = ∅ |

実行ガード: 各 Phase 完了時に InvariantCheck、違反あり → 強制停止 + 自動修正 or 質問。

## AI 運用 5 原則

1. **複雑度判定**: タスク受領 → Simple/TaskDecomposition/AgentHierarchy → 適切なファイル選択
2. **完了モナド**: `complete(task) = (afplay 通知, serena.write_memory(result))`
3. **確認通知**: `confirm(boundary) = (afplay 確認音, wait_user_approval())`
4. **行動規範**: clean → careful → cooperative
5. **応答フォーマット**: ユーザー入力引用 → 実行モード明示 → 可換図式（現在地 → 次ステップ）

## ガードレール詳細

### 禁止操作（絶対）

- システム破壊: `rm -rf /`, `shutdown -h now`, `mkfs.*`
- セキュリティ: `chmod 777 -R /`, secrets / .env のコミットや push、ユーザー入力の任意コード評価
- Git 危険: `git push --force` / `git reset --hard` リモート / `git clean -fdx`（許可なし）
- YAGNI 違反: 未使用コード生成、「念のため」「将来使うかも」の実装

### 要確認操作の確認フロー

1. explain_impact（影響説明）
2. afplay 確認音
3. wait_user_approval()
4. approved → execute / else cancel
5. log(action, result)

## 実践チェックリスト

**タスク受領時**
- [ ] 複雑度判定（Simple/TaskDecomposition/AgentHierarchy）
- [ ] 必要ファイル読込

**操作実行前**
- [ ] 操作ガードで分類
- [ ] 要確認 → 確認音 + 承認待ち
- [ ] 禁止 → 即拒否 + 理由説明

**TaskDecomposition 時**
- [ ] 各 Phase の不変条件を満たしているか確認

**完了時**
- [ ] 完了モナド実行（通知音 + memory 保存）
- [ ] 全必須要件の達成確認

## 安全性定理

- **定理1**: 安全操作は常に安全 — `∀f ∈ Mor(安全操作), ¬causes_harm(f)`
- **定理2**: 要確認操作はユーザー承認で安全 — `user_approval(f) ⟹ ¬causes_harm(f)`
- **定理3**: 禁止操作は実行不可 — `f ∉ Mor(Claude圏) ⟹ ¬executable(f)`
- **完全性**: 各 Phase で不変条件チェック ∧ 違反時強制停止 ⟹ 作業漏れゼロ ∧ 品質保証

## まとめ: 最重要 3 ルール

1. **操作ガード**: 全操作を安全/要確認/禁止に分類
2. **ComplexityCheck**: Simple/TaskDecomposition/AgentHierarchy で手法選択
3. **実行強制**: 各 Phase 完了時に不変条件チェック、違反時強制停止

```
タスク受領 → 複雑度判定
  ├─ Simple → 直接実装（操作ガード適用）
  ├─ TaskDecomposition → 5 フェーズワークフロー
  └─ AgentHierarchy → PO/Manager/Developer 階層

各操作前 → 操作ガード
  ├─ 安全 → 即実行
  ├─ 要確認 → 確認音 + 承認 + 実行
  └─ 禁止 → 拒否 + 理由説明

完了時 → complete(task) → 通知音 + memory 保存
```
