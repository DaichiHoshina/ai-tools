# 大規模作業ワークフロー(Large-Scale Workflow)

> **目的**: 大規模作業を効率的かつ確実に完遂

---

## 🎯 大規模作業の定義

```typescript
interface LargeScaleWork {
  files: number           // 影響ファイル数
  lines: number           // 変更行数
  duration: number        // 推定時間(分)
  subtasks: number        // サブタスク数
  agents: number          // 必要エージェント数
}

function isLargeScale(work: LargeScaleWork): boolean {
  return (
    work.files >= 10 ||      // 10ファイル以上
    work.lines >= 500 ||     // 500行以上
    work.duration >= 60 ||   // 60分以上
    work.subtasks >= 5       // 5サブタスク以上
  )
}
```

---

## 📋 Phase 0: 計画フェーズ(必須)

### 作業計画書作成

```markdown
# 作業計画書: [プロジェクト名]

## 1. 目的と範囲
- **目的**: [何を達成するか]
- **範囲**: [どこまでやるか]
- **制約**: [制約条件]

## 2. 影響分析
- **影響ファイル数**: XX個
- **推定変更行数**: XXX行
- **影響範囲**: [システムのどの部分]
- **リスク**: [潜在的リスク]

## 3. タスク分解
```
タスク1: [タスク名]
  - 担当: dev1
  - 推定時間: XX分
  - 依存: なし

タスク2: [タスク名]
  - 担当: dev2
  - 推定時間: XX分
  - 依存: タスク1
```

## 4. 並列実行計画
```
第1段階(並列):
├─ dev1: タスク1
├─ dev2: タスク2
└─ dev3: タスク3

第2段階(並列):
├─ dev1: タスク4
└─ dev2: タスク5
```

## 5. 品質基準
- テストカバレッジ: ≥ 80%
- 型安全性: 100%
- パフォーマンス: [基準]
- セキュリティ: [基準]

## 6. 検証計画
- [ ] ユニットテスト
- [ ] 統合テスト
- [ ] E2Eテスト
- [ ] パフォーマンステスト
- [ ] セキュリティテスト

## 7. ロールバック計画
[問題発生時の対処]
```

### リスク評価

```typescript
interface Risk {
  description: string
  probability: number      // 0-1
  impact: number          // 0-10
  mitigation: string
}

// リスク評価
function assessRisks(work: LargeScaleWork): Risk[] {
  const risks: Risk[] = []

  if (work.files > 50) {
    risks.push({
      description: '多数のファイル変更による影響範囲拡大',
      probability: 0.7,
      impact: 8,
      mitigation: '段階的実装、十分なテスト'
    })
  }

  if (work.subtasks > 10) {
    risks.push({
      description: 'タスク間の依存関係による遅延',
      probability: 0.5,
      impact: 6,
      mitigation: '並列実行の最大化、依存関係の最小化'
    })
  }

  return risks.sort((a, b) =>
    (b.probability * b.impact) - (a.probability * a.impact)
  )
}
```

---

## 📊 Phase 1: タスク分解フェーズ

### 自動タスク分解

```typescript
interface Task {
  id: string
  name: string
  description: string
  agent: string          // dev1-4
  estimatedLines: number
  estimatedTime: number  // 分
  dependencies: string[] // タスクID
  files: string[]
  priority: number       // 1-5
}

// タスク分解アルゴリズム
function decomposeWork(work: LargeScaleWork): Task[] {
  const tasks: Task[] = []

  // 機能単位で分解
  if (hasMultipleFeatures(work)) {
    tasks.push(...splitByFeature(work))
  }

  // レイヤー単位で分解
  if (hasMultipleLayers(work)) {
    tasks.push(...splitByLayer(work))
  }

  // ファイル単位で分解
  if (hasManyFiles(work)) {
    tasks.push(...splitByFile(work))
  }

  // タスクサイズを最適化
  return optimizeTaskSize(tasks)
}

// タスクサイズ最適化
function optimizeTaskSize(tasks: Task[]): Task[] {
  return tasks.flatMap(task => {
    // 大きすぎるタスクは分割
    if (task.estimatedLines > 200) {
      return splitTask(task)
    }

    // 小さすぎるタスクは統合候補
    if (task.estimatedLines < 20) {
      return [{ ...task, mergeable: true }]
    }

    return [task]
  })
}
```

