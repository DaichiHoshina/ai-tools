# Agent Flowchart - エージェント連携フロー図

> タスク複雑度に応じた適切なエージェント連携パターン

## ComplexityCheck 判定フロー

```mermaid
flowchart TD
    Task[Task受領]
    CC{ComplexityCheck}

    Task --> CC

    CC -->|"ファイル<5 & 行数<300"| Simple[Direct実装]
    CC -->|"ファイル≥5 OR 機能≥3"| TD[TaskDecomposition]
    CC -->|"複数プロジェクト横断"| AH[AgentHierarchy]

    Simple --> Done[完了]

    TD --> Kanban[Kanban管理]
    Kanban --> Phase1[Phase1: 探索]
    Phase1 --> Phase2[Phase2: 設計]
    Phase2 --> Phase3[Phase3: 実装]
    Phase3 --> Phase4[Phase4: 検証]
    Phase4 --> Phase5[Phase5: 完了]
    Phase5 --> Done

    AH --> PO[PO Agent]
```

## エージェント階層構造

```mermaid
flowchart TD
    subgraph "戦略層"
        PO[PO Agent<br/>戦略決定・Worktree管理]
    end

    subgraph "管理層"
        Manager[Manager Agent<br/>タスク分割・配分計画]
    end

    subgraph "実行層"
        Dev1[Developer 1<br/>Serena MCP必須]
        Dev2[Developer 2<br/>Serena MCP必須]
        Dev3[Developer 3<br/>Serena MCP必須]
        Dev4[Developer 4<br/>Serena MCP必須]
    end

    subgraph "探索層"
        Exp1[Explore 1<br/>読み取り専用]
        Exp2[Explore 2<br/>読み取り専用]
    end

    subgraph "検証層"
        Verify[verify-app<br/>ビルド・テスト・lint]
        Simplify[code-simplifier<br/>複雑度削減]
    end

    PO --> Manager
    Manager --> Dev1 & Dev2 & Dev3 & Dev4
    Manager --> Exp1 & Exp2
    Dev1 & Dev2 & Dev3 & Dev4 --> Verify
    Verify --> Simplify
```

## ワークフロー自動化

```mermaid
flowchart LR
    subgraph "入力"
        User[ユーザー入力]
        Flow[/flow コマンド]
    end

    subgraph "判定"
        WO[workflow-orchestrator]
        Type{タスクタイプ}
    end

    subgraph "実行"
        Plan[/plan]
        Dev[/dev]
        Review[/review]
        Debug[/debug]
        Test[/test]
    end

    User --> Flow
    Flow --> WO
    WO --> Type

    Type -->|"設計・計画"| Plan
    Type -->|"実装"| Dev
    Type -->|"レビュー"| Review
    Type -->|"デバッグ"| Debug
    Type -->|"テスト作成"| Test
```

## Kanban 5フェーズ

```mermaid
flowchart LR
    subgraph "Phase 1"
        P1[探索<br/>コードベース理解]
    end

    subgraph "Phase 2"
        P2[設計<br/>アーキテクチャ決定]
    end

    subgraph "Phase 3"
        P3[実装<br/>コード作成]
    end

    subgraph "Phase 4"
        P4[検証<br/>テスト・レビュー]
    end

    subgraph "Phase 5"
        P5[完了<br/>ドキュメント・PR]
    end

    P1 --> P2 --> P3 --> P4 --> P5
```

## エージェント特性一覧

| エージェント | 役割 | ツール | 特徴 |
|-------------|------|--------|------|
| **po-agent** | 戦略決定 | All tools | 実装は一切行わない |
| **manager-agent** | タスク分割 | All tools | 実装は一切行わない |
| **developer-agent** | 実装担当 | All tools + Serena MCP | Serena必須 |
| **explore-agent** | 探索・分析 | All tools + Serena MCP | 読み取り専用 |
| **verify-app** | 包括検証 | All tools | ビルド・テスト・lint |
| **code-simplifier** | 簡素化 | All tools | 複雑度削減・重複統合 |
| **workflow-orchestrator** | 自動化 | All tools | タスクタイプ判定 |

## 並列実行パターン

```mermaid
flowchart TD
    subgraph "並列実行可能"
        A[Developer 1: Feature A]
        B[Developer 2: Feature B]
        C[Explore 1: 調査]
        D[Explore 2: 分析]
    end

    subgraph "同期ポイント"
        Sync[Manager: 統合]
    end

    A & B & C & D --> Sync
```

## 使用例

### Simple タスク
```
ユーザー: "この関数のバグを修正して"
→ 直接実装（エージェント不要）
```

### TaskDecomposition タスク
```
ユーザー: "ユーザー認証機能を追加して"
→ Kanban + 5フェーズで管理
→ Developer 1-2 が並列実装
```

### AgentHierarchy タスク
```
ユーザー: "フロントエンドとバックエンドを新規構築"
→ PO が戦略決定
→ Manager がタスク分割
→ Developer 1-4 が並列実装
→ verify-app で検証
```
