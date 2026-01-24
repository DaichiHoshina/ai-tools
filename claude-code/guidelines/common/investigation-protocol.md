# 調査プロトコル(Investigation Protocol)

> **目的**: 調査精度を最大化し、見落としを防止

---

## 🎯 調査の3原則

### 1. 段階的深掘り(Progressive Deep Dive)

```
Level 1: 概要把握(1-2分)
  ↓
Level 2: 詳細調査(5-10分)
  ↓
Level 3: 徹底分析(必要に応じて)
```

### 2. 複数ソース確認(Multi-Source Verification)

```
∀finding ∈ Investigation:
  sources(finding) ≥ 2

1つのソースで結論を出さない
```

### 3. 仮説検証サイクル(Hypothesis Testing)

```
仮説構築 → 証拠収集 → 検証 → 結論
        ↑__________________|
        仮説が間違っていたら再構築
```

---

## 📋 調査フェーズ

### Phase 1: 情報収集(Information Gathering)

#### 必須ステップ

```typescript
interface InvestigationPlan {
  objective: string          // 調査目的
  scope: string[]           // 調査範囲
  tools: string[]           // 使用ツール
  timeEstimate: number      // 推定時間(分)
}

// 調査開始前に計画を立てる
function planInvestigation(request: string): InvestigationPlan {
  return {
    objective: extractObjective(request),
    scope: defineScope(request),
    tools: selectTools(request),
    timeEstimate: estimateTime(request)
  }
}
```

#### Serena MCP活用(優先順位)

```
1. get_symbols_overview
   → ファイルの構造を素早く把握

2. find_symbol
   → 特定のシンボルを検索

3. find_referencing_symbols
   → 使用箇所を特定

4. search_for_pattern
   → パターンマッチング

5. 標準ツール(Read, Grep, Glob)
   → Serenaで不十分な場合のみ
```

#### 調査範囲の明確化

```typescript
interface Scope {
  files: string[]           // 対象ファイル
  directories: string[]     // 対象ディレクトリ
  symbols: string[]         // 対象シンボル
  exclusions: string[]      // 除外対象
}

// 範囲が広すぎる場合は警告
function validateScope(scope: Scope): ValidationResult {
  if (scope.files.length > 50) {
    return {
      valid: false,
      message: '範囲が広すぎます。絞り込んでください'
    }
  }
  return { valid: true }
}
```

### Phase 2: 分析(Analysis)

#### パターン検出

```typescript
interface Pattern {
  type: string              // パターン種別
  occurrences: number       // 出現回数
  locations: Location[]     // 出現箇所
  confidence: number        // 確信度(0-1)
}

// パターンを検出して分析
function analyzePatterns(data: CodeData): Pattern[] {
  const patterns = detectPatterns(data)

  // 確信度が低いパターンは報告に含めない
  return patterns.filter(p => p.confidence >= 0.8)
}
```

#### 依存関係の追跡

```typescript
interface Dependency {
  from: string              // 依存元
  to: string                // 依存先
  type: 'import' | 'call' | 'inherit'
  critical: boolean         // 重要度
}

// 依存関係を可視化
function visualizeDependencies(deps: Dependency[]): string {
  // グラフ構造で表現
  return buildDependencyGraph(deps)
}
```

#### 矛盾の検出

```typescript
interface Contradiction {
  source1: Finding
  source2: Finding
  description: string
}

// 矛盾を自動検出
function detectContradictions(findings: Finding[]): Contradiction[] {
  const contradictions: Contradiction[] = []

  for (let i = 0; i < findings.length; i++) {
    for (let j = i + 1; j < findings.length; j++) {
      if (contradict(findings[i], findings[j])) {
        contradictions.push({
          source1: findings[i],
          source2: findings[j],
          description: explainContradiction(findings[i], findings[j])
        })
      }
    }
  }

  return contradictions
}
```

### Phase 3: 検証(Verification)

#### ダブルチェック(必須)

```
∀finding ∈ CriticalFindings:
  verify(finding) = true

検証方法:
1. 別の方法で同じ結論に到達できるか?
2. 反例はないか?
3. エッジケースを考慮したか?
```

#### クロスリファレンス

```typescript
interface CrossReference {
  finding: Finding
  confirmingSources: Source[]
  conflictingSources: Source[]
}

// 複数ソースでクロスチェック
function crossReference(finding: Finding): CrossReference {
  const sources = findRelatedSources(finding)

  return {
    finding,
    confirmingSources: sources.filter(s => confirms(s, finding)),
    conflictingSources: sources.filter(s => conflicts(s, finding))
  }
}
```

#### 完全性チェック

```typescript
interface CompletenessCheck {
  requiredItems: string[]
  foundItems: string[]
  missingItems: string[]
  completeness: number      // 0-1
}

// 調査の完全性を確認
function checkCompleteness(
  objective: string,
  findings: Finding[]
): CompletenessCheck {
  const required = extractRequiredItems(objective)
  const found = findings.map(f => f.item)
  const missing = required.filter(r => !found.includes(r))

  return {
    requiredItems: required,
    foundItems: found,
    missingItems: missing,
    completeness: found.length / required.length
  }
}
```

