# /flow コマンド カバレッジ分析

> 最終更新: 2026-02-07

## 概要

`/flow` コマンドは、タスクタイプを自動判定して最適なワークフローを実行する統合コマンドです。この文書では、全26スキル・21コマンドのうち、どれがカバーされているか、されていないかを分析します。

## 📊 カバレッジ統計

| カテゴリ | 総数 | カバー済 | 未カバー | カバー率 |
|---------|------|---------|---------|---------|
| コマンド | 21 | 14 | 7 | 67% |
| スキル | 26 | 6 | 20 | 23% |
| エージェント | 9 | 4 | 5 | 44% |

## ✅ カバー済み（flowで使用可能）

### コマンド（14/21）

#### ワークフローコマンド
- **brainstorm** - 設計相談ワークフロー（Priority 0）
- **prd** - 要件定義（全ワークフローで使用）
- **plan** - 実装計画（feature/refactor/design）
- **debug** - バグ調査（bugfix/hotfix）
- **dev** - 実装（feature/bugfix/hotfix）
- **refactor** - リファクタリング（refactor）
- **docs** - ドキュメント作成（docs）
- **test** - テスト作成（feature/test）
- **review** - レビュー（feature/refactor/docs/test）
- **commit-push-pr** - Git統合（全ワークフロー完了時）

#### サポートコマンド
- **protection-mode** - 前提条件（必須読み込み）
- **explore** - コードベース調査（docs）
- **flow** - 自身
- **serena** - Serena MCPツール（全操作で使用）

### エージェント（4/9）

- **workflow-orchestrator** - flowのバックエンド（タスク自動判定）
- **code-simplifier** - コード簡素化（feature/refactor後に必須）
- **verify-app** - アプリケーション検証（全ワークフローで必須）
- **developer-agent/reviewer-agent** - Writer/Reviewer並列パターン（大規模変更時）

### スキル（6/26 - reviewコマンド経由）

#### レビュー系（基本セット）
- **code-quality-review** - 品質レビュー（全ワークフローのreviewフェーズ）
- **security-error-review** - セキュリティレビュー（全ワークフローのreviewフェーズ）
- **docs-test-review** - ドキュメント・テストレビュー（テスト含むワークフロー）
- **uiux-review** - UI/UXレビュー（UIファイル変更時）
- **ui-skills** - UI構築制約（Tailwind/shadcn使用時）
- **cleanup-enforcement** - クリーンアップ強制（reviewフェーズ前の確認）

## ⚠️ 部分カバー（明示的統合なし、自動使用の可能性あり）

### 開発系スキル（技術スタック検出時に自動使用？）

| スキル | 使用タイミング（推測） | flowでの明示的統合 |
|--------|----------------------|-------------------|
| **go-backend** | Go検出時の/devフェーズ | ❌ なし（load-guidelines経由？） |
| **typescript-backend** | TypeScript検出時の/devフェーズ | ❌ なし（load-guidelines経由？） |
| **react-best-practices** | React/Next.js検出時 | ❌ なし（load-guidelines経由？） |
| **grpc-protobuf** | proto定義変更時 | ❌ なし |
| **api-design** | API開発時 | ❌ なし |
| **clean-architecture-ddd** | 設計重視時 | ❌ なし（brainstorm/prd時に手動？） |

**問題点**: これらのスキルは `/dev` コマンドや `/review` コマンドが内部で使用している可能性があるが、`/flow` から明示的に呼び出されていない。

## ❌ 未カバー（flowで使用不可）

### コマンド（7/21）

#### メタ操作（flowの対象外）
- **aliases** - コマンドエイリアス定義（設定）
- **reload** - CLAUDE.md再読み込み（メンテナンス）
- **retrospective** - 振り返り（メタ分析）
- **session-mode** - セッションモード切替（設定）

#### 特定開発スタイル
- **tdd** - TDD開発モード（flowと競合する独立ワークフロー）
- **quick-fix** - 単純修正（flowの簡略版、Simple時は直接実行推奨）
- **commit** - Gitコミットのみ（commit-push-prに含まれる）

### スキル（20/26）

#### 特定技術スタック（flowのワークフローに未統合）
- **grpc-protobuf** - gRPC/Protobuf開発
- **terraform** - Terraform IaC設計
- **dockerfile-best-practices** - Dockerfileベストプラクティス
- **kubernetes** - Kubernetes設計・運用
- **microservices-monorepo** - マイクロサービス・モノレポ設計

#### 設計ガイドライン（brainstorm/prd時に手動使用）
- **clean-architecture-ddd** - クリーンアーキテクチャ・DDD
- **api-design** - API設計
- **formal-methods** - 形式手法（TLA+/Alloy）

#### ユーティリティ（メタ操作）
- **ai-tools-sync** - ai-tools同期
- **mcp-setup-guide** - MCPセットアップ
- **guideline-maintenance** - ガイドラインメンテナンス
- **load-guidelines** - ガイドライン自動読み込み（/devや/reviewが内部使用？）

