# 品質保証(Quality Assurance)

> **目的**: 間違いを防止し、成果物の品質を保証

---

## 🎯 品質保証の4原則

### 1. ゼロ欠陥(Zero Defects)

```
目標: 間違いゼロ

実現方法:
- 段階的検証
- 自己レビュー
- 自動チェック
```

### 2. 多層防御(Defense in Depth)

```
Layer 1: 作業中の自己チェック
Layer 2: 作業完了時の検証
Layer 3: 自動検証ツール
Layer 4: 最終確認

∀layer: エラー検出率 ≥ 90%
```

### 3. 早期検出(Early Detection)

```
エラーコスト ∝ 検出タイミングの遅さ

作業中検出: コスト = 1x
作業後検出: コスト = 10x
納品後検出: コスト = 100x

→ 作業中に検出・修正
```

### 4. 継続的改善(Continuous Improvement)

```
失敗 → 原因分析 → プロセス改善 → 再発防止
```

---

## 🔍 作業中チェック

### リアルタイム検証

```typescript
// 作業の各ステップで検証
interface WorkStep {
  action: string
  validation: () => boolean
  onError: () => void
}

const workflow: WorkStep[] = [
  {
    action: 'ファイル読み込み',
    validation: () => fileExists && fileReadable,
    onError: () => reportError('ファイル読み込みエラー')
  },
  {
    action: 'コード解析',
    validation: () => syntaxValid && semanticsValid,
    onError: () => reportError('解析エラー')
  },
  {
    action: 'コード編集',
    validation: () => changesValid && noSyntaxErrors,
    onError: () => reportError('編集エラー')
  }
]

// 各ステップで検証実行
function executeWorkflow(workflow: WorkStep[]): Result {
  for (const step of workflow) {
    if (!step.validation()) {
      step.onError()
      return { success: false, step: step.action }
    }
  }
  return { success: true }
}
```

### 自己質問リスト

作業中に自問自答:

```
□ 今やっていることは正しいか?
□ 見落としはないか?
□ エッジケースを考慮したか?
□ テストは通るか?
□ 型安全性は保たれているか?
□ セキュリティは大丈夫か?
□ パフォーマンスへの影響は?
□ 既存コードを壊していないか?
```

---

## ✅ 作業完了時チェックリスト

### コード品質

```
□ 型安全性
  - any/Any/interface{} を使用していない
  - 全ての型が明示的

□ テストカバレッジ
  - カバレッジ ≥ 80%
  - 全エッジケースをカバー

□ コード品質メトリクス
  - 関数サイズ ≤ 50行
  - 循環的複雑度 ≤ 10
  - 引数の数 ≤ 3個

□ 命名規則
  - 意図が明確な命名
  - マジックナンバー不使用

□ コメント
  - 複雑なロジックに説明
  - TODOの適切な使用
```

### 機能要件

```
□ 仕様通りに実装されているか?
□ 全ての要件を満たしているか?
□ エッジケースは考慮されているか?
□ エラーハンドリングは適切か?
□ ユーザー体験は良いか?
```

### 非機能要件

```
□ パフォーマンス
  - 応答時間 < 200ms(API)
  - N+1問題なし
  - メモリリークなし

□ セキュリティ
  - SQL Injection対策
  - XSS対策
  - CSRF対策
  - 認証・認可の実装

□ 可用性
  - エラー回復機能
  - ログ出力
  - モニタリング可能
```

### ドキュメント

```
□ README更新
□ API仕様書更新
□ コメント追加
□ 変更履歴記録
```

---

## 🤖 自動検証ルール

### 静的解析

```bash
# TypeScript
npm run type-check  # 型チェック
npm run lint        # リントチェック

# Go
go vet ./...        # 静的解析
golangci-lint run   # 包括的リント

# Python
mypy src/           # 型チェック
pylint src/         # リントチェック
```

### テスト実行

```typescript
interface TestResult {
  passed: number
  failed: number
  coverage: number
  duration: number
}

// テスト実行と検証
function runTests(): TestResult {
  const result = executeTests()

  // 品質基準チェック
  if (result.failed > 0) {
    throw new Error(`${result.failed}個のテストが失敗`)
  }

  if (result.coverage < 0.8) {
    throw new Error(`カバレッジ不足: ${result.coverage * 100}%`)
  }

  return result
}
```

### セキュリティスキャン

```bash
# 依存関係の脆弱性チェック
npm audit
pip-audit
go list -json -m all | nancy sleuth

# シークレット検出
git secrets --scan
trufflehog --regex --entropy=False .
```

---

## 🔄 レビュープロトコル

### セルフレビュー(必須)

作業完了後、自分でレビュー:

```markdown
## セルフレビューチェックリスト

### コード
□ ロジックは正しいか?
□ エッジケースを考慮したか?
□ エラーハンドリングは適切か?
□ コードは読みやすいか?
□ 重複コードはないか?

### テスト
□ 正常系テストあり
□ 異常系テストあり
□ 境界値テストあり
□ 全テストPass

### セキュリティ
□ 入力検証あり
□ SQL Injection対策あり
□ XSS対策あり
□ 認証・認可チェック済み

### パフォーマンス
□ N+1問題なし
□ 不要なループなし
□ キャッシュ活用
□ メモリリークなし

### ドキュメント
□ コメント追加
□ README更新
□ 変更理由記録
```

### ペアレビュー(推奨)

他のエージェントまたはQA Agentによるレビュー:

```
1. Developer Agent → QA Agent
2. QA Agentがコード品質チェック
3. 問題があれば Developer Agentに差し戻し
4. 問題なければ承認
```

---

## 🚨 エラーパターン検出

### よくある間違い

```typescript
// 間違いパターンのデータベース
interface ErrorPattern {
  pattern: RegExp
  description: string
  severity: 'high' | 'medium' | 'low'
  suggestion: string
}

const commonErrors: ErrorPattern[] = [
  {
    pattern: /:\s*any\b/,
    description: 'any型の使用',
    severity: 'high',
    suggestion: '具体的な型を指定してください'
  },
  {
    pattern: /==\s*null/,
    description: 'nullチェックに==使用',
    severity: 'medium',
    suggestion: '===を使用してください'
  },
  {
    pattern: /\.innerHTML\s*=/,
    description: 'XSS脆弱性の可能性',
    severity: 'high',
    suggestion: 'textContentを使用してください'
  },
  {
    pattern: /SELECT.*\$\{/,
    description: 'SQL Injection脆弱性',
    severity: 'high',
    suggestion: 'プレースホルダーを使用してください'
  }
]

// 自動スキャン
function scanForErrors(code: string): ErrorPattern[] {
  return commonErrors.filter(error => error.pattern.test(code))
}
```

### アンチパターン検出

```typescript
interface AntiPattern {
  name: string
  detector: (code: CodeAST) => boolean
  impact: string
  solution: string
}

const antiPatterns: AntiPattern[] = [
  {
    name: 'God Object',
    detector: (code) => classSize(code) > 500,
    impact: '保守性低下、テスト困難',
    solution: 'クラスを分割してください'
  },
  {
    name: 'Deep Nesting',
    detector: (code) => maxNestLevel(code) > 4,
    impact: '可読性低下、複雑度増加',
    solution: 'Early returnやGuard Clauseを使用'
  },
  {
    name: 'Magic Number',
    detector: (code) => hasMagicNumbers(code),
    impact: '意図不明、変更困難',
    solution: '定数として定義してください'
  }
]
```

---

## 📊 品質メトリクス

### 測定項目

```typescript
interface QualityMetrics {
  // コード品質
  typeStrength: number          // 型安全性 (0-1)
  testCoverage: number          // カバレッジ (0-1)
  complexity: number            // 複雑度 (1-10)
  duplication: number           // 重複率 (0-1)

  // バグ
  bugCount: number              // バグ数
  criticalBugCount: number      // 重大バグ数

  // パフォーマンス
  responseTime: number          // 応答時間 (ms)
  memoryUsage: number           // メモリ使用量 (MB)

  // セキュリティ
  vulnerabilityCount: number    // 脆弱性数
  securityScore: number         // セキュリティスコア (0-100)
}

// 品質基準
const QUALITY_STANDARDS: QualityMetrics = {
  typeStrength: 1.0,            // 100%型安全
  testCoverage: 0.8,            // 80%以上
  complexity: 10,               // 10以下
  duplication: 0.05,            // 5%以下

  bugCount: 0,                  // ゼロ
  criticalBugCount: 0,          // ゼロ

  responseTime: 200,            // 200ms以下
  memoryUsage: 512,             // 512MB以下

  vulnerabilityCount: 0,        // ゼロ
  securityScore: 90             // 90以上
}
```

### 品質ゲート

```typescript
function passQualityGate(metrics: QualityMetrics): boolean {
  const checks = [
    metrics.typeStrength >= QUALITY_STANDARDS.typeStrength,
    metrics.testCoverage >= QUALITY_STANDARDS.testCoverage,
    metrics.complexity <= QUALITY_STANDARDS.complexity,
    metrics.duplication <= QUALITY_STANDARDS.duplication,
    metrics.criticalBugCount === 0,
    metrics.vulnerabilityCount === 0
  ]

  return checks.every(check => check)
}
```

---

## 🎓 失敗から学ぶ

### 事後分析(Post-Mortem)

エラー発生時の分析プロセス:

```markdown
## 事後分析レポート

### 概要
- **日時**: [発生日時]
- **影響**: [影響範囲]
- **検出**: [検出方法]

### 根本原因
[5 Whys分析]
1. なぜエラーが発生したか?
2. なぜその状態になったか?
3. なぜ防げなかったか?
4. なぜチェックで見逃したか?
5. なぜプロセスが不十分だったか?

### 再発防止策
1. [即座の対策]
2. [短期的対策]
3. [長期的対策]

### プロセス改善
[今回の教訓を活かした改善]
```

### ナレッジベース構築

```typescript
interface LessonLearned {
  error: string                 // エラー内容
  rootCause: string             // 根本原因
  prevention: string            // 防止策
  detection: string             // 検出方法
  dateRecorded: Date
}

// エラーデータベースに記録
function recordLesson(lesson: LessonLearned): void {
  lessonsDB.add(lesson)

  // 類似エラーの自動検出に活用
  updateErrorDetectionRules(lesson)
}
```

---

## 📋 品質保証チェックリスト(最終確認)

```
作業完了前の最終確認:

□ セルフレビュー完了
□ 全テストPass
□ カバレッジ ≥ 80%
□ 型安全性100%
□ セキュリティチェック完了
□ パフォーマンス基準達成
□ ドキュメント更新
□ エラーパターン未検出
□ アンチパターン未検出
□ 品質メトリクス基準達成
□ 品質ゲートPass

全てチェックされるまで作業完了としない
```

---

**多層防御、継続的検証、失敗からの学習で高品質を保証**