### 優先度付け

```typescript
// 優先度計算
function calculatePriority(task: Task): number {
  let priority = 0

  // クリティカルパス上のタスクは高優先度
  if (isOnCriticalPath(task)) priority += 5

  // 他のタスクに依存されるタスクは高優先度
  priority += countDependents(task) * 2

  // 複雑度が高いタスクは早めに着手
  if (task.estimatedLines > 150) priority += 3

  return Math.min(priority, 10)
}
```

---

## 🚀 Phase 2: 実行フェーズ

### 並列実行戦略

```typescript
// 並列実行グループ作成
function createExecutionPlan(tasks: Task[]): Task[][] {
  // 依存関係グラフを構築
  const graph = buildDependencyGraph(tasks)

  // トポロジカルソートでレベル分け
  const levels = topologicalSort(graph)

  // 各レベル内で優先度順にソート
  return levels.map(level =>
    level.sort((a, b) => b.priority - a.priority)
  )
}

// 実行
async function executePlan(plan: Task[][]): Promise<void> {
  for (let i = 0; i < plan.length; i++) {
    const level = plan[i]

    console.log(`\n=== 第${i + 1}段階 (${level.length}並列) ===`)

    // 並列実行
    const results = await Promise.all(
      level.map(task => executeTask(task))
    )

    // 全タスクが成功するまで次に進まない
    if (results.some(r => !r.success)) {
      throw new Error(`第${i + 1}段階で失敗`)
    }
  }
}
```

### チェックポイント(必須)

```typescript
interface Checkpoint {
  phase: string
  checks: Check[]
  passed: boolean
}

interface Check {
  name: string
  validator: () => boolean
  errorMessage: string
}

// チェックポイント定義
const checkpoints: Checkpoint[] = [
  {
    phase: 'タスク25%完了',
    checks: [
      {
        name: 'テスト実行',
        validator: () => allTestsPass(),
        errorMessage: 'テストが失敗しています'
      },
      {
        name: '型チェック',
        validator: () => noTypeErrors(),
        errorMessage: '型エラーがあります'
      }
    ],
    passed: false
  },
  {
    phase: 'タスク50%完了',
    checks: [
      {
        name: 'カバレッジ確認',
        validator: () => coverage() >= 0.7,
        errorMessage: 'カバレッジが70%未満です'
      },
      {
        name: '統合テスト',
        validator: () => integrationTestsPass(),
        errorMessage: '統合テストが失敗しています'
      }
    ],
    passed: false
  },
  {
    phase: 'タスク75%完了',
    checks: [
      {
        name: 'パフォーマンステスト',
        validator: () => performanceOK(),
        errorMessage: 'パフォーマンス基準を満たしていません'
      },
      {
        name: 'セキュリティスキャン',
        validator: () => noVulnerabilities(),
        errorMessage: '脆弱性が検出されました'
      }
    ],
    passed: false
  }
]

// チェックポイント実行
function runCheckpoint(checkpoint: Checkpoint): boolean {
  console.log(`\n🔍 チェックポイント: ${checkpoint.phase}`)

  for (const check of checkpoint.checks) {
    if (!check.validator()) {
      console.error(`❌ ${check.name}: ${check.errorMessage}`)
      return false
    }
    console.log(`✅ ${check.name}: OK`)
  }

  checkpoint.passed = true
  return true
}
```

### 進捗追跡

```typescript
interface Progress {
  totalTasks: number
  completedTasks: number
  inProgressTasks: number
  blockedTasks: number
  percentage: number
  estimatedTimeRemaining: number  // 分
}

// 進捗計算
function calculateProgress(tasks: Task[]): Progress {
  const total = tasks.length
  const completed = tasks.filter(t => t.status === 'completed').length
  const inProgress = tasks.filter(t => t.status === 'in_progress').length
  const blocked = tasks.filter(t => t.status === 'blocked').length

  const remainingTasks = tasks.filter(t => t.status !== 'completed')
  const estimatedTime = remainingTasks.reduce(
    (sum, t) => sum + t.estimatedTime,
    0
  )

  return {
    totalTasks: total,
    completedTasks: completed,
    inProgressTasks: inProgress,
    blockedTasks: blocked,
    percentage: (completed / total) * 100,
    estimatedTimeRemaining: estimatedTime
  }
}

// 進捗レポート
function reportProgress(progress: Progress): void {
  console.log(`
