# Skills Dependency Graph - スキル依存関係図

> スキル間の依存関係と推奨組み合わせを可視化

**注記**: Phase 2-5でスキル統合を実施（24スキル→21スキル）。本ドキュメントは新スキル名で更新済み。旧スキル名も動作します。詳細は [SKILL-MIGRATION.md](../tutorials/SKILL-MIGRATION.md) 参照。

## スキル依存関係全体図

```mermaid
flowchart TB
    subgraph "ガイドライン基盤"
        LG[load-guidelines]
    end

    subgraph "言語・開発スキル（5+1）"
        TS[backend-dev]
        React[react-best-practices]
        CA[clean-architecture-ddd]
        API[api-design]
        GRPC[grpc-protobuf]
        Diagram[architecture-diagram]
    end

    subgraph "UI・レビュー系（3）"
        CReview[comprehensive-review]
        UIReview[uiux-review]
        UIS[ui-skills]
    end

    subgraph "インフラスキル（3）"
        Container[container-ops]
        TF[terraform]
        MS[microservices-monorepo]
    end

    subgraph "ユーティリティ（9）"
        C7[context7]
        CE[cleanup-enforcement]
        MCP[mcp-setup-guide]
        SM[session-mode]
        DA[data-analysis]
        TD[techdebt]
        IR[incident-response]
        RC[root-cause]
        CTX7[context7]
    end

    %% ガイドライン依存
    LG --> TS & React & CA & API & GRPC & Container & TF & MS

    %% 開発スキル依存
    CA --> TS & API & GRPC
    API --> GRPC
    MS --> Container & TF
    Diagram --> CA & MS

    %% レビュー系依存
    CReview --> CA
    UIReview --> UIS & React
    UIS --> React

    %% ユーティリティ依存
    CE --> CReview & TS
    TD --> CA & CE
    IR --> RC & CReview
    RC -.-> all

    %% インフラ依存
    Container --> TF
```

## カテゴリ別依存関係

### バックエンド開発

```mermaid
flowchart LR
    subgraph "Go/TypeScript/Python/Rust"
        LG[load-guidelines]
        BE[backend-dev]
        CA[clean-architecture-ddd]
        GRPC[grpc-protobuf]
    end

    LG --> BE --> CA --> GRPC
```

### フロントエンド開発

```mermaid
flowchart LR
    subgraph "React/Next.js"
        R_LG[load-guidelines]
        R_BP[react-best-practices]
        R_UI[ui-skills]
        R_UX[uiux-review]
    end

    R_LG --> R_BP --> R_UI --> R_UX
```

### インフラ構築

```mermaid
flowchart LR
    subgraph "コンテナ〜クラウド"
        I_CO[container-ops]
        I_TF[terraform]
        I_MS[microservices-monorepo]
    end

    I_CO --> I_TF & I_MS
```

### 品質レビュー

```mermaid
flowchart LR
    subgraph "レビューフロー"
        R_CR[comprehensive-review]
        R_UI[uiux-review]
        R_UIS[ui-skills]
    end

    R_CR --> R_UI & R_UIS
```

## 推奨スキル組み合わせ

### フルスタック開発

| 用途 | スキル組み合わせ |
|------|-----------------|
| **バックエンド（Go/TS/Python/Rust）** | `backend-dev` → `clean-architecture-ddd` → `api-design` / `grpc-protobuf` |
| **マイクロサービス** | `backend-dev` + `clean-architecture-ddd` + `microservices-monorepo` → `api-design` |
| **React/Next.js** | `react-best-practices` → `ui-skills` → `uiux-review` |
| **設計重視** | `clean-architecture-ddd` → `architecture-diagram` |

### インフラ構築

| 用途 | スキル組み合わせ |
|------|-----------------|
| **コンテナ化** | `container-ops` |
| **Kubernetes デプロイ** | `container-ops` → `microservices-monorepo` |
| **クラウド全体** | `container-ops` → `terraform` |
| **コンテナトラブル** | `container-ops --mode=troubleshoot` |

### 品質保証

| 用途 | スキル組み合わせ |
|------|-----------------|
| **コード品質** | `comprehensive-review` |
| **セキュリティ＆品質** | `comprehensive-review` + `root-cause` |
| **インシデント対応** | `incident-response` → `root-cause` |
| **UI/UX** | `uiux-review` → `ui-skills` |

## スキル自動選択フロー

```mermaid
flowchart TD
    Input[ユーザー入力]

    Input --> FileCheck{ファイル検出}
    Input --> KeywordCheck{キーワード検出}
    Input --> ErrorCheck{エラーログ検出}
    Input --> GitCheck{Git状態検出}

    FileCheck -->|"*.go/ts/py/rs"| BE[backend-dev]
    FileCheck -->|"*.tsx/jsx"| React[react-best-practices]
    FileCheck -->|"Dockerfile"| Container[container-ops]

    KeywordCheck -->|"リファクタ"| CA[clean-architecture-ddd]
    KeywordCheck -->|"セキュリティ"| CR[comprehensive-review]
    KeywordCheck -->|"UI/デザイン"| UI[ui-skills/uiux-review]

    ErrorCheck -->|"コンテナ"| CT[container-ops --mode=troubleshoot]
    ErrorCheck -->|"型エラー"| BE2[backend-dev]
    ErrorCheck -->|"マイク障害"| IR[incident-response]

    GitCheck -->|"feature/api"| API[api-design]
    GitCheck -->|"refactor/"| CA2[clean-architecture-ddd]
    GitCheck -->|"fix/incident"| RC[root-cause]
```

## 優先度ルール

1. **エラー検出** → 最優先（問題解決）
2. **ファイルパス検出** → 高優先（言語特定）
3. **キーワード検出** → 中優先（意図理解）
4. **Git状態検出** → 低優先（コンテキスト補完）

## ガイドライン必須スキル

以下のスキルは `load-guidelines` の事前読み込みが必須:

| スキル | 必要ガイドライン |
|--------|-----------------|
| `backend-dev` | `languages/golang.md`, `languages/typescript.md`, `languages/python.md`, `languages/rust.md`（言語検出時） |
| `react-best-practices` | `languages/react-best-practices.md` |
| `clean-architecture-ddd` | `design/clean-architecture-ddd.md` |
| `api-design` | `design/api-design.md` |
| `grpc-protobuf` | `languages/golang.md`, `design/grpc-protobuf.md` |
| `container-ops` | `infrastructure/docker-kubernetes.md` |
| `terraform` | `infrastructure/terraform.md` |
| `microservices-monorepo` | `infrastructure/microservices-kubernetes.md` |
| `comprehensive-review` | `common/review-guidelines.md` |