#### その他
- **techdebt** - 技術的負債検出（リファクタリング時に有用だが未統合）
- **context7** - ドキュメント検索ツール（手動使用）
- **data-analysis** - データ分析（特定タスクタイプだが未統合）
- **docker-troubleshoot** - Dockerトラブルシュート（緊急対応だが未統合）

### エージェント（5/9）

- **explore-agent** - 探索エージェント（/exploreコマンド経由では使用可能）
- **developer-agent** - 開発エージェント（並列パターン以外は未使用）
- **reviewer-agent** - レビューエージェント（並列パターン以外は未使用）
- **manager-agent** - マネージャーエージェント（タスク分割、未統合）
- **po-agent** - Product Ownerエージェント（戦略策定、未統合）

## 🔍 詳細分析

### 1. タスクタイプ別カバレッジ

| タスクタイプ | ワークフロー | カバー率 | 未カバー機能 |
|------------|------------|---------|-------------|
| 設計相談（Priority 0） | brainstorm→prd→plan | 🟢 高 | 設計ガイドライン（clean-arch/api-design/formal-methods）|
| 緊急対応（Priority 1） | debug→dev→verify→PR | 🟡 中 | docker-troubleshoot |
| バグ修正（Priority 2） | debug→dev→verify→PR | 🟢 高 | - |
| リファクタリング（Priority 3） | plan→refactor→simplify→review→verify→PR | 🟡 中 | techdebt（技術的負債検出） |
| ドキュメント（Priority 4） | explore→docs→review→PR | 🟢 高 | - |
| テスト作成（Priority 5） | test→review→verify→PR | 🟢 高 | - |
| 新機能実装（Priority 6） | prd→plan→dev→simplify→test→review→verify→PR | 🟡 中 | 技術スタック特化スキル |

### 2. 技術スタック別カバレッジ

| 技術スタック | 対応スキル | flowでの統合 | 改善案 |
|------------|----------|------------|-------|
| Go | go-backend, grpc-protobuf | ❌ なし | /devフェーズで自動読み込み |
| TypeScript | typescript-backend | ❌ なし | /devフェーズで自動読み込み |
| React/Next.js | react-best-practices, ui-skills | ⚠️ review時のみ | /devフェーズで自動読み込み |
| Docker | dockerfile-best-practices, docker-troubleshoot | ❌ なし | インフラワークフロー追加 |
| Kubernetes | kubernetes, microservices-monorepo | ❌ なし | インフラワークフロー追加 |
| Terraform | terraform | ❌ なし | インフラワークフロー追加 |

### 3. 欠けているワークフロー

#### データ分析ワークフロー（未実装）
```yaml
data-analysis:
  steps:
    - skill: data-analysis
      required: true
      description: データ分析実行
    - command: /docs
      required: false
      description: 分析結果ドキュメント化
    - command: /commit-push-pr
      required: true
```

#### インフラ開発ワークフロー（未実装）
```yaml
infrastructure:
  steps:
    - command: /plan
      required: true
      description: インフラ設計
    - skill: terraform OR kubernetes OR dockerfile-best-practices
      required: true
      description: IaCコード作成
    - agent: verify-app
      args: "terraform plan"
      required: true
    - command: /commit-push-pr
      required: true
```

#### TDD開発ワークフロー（tddコマンドと重複）
```yaml
# /tdd コマンドが独立して存在するため、flowには統合不要
# ただし、flowからtddモードに切り替えるオプションはあっても良い
```

#### トラブルシュートワークフロー（未実装）
```yaml
troubleshoot:
  steps:
    - skill: docker-troubleshoot OR debug
      required: true
      description: 問題診断
    - command: /dev
      required: false
      description: 修正実装
    - command: /docs
      required: false
      description: トラブルシュート手順ドキュメント化
```

## 💡 改善提案

### Priority 1: 技術スタック自動検出の強化

**問題**: 技術スタック特化スキル（go-backend, typescript-backend等）がflowで使用されていない。

**解決策**: workflow-orchestratorのPhase 1に技術スタック検出を追加し、/devフェーズで自動読み込み。

```typescript
// Phase 1に追加
async function detectTechStack(): Promise<string[]> {
  const stacks: string[] = [];

  // go.mod検出 → go-backend
  if (await fileExists('go.mod')) stacks.push('go-backend');

  // package.json検出 → typescript-backend or react-best-practices
  if (await fileExists('package.json')) {
    const pkg = JSON.parse(await readFile('package.json'));
    if (pkg.dependencies?.['react']) stacks.push('react-best-practices');
    if (pkg.dependencies?.['next']) stacks.push('react-best-practices');
    if (!stacks.includes('react-best-practices')) stacks.push('typescript-backend');
  }

  // Dockerfile検出 → dockerfile-best-practices
  if (await fileExists('Dockerfile')) stacks.push('dockerfile-best-practices');

  // terraform検出 → terraform
  if (await fileExists('main.tf')) stacks.push('terraform');

  // kubernetes検出 → kubernetes
  if (await fileExists('k8s/') || await fileExists('kubernetes/')) stacks.push('kubernetes');

  return stacks;
}

// /devフェーズ実行時に技術スタック特化スキルを自動適用
async function executeDevPhase(techStacks: string[]) {
  // 技術スタック特化スキルを並列実行
  const skillPromises = techStacks.map(stack => Skill(stack));
  await Promise.all(skillPromises);

  // 実装コマンド実行
  await executeCommand('/dev');
}
```

