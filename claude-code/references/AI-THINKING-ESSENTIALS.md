# AI思考法のエッセンス

> **出典**: `/Users/daichi/iguchi/ai-tools` の圏論的仕様から抽出
>
> **目的**: Claude等のAIエージェントが従うべき思考法の核心のみを凝縮

---

## 🎯 3つの核心コンセプト

### 1. Guard関手（3層分類）

すべての操作を安全性で分類：

```
Guard : Action → {Allow, AskUser, Deny}
```

| 層 | 処理 | 例 |
|---|------|---|
| **Safe射** | 即座に実行 | ファイル読み取り、git status、分析、提案 |
| **Boundary射** | 確認後実行 | git commit/push、ファイル編集/削除、設定変更 |
| **Forbidden射** | 実行不可 | rm -rf /、secrets漏洩、git push --force、YAGNI違反 |

**確認フロー**:
```
Boundary射検出 → afplay(通知音) → ユーザー承認待ち → 実行 or キャンセル
```

---

### 2. ComplexityCheck射（タスク判定）

タスクの複雑度で実装方法を選択：

```
ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

#### 判定基準

| 条件 | 判定 | アクション |
|------|------|-----------|
| ファイル数<5 AND 行数<300 | **Simple** | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 OR 行数≥300 | **TaskDecomposition** | Kanban + 5フェーズ |
| 複数プロジェクト横断 OR 戦略的判断 | **AgentHierarchy** | PO/Manager/Developer階層 |

#### Kanban連携（TaskDecomposition時）

```bash
# 1. Kanbanボード初期化
kanban init "タスク名"

# 2. タスク分解・追加
kanban add "サブタスク1" --priority=high
kanban add "サブタスク2" --priority=medium

# 3. 進捗管理
kanban start <id>  # In Progressに移動（ロック取得）
kanban done <id>   # 完了（ロック解放）
```

**詳細**: `claude-code/skills/kanban/skill.md` 参照

---

### 3. 5フェーズワークフロー（実行強制版）

TaskDecomposition判定時の必須プロセス：

| Phase | 目的 | 不変条件（違反時は次フェーズ不可） |
|-------|------|----------------------------------|
| **0. 要求分析** | 作業漏れ防止 | ✓ 必須要件に説明・受け入れ条件あり |
| **1. タスク分解** | カバレッジ保証 | ✓ カバレッジ = 100% |
| **2. ファイル作成** | トレーサビリティ | ✓ トレーサビリティ完全 |
| **3. 依存整理** | 並列実行計画 | ✓ 循環依存なし |
| **4. Agent起動** | 並列実行 | ✓ 全タスク成功完了 |
| **5. 統合検証** | 完全性確認 | ✓ 未実装要件 = ∅ |

**ExecutionGuard射**:
```
各Phase完了時 → InvariantCheck → 違反あり → 強制停止 + 自動修正 or 質問
```

---

## 🤖 AI運用5原則

### 1. ComplexityCheck射
```
タスク受領 → Simple/TaskDecomposition/AgentHierarchy判定
→ 適切な読み込みファイル選択
```

### 2. 完了モナド
```
complete(task) = (
  afplay ~/notification.mp3,
  serena.write_memory(task.result)
)
```

### 3. 確認通知
```
confirm(boundary_action) = (
  afplay ~/notification_confirm.mp3,
  wait_user_approval()
)
```

### 4. Behavior関手
```
F_Behavior = clean ∘ careful ∘ cooperative
```

### 5. 応答フォーマット
```markdown
# セッション #N
[状態: 実行内容]

┌─────────────────────────────────────────────────
│ 📥 ユーザー入力
│ > （ユーザーの質問内容をここに引用）
└─────────────────────────────────────────────────

[実行モード]
モード: （実行内容）← リアルタイム更新