---

## 🔍 調査タイプ別プロトコル

### Type 1: コード調査

```
目的: 既存コードの理解

手順:
1. get_symbols_overview で全体構造把握
2. 主要シンボルを find_symbol で詳細確認
3. find_referencing_symbols で使用箇所特定
4. 依存関係をマッピング
5. アーキテクチャパターンを特定
6. 結論をまとめる

検証:
□ 全主要コンポーネントを確認したか?
□ 依存関係は正しくマッピングしたか?
□ エッジケースを見落としていないか?
```

### Type 2: バグ調査

```
目的: バグの原因特定

手順:
1. 症状を明確化
2. 再現手順を確認
3. 関連コードを特定(find_symbol, search_for_pattern)
4. データフローを追跡
5. 仮説を立てる(複数)
6. 各仮説を検証
7. 根本原因を特定

検証:
□ 複数の仮説を検討したか?
□ 再現できることを確認したか?
□ 副作用を考慮したか?
```

### Type 3: パフォーマンス調査

```
目的: ボトルネックの特定

手順:
1. メトリクスを収集
2. プロファイリング結果を分析
3. ホットスポットを特定
4. アルゴリズム複雑度を確認
5. N+1問題をチェック
6. 最適化ポイントを特定

検証:
□ 測定可能なデータに基づいているか?
□ 推測ではなく実測したか?
□ 最適化の影響を試算したか?
```

### Type 4: セキュリティ調査

```
目的: 脆弱性の発見

手順:
1. 攻撃面を特定
2. 入力検証を確認
3. 認証・認可をチェック
4. データフローを追跡
5. OWASP Top 10 に照らし合わせ
6. 脆弱性を評価(CVSS)

検証:
□ 全入力ポイントを確認したか?
□ 実際に攻撃可能か検証したか?
□ 影響範囲を正しく評価したか?
```

---

## 📊 調査品質メトリクス

### 測定項目

```typescript
interface InvestigationMetrics {
  sourcesChecked: number        // 確認したソース数
  findingsCount: number         // 発見事項数
  verifiedFindings: number      // 検証済み発見事項数
  contradictions: number        // 検出された矛盾数
  completeness: number          // 完全性(0-1)
  confidence: number            // 確信度(0-1)
  timeSpent: number             // 所要時間(分)
}

// 品質基準
const QUALITY_THRESHOLDS = {
  sourcesChecked: 3,            // 最低3ソース
  verifiedFindings: 0.9,        // 90%以上検証済み
  contradictions: 0,            // 矛盾ゼロ
  completeness: 0.95,           // 95%以上完全
  confidence: 0.85              // 85%以上の確信度
}
```

### 品質チェック

```typescript
function assessInvestigationQuality(
  metrics: InvestigationMetrics
): QualityAssessment {
  const issues: string[] = []

  if (metrics.sourcesChecked < QUALITY_THRESHOLDS.sourcesChecked) {
    issues.push('ソース数が不足')
  }

  if (metrics.verifiedFindings / metrics.findingsCount < QUALITY_THRESHOLDS.verifiedFindings) {
    issues.push('検証が不十分')
  }

  if (metrics.contradictions > QUALITY_THRESHOLDS.contradictions) {
    issues.push('矛盾が存在')
  }

  if (metrics.completeness < QUALITY_THRESHOLDS.completeness) {
    issues.push('調査が不完全')
  }

  if (metrics.confidence < QUALITY_THRESHOLDS.confidence) {
    issues.push('確信度が低い')
  }

  return {
    passed: issues.length === 0,
    issues
  }
}
```

---

## 🚨 レッドフラグ(警告サイン)

### 調査中に以下を検出したら再調査

```
⚠️ 矛盾する情報が見つかった
   → 追加調査で矛盾を解消

⚠️ 確信度が低い(< 0.8)
   → より多くの証拠を収集

⚠️ ソースが1つのみ
   → 別のソースで確認

⚠️ 完全性が低い(< 0.9)
   → 見落としがないか再確認

⚠️ パターンが不明瞭
   → より多くのデータポイントを収集

⚠️ 仮説が検証できない
   → 仮説を再構築
```

---

## 📋 調査レポートテンプレート

```markdown
# 調査レポート: [調査対象]

## 概要
- **目的**: [調査目的]
- **範囲**: [調査範囲]
- **期間**: [所要時間]

## 調査方法
1. [使用した手法1]
2. [使用した手法2]
3. [使用した手法3]

## 発見事項

### 主要発見1
- **内容**: [発見内容]
- **ソース**: [確認したソース]
- **確信度**: XX%
- **検証**: ✓ 検証済み

### 主要発見2
...

## 依存関係
[依存関係図]

## 矛盾点
[検出された矛盾とその解決]

## 未確認事項
- [ ] [未確認項目1]
- [ ] [未確認項目2]

## 結論
[調査結論]

## 推奨事項
1. [推奨1]
2. [推奨2]

## 品質メトリクス
- ソース確認数: X
- 検証済み発見: X/Y (XX%)
- 完全性: XX%
- 確信度: XX%
```

---

**段階的調査、複数ソース確認、徹底検証で高精度な調査を実現**