### Priority 2: 欠けているワークフローの追加

**追加すべきワークフロー**:
1. **data-analysis** - データ分析ワークフロー
2. **infrastructure** - インフラ開発ワークフロー
3. **troubleshoot** - トラブルシュートワークフロー

**実装箇所**: workflow-orchestrator.mdの`workflows`セクションに追加

### Priority 3: 設計ガイドラインの統合

**問題**: clean-architecture-ddd, api-design, formal-methodsがbrainstorm/prdフェーズで自動使用されていない。

**解決策**: brainstormコマンドに設計ガイドライン選択UIを追加。

```typescript
// /brainstormフェーズに追加
async function selectDesignGuidelines(taskContext: TaskContext): Promise<string[]> {
  const guidelines: string[] = [];

  // タスク内容から推奨ガイドライン判定
  const recommendations = analyzeTaskForGuidelines(taskContext);

  // ユーザーに確認
  const answer = await AskUserQuestion({
    questions: [{
      question: "設計ガイドラインを選択してください（複数選択可）",
      header: "設計ガイドライン",
      multiSelect: true,
      options: [
        { label: "Clean Architecture/DDD (推奨)", description: "レイヤー設計、ドメインモデリング" },
        { label: "API Design", description: "REST/GraphQL設計原則" },
        { label: "Formal Methods", description: "TLA+/Alloy形式手法" },
        { label: "なし", description: "ガイドラインなしで進める" }
      ]
    }]
  });

  // 選択されたガイドラインを適用
  if (answer["設計ガイドラインを選択してください（複数選択可）"].includes("Clean Architecture/DDD (推奨)")) {
    guidelines.push('clean-architecture-ddd');
  }
  // ...

  return guidelines;
}
```

### Priority 4: techdebtスキルの統合

**問題**: リファクタリング時に技術的負債検出が自動実行されない。

**解決策**: refactorワークフローのplanフェーズ後にtechdebtスキルを自動実行。

```yaml
refactor:
  steps:
    - mode: plan
      required: true
    - command: /plan
      required: true
    - skill: techdebt  # 追加
      required: true
      description: 技術的負債検出
      activeForm: 技術的負債検出中
    - command: /refactor
      required: true
    # ...
```

### Priority 5: load-guidelinesの明示的統合

**問題**: load-guidelinesがいつ呼び出されるか不明確。

**解決策**: workflow-orchestratorのPhase 1で明示的に呼び出し。

```typescript
// Phase 1の最後に追加
async function loadRequiredGuidelines(taskType: string, techStacks: string[]): Promise<void> {
  console.log('📚 必要なガイドラインを読み込んでいます...');

  // タスクタイプ別の必須ガイドライン
  const guidelinesForTask = {
    'feature': ['common'],
    'refactor': ['common'],
    'bugfix': ['common'],
    // ...
  };

  // 技術スタック別のガイドライン
  const guidelinesForStack = {
    'go-backend': ['golang', 'common'],
    'typescript-backend': ['typescript', 'common'],
    // ...
  };

  // 必要なガイドラインをマージ
  const requiredGuidelines = new Set([
    ...(guidelinesForTask[taskType] || []),
    ...techStacks.flatMap(stack => guidelinesForStack[stack] || [])
  ]);

  // load-guidelines呼び出し
  await Skill('load-guidelines', Array.from(requiredGuidelines).join(','));
}
```

## 📈 カバレッジ改善ロードマップ

### Phase 1（即座実施可能）
- ✅ 技術スタック自動検出の実装
- ✅ load-guidelinesの明示的統合
- ✅ techdebtスキルのrefactorワークフロー統合

### Phase 2（2週間以内）
- ⏳ 欠けているワークフローの追加（data-analysis, infrastructure, troubleshoot）
- ⏳ 設計ガイドライン選択UIの実装

### Phase 3（1ヶ月以内）
- ⏳ Writer/Reviewer並列パターンの自動判定
- ⏳ エージェント階層（manager-agent, po-agent）の統合

## 🎯 結論

### 現状の評価
- **コマンドカバレッジ**: 67%（14/21） - 良好
- **スキルカバレッジ**: 23%（6/26） - 改善が必要
- **エージェントカバレッジ**: 44%（4/9） - まずまず

### 主な問題点
1. **技術スタック特化スキルが未統合**（go-backend, typescript-backend等）
2. **設計ガイドラインが手動選択**（clean-arch, api-design等）
3. **特定タスクタイプのワークフロー欠如**（data-analysis, infrastructure等）
4. **自動化ユーティリティの使用不明確**（load-guidelines, techdebt等）

### 推奨アクション
優先度順：
1. 技術スタック自動検出の実装（Priority 1）
2. load-guidelinesとtechdebtの明示的統合（Priority 1, 4）
3. 欠けているワークフローの追加（Priority 2）
4. 設計ガイドライン統合（Priority 3）

これらの改善により、スキルカバレッジを**23% → 70%以上**に向上可能です。