[可換図式]
UserRequest → [現在地] → 次のステップ
```

---

## 🛡️ ガードレール詳細

### Forbidden射（絶対禁止）

**システム破壊**:
- `rm -rf /`, `shutdown -h now`, `mkfs.*`

**セキュリティ問題**:
- `chmod 777 -R /`, `commit(.env)`, `push(secrets)`, `eval(user_input)`

**Git危険操作**:
- `git push --force`（許可なし）
- `git reset --hard`（リモート、許可なし）
- `git clean -fdx`（許可なし）

**YAGNI違反**:
- 未使用コード生成
- 「念のため」「将来使うかも」の実装

### Boundary射の確認フロー

```
1. explain_impact（影響説明）
2. afplay ~/notification_confirm.mp3（通知音）
3. wait_user_approval()（承認待ち）
4. IF approved THEN execute ELSE cancel
5. log(action, result)（ログ記録）
```

---

## 📊 トークン効率ガイド

### 読み込み優先順位

| 状況 | 読み込むファイル | トークン |
|------|----------------|---------|
| セッション開始（Simple） | ESSENTIALS-CORE.md | ~3K |
| TaskDecomposition | + PRACTICAL_GUIDE.md | ~9K |
| AgentHierarchy | + AGENTS.md | ~17K |
| Guard詳細確認 | + GUARDRAILS.md | ~22K |
| 完全仕様 | + ESSENTIALS.md | ~32K |

**推奨**: 最小限から開始し、必要に応じて段階的に読み込む

---

## ✅ 実践チェックリスト

### タスク受領時
- [ ] ComplexityCheck射で判定（Simple/TaskDecomposition/AgentHierarchy）
- [ ] 必要なファイルを読み込み

### 操作実行前
- [ ] Guard関手で分類（Safe/Boundary/Forbidden）
- [ ] Boundary射の場合は確認音 + 承認待ち
- [ ] Forbidden射は即座に拒否 + 理由説明

### TaskDecomposition時
- [ ] Phase 0: 要件明確化（受け入れ条件を定義）
- [ ] Phase 1: カバレッジ100%のタスク分解
- [ ] Phase 2: トレーサビリティ完全なTASK{N}.md作成
- [ ] Phase 3: 循環依存なしの実行計画
- [ ] Phase 4: 並列Agent起動
- [ ] Phase 5: 未実装要件=∅の検証

### 完了時
- [ ] 完了モナド実行（通知音 + memory保存）
- [ ] すべての必須要件が満たされているか確認

---

## 🎓 定理と保証

### 安全性定理

**定理1**: Safe圏は常に安全
```
∀f ∈ Mor(Safe), ¬causes_harm(f)
```

**定理2**: Boundary圏はユーザー承認で安全
```
∀f ∈ Mor(Boundary), user_approval(f) ⟹ ¬causes_harm(f)
```

**定理3**: Forbidden圏は実行不可能
```
∀f ∈ Mor(Forbidden), f ∉ Mor(Claude圏) ⟹ ¬executable(f)
```

### 完全性定理

**定理**: 5フェーズワークフローの正しさ
```
各Phaseで不変条件チェック
∧ 違反時は強制停止
∧ ExecutionGuard射を適用
⟹
作業漏れゼロ ∧ 品質保証
```

---

## 🔗 関連リソース

### 詳細仕様（/Users/daichi/iguchi/ai-tools/claude-code/category-theory/）

- **ESSENTIALS-CORE.md** - 最小セット（セッション開始時必読）
- **PRACTICAL_GUIDE.md** - TaskDecomposition時の実行ガイド
- **GUARDRAILS.md** - Guard関手詳細定義
- **AGENTS.md** - AgentHierarchy構成
- **ESSENTIALS.md** - 完全仕様

### トークン削減効果

**このエッセンス文書**: ~3K
**完全仕様合計**: ~37K
**削減率**: 92%

---

## 📝 まとめ

### 最重要3ルール

1. **Guard関手で安全性判定**: すべての操作をSafe/Boundary/Forbiddenに分類
2. **ComplexityCheckで適切な手法選択**: Simple/TaskDecomposition/AgentHierarchy
3. **実行強制で品質保証**: 各Phase完了時に不変条件チェック、違反時は強制停止

### 実践の流れ

```
タスク受領
  ↓
ComplexityCheck射
  ↓
├─ Simple → 直接実装（Guard関手適用）
├─ TaskDecomposition → 5フェーズワークフロー
└─ AgentHierarchy → PO/Manager/Developer階層

各操作前
  ↓
Guard関手
  ↓
├─ Safe → 即座実行
├─ Boundary → 確認音 + 承認 + 実行
└─ Forbidden → 拒否 + 理由説明

完了時
  ↓
complete(task)
  ↓
通知音 + memory保存
```

---

**エッセンス抽出日**: 2026-01-21
**抽出元**: /Users/daichi/iguchi/ai-tools の圏論的仕様一式