📊 進捗レポート
━━━━━━━━━━━━━━━━━━━━━━━━
完了: ${progress.completedTasks}/${progress.totalTasks} (${progress.percentage.toFixed(1)}%)
進行中: ${progress.inProgressTasks}
ブロック: ${progress.blockedTasks}
残り時間: 約${progress.estimatedTimeRemaining}分
━━━━━━━━━━━━━━━━━━━━━━━━
  `)
}
```

---

## 🔄 Phase 3: 統合フェーズ

### 統合テスト

```typescript
interface IntegrationTest {
  name: string
  components: string[]
  testCases: TestCase[]
  passed: boolean
}

// 統合テスト実行
async function runIntegrationTests(
  tests: IntegrationTest[]
): Promise<TestResult> {
  const results: TestResult[] = []

  for (const test of tests) {
    console.log(`\n🧪 統合テスト: ${test.name}`)

    for (const testCase of test.testCases) {
      const result = await executeTestCase(testCase)
      results.push(result)

      if (!result.passed) {
        console.error(`❌ ${testCase.name}: ${result.error}`)
      } else {
        console.log(`✅ ${testCase.name}`)
      }
    }
  }

  const allPassed = results.every(r => r.passed)
  return {
    total: results.length,
    passed: results.filter(r => r.passed).length,
    failed: results.filter(r => !r.passed).length,
    allPassed
  }
}
```

### コンフリクト解決

```typescript
interface Conflict {
  file: string
  tasks: string[]        // 競合するタスク
  resolution: string
}

// コンフリクト検出
function detectConflicts(tasks: Task[]): Conflict[] {
  const fileMap = new Map<string, string[]>()

  // 各タスクが触るファイルを記録
  for (const task of tasks) {
    for (const file of task.files) {
      if (!fileMap.has(file)) {
        fileMap.set(file, [])
      }
      fileMap.get(file)!.push(task.id)
    }
  }

  // 複数タスクが同じファイルを変更する場合は競合
  const conflicts: Conflict[] = []
  for (const [file, taskIds] of fileMap) {
    if (taskIds.length > 1) {
      conflicts.push({
        file,
        tasks: taskIds,
        resolution: '順次実行に変更'
      })
    }
  }

  return conflicts
}
```

---

## ✅ Phase 4: 検証フェーズ

### 包括的検証

```typescript
interface Verification {
  functional: boolean      // 機能要件
  performance: boolean     // パフォーマンス
  security: boolean        // セキュリティ
  quality: boolean         // コード品質
  documentation: boolean   // ドキュメント
}

// 全項目検証
async function comprehensiveVerification(): Promise<Verification> {
  return {
    functional: await verifyFunctionalRequirements(),
    performance: await verifyPerformance(),
    security: await verifySecurity(),
    quality: await verifyCodeQuality(),
    documentation: await verifyDocumentation()
  }
}

// 検証結果チェック
function allVerificationsPassed(v: Verification): boolean {
  return Object.values(v).every(check => check === true)
}
```

### 最終チェックリスト

```
□ 全タスク完了
□ 全テストPass
□ カバレッジ ≥ 80%
□ 型安全性100%
□ セキュリティチェック完了
□ パフォーマンステスト完了
□ 統合テスト完了
□ E2Eテスト完了
□ ドキュメント更新完了
□ チェックポイント全Pass
□ コンフリクト解決済み
□ ロールバック計画準備済み
```

---

## 📈 Phase 5: 完了レポート

```markdown
# 完了レポート: [プロジェクト名]

## 概要
- **開始日時**: [日時]
- **完了日時**: [日時]
- **実作業時間**: XX分

## タスク実行結果
- **総タスク数**: XX
- **完了タスク**: XX
- **並列実行段階数**: XX
- **平均並列度**: X.X
- **理論高速化率**: X.Xx

## 品質メトリクス
- **テストカバレッジ**: XX%
- **型安全性**: 100%
- **バグ数**: 0
- **脆弱性数**: 0

## パフォーマンス
- **応答時間**: XXms
- **メモリ使用量**: XXMB

## 課題と学び
- [発生した課題1]
- [発生した課題2]
- [学んだこと]

## 改善提案
- [次回への改善案1]
- [次回への改善案2]
```

---

**計画、分解、実行、統合、検証の5フェーズで大規模作業を確実に完遂**
