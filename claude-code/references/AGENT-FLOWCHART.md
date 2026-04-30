# Agent Flowchart - エージェント連携フロー図

> 7段階エージェント階層による自動化フロー

## エージェント階層構造

```mermaid
flowchart TD
    subgraph "戦略層"
        PO[PO Agent<br/>戦略決定・Worktree管理<br/>プロジェクト全体方針]
    end

    subgraph "管理層"
        Manager[Manager Agent<br/>タスク分割・配分計画<br/>並列実行制御]
    end

    subgraph "実行層"
        Dev1[Developer 1<br/>Frontend<br/>UI/コンポーネント]
        Dev2[Developer 2<br/>Backend<br/>API/ロジック]
        Dev3[Developer 3<br/>Testing<br/>テスト実装]
        Dev4[Developer 4<br/>General<br/>インフラ/ドキュメント]
    end

    subgraph "探索層"
        Explore[Explore Agent<br/>読み取り専用<br/>広域分析・クエリ]
    end

    subgraph "検証・改善層"
        Reviewer[Reviewer Agent<br/>コード品質<br/>セキュリティ監査]
        RootCause[Root Cause Agent<br/>インシデント分析<br/>根本原因特定]
        Verify[Verify Agent<br/>ビルド・テスト・lint]
    end

    PO --> Manager
    Manager --> Dev1 & Dev2 & Dev3 & Dev4
    Manager --> Explore
    Dev1 & Dev2 & Dev3 & Dev4 --> Reviewer
    Reviewer --> Verify
    Verify --> RootCause
```

## タスク複雑度による Agent 選択

```mermaid
flowchart TD
    Task[Task受領]
    CC{複雑度判定}

    Task --> CC

    CC -->|"単純：ファイル<5 & 機能<2"| Simple["/dev --quick<br/>直接実装"]
    CC -->|"中級：ファイル5-10 & 機能2-3"| Medium["/flow<br/>Manager + Dev1-4"]
    CC -->|"複雑：ファイル>10 OR 複数領域"| Complex["/flow --parallel<br/>Manager + 並列Dev"]
    CC -->|"広域分析必要"| Explore_Task["Explore Agent<br/>読み取り専用"]

    Simple --> Verify_Done["検証 + 完了"]
    Medium --> Tasks["Tasks 5フェーズ"]
    Complex --> Parallel["並列実装<br/>max N=4"]
    Explore_Task --> Report["分析レポート"]

    Tasks --> Verify_Done
    Parallel --> Verify_Done
```

## Developer 専門性分類（実行層 N=4）

| ID | 専門 | 担当 | 例 |
|----|------|------|-----|
| dev1 | Frontend | UI/UX、コンポーネント | React/Vue/Svelte |
| dev2 | Backend | API、ビジネスロジック | Node.js/Python/Go |
| dev3 | Testing | テスト実装、品質保証 | Jest/pytest/RSpec |
| dev4 | General | インフラ、ドキュメント | Docker/K8s/Terraform |

## 並列実行フロー（`/flow --parallel`）

```mermaid
flowchart LR
    PO["PO Agent<br/>Worktree設計"]
    --> Mgr["Manager Agent<br/>タスク分割"]
    --> Split["並列分割 max N≤4"]

    Split --> |wt-1| D1["Dev1"]
    Split --> |wt-2| D2["Dev2"]
    Split --> |wt-3| D3["Dev3"]
    Split --> |wt-4| D4["Dev4"]

    D1 --> Merge["Merge<br/>並列worktreeを本流へ"]
    D2 --> Merge
    D3 --> Merge
    D4 --> Merge

    Merge --> Verify["Verify Agent"]
```

## ワークフロー入力点

| コマンド | 実行Agent | 用途 |
|---------|-----------|------|
| `/plan` | PO | 戦略計画・DesignDoc |
| `/flow` | Manager | タスク分割・単順行 |
| `/flow --parallel` | Manager | 並列実行制御（N≤4） |
| `/dev` | Developer | 直接実装（単発） |
| `/dev --quick` | Developer | 軽量実装（1-2ファイル） |
| `/explore` | Explore | 広域読み取り分析 |
| `/review` | Reviewer | コード品質・セキュリティ |
| `/root-cause` | Root Cause | インシデント分析 |
| `/verify-once` | Verify | 検証用テスト |

## 完了フロー

```
Developer実装完了
  ↓
Reviewer コード品質監査
  ↓
Verify Agent テスト・lint・ビルド
  ↓
Root Cause Agent 潜在リスク検査
  ↓
成功 → PR / merge
失敗 → bug report + Developer再実装
```
