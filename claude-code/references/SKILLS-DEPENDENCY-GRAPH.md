# Skills Dependency Graph - スキル依存関係図

> スキル間の依存関係と推奨組み合わせを可視化

**注記**: Phase 2-5でスキル統合を実施（24スキル→18スキル）。本ドキュメントは新スキル名で更新済み。旧スキル名も動作します。詳細は [SKILL-MIGRATION.md](../SKILL-MIGRATION.md) 参照。

## スキル依存関係全体図

```mermaid
flowchart TB
    subgraph "ガイドライン基盤"
        LG[load-guidelines]
    end

    subgraph "言語スキル"
        GO[go-backend]
        TS[typescript-backend]
        React[react-best-practices]
        Python[python-backend]
        Rust[rust-backend]
        Java[java-backend]
        Vue[vue-best-practices]
        Svelte[svelte-best-practices]
    end

    subgraph "設計スキル"
        CA[clean-architecture-ddd]
        API[api-design]
        MS[microservices-monorepo]
        GRPC[grpc-protobuf]
    end

    subgraph "インフラスキル"
        Docker[dockerfile-best-practices]
        K8s[kubernetes]
        TF[terraform]
        DT[docker-troubleshoot]
    end

    subgraph "レビュースキル"
        CQ[comprehensive-review --focus=quality]
        SE[comprehensive-review --focus=security]
        DT2[comprehensive-review --focus=docs]
        UI[uiux-review]
        UIS[ui-skills]
    end

    subgraph "ユーティリティ"
        Tasks[Claude Code Tasks]
        SM[session-mode]
        GM[guideline-maintenance]
        CE[cleanup-enforcement]
        MCP[mcp-setup-guide]
        AIS[ai-tools-sync]
    end

    %% ガイドライン依存
    LG --> GO & TS & React & Python & Rust & Java & Vue & Svelte
    LG --> CA & API & Docker & K8s & TF

    %% 設計依存
    CA --> GO & TS & Python & Rust & Java
    API --> GO & TS & GRPC
    MS --> Docker & K8s

    %% インフラ依存
    Docker --> K8s
    K8s --> TF
    DT -.-> Docker

    %% レビュー関連
    CQ --> CA
    SE --> CQ
    DT2 --> CQ

    %% UI関連
    UI --> UIS
    UIS --> React & Vue & Svelte
```

## カテゴリ別依存関係

### バックエンド開発

```mermaid
flowchart LR
    subgraph "Go"
        GO_LG[load-guidelines]
        GO_BE[go-backend]
        GO_CA[clean-architecture-ddd]
        GO_GRPC[grpc-protobuf]
    end

    GO_LG --> GO_BE --> GO_CA --> GO_GRPC
```

```mermaid
flowchart LR
    subgraph "TypeScript"
        TS_LG[load-guidelines]
        TS_BE[typescript-backend]
        TS_CA[clean-architecture-ddd]
    end

    TS_LG --> TS_BE --> TS_CA
```

```mermaid
flowchart LR
    subgraph "Python"
        PY_LG[load-guidelines]
        PY_BE[python-backend]
        PY_CA[clean-architecture-ddd]
    end

    PY_LG --> PY_BE --> PY_CA
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
        I_DF[dockerfile-best-practices]
        I_K8[kubernetes]
        I_TF[terraform]
    end

    I_DF --> I_K8 --> I_TF
```

### 品質レビュー

```mermaid
flowchart LR
    subgraph "レビューフロー"
        R_CQ[comprehensive-review --focus=quality]
        R_SE[comprehensive-review --focus=security]
        R_DT[comprehensive-review --focus=docs]
    end

    R_CQ --> R_SE --> R_DT
```

## 推奨スキル組み合わせ

### フルスタック開発

| 用途 | スキル組み合わせ |
|------|-----------------|
| **Go + gRPC** | `go-backend` → `clean-architecture-ddd` → `grpc-protobuf` |
| **TypeScript** | `typescript-backend` → `clean-architecture-ddd` → `api-design` |
| **React/Next.js** | `react-best-practices` → `ui-skills` → `uiux-review` |
| **Python FastAPI** | `python-backend` → `clean-architecture-ddd` → `api-design` |
| **Rust CLI** | `rust-backend` → `clean-architecture-ddd` |
| **Vue/Nuxt** | `vue-best-practices` → `ui-skills` → `uiux-review` |

### インフラ構築

| 用途 | スキル組み合わせ |
|------|-----------------|
| **コンテナ化** | `dockerfile-best-practices` |
| **K8s デプロイ** | `dockerfile-best-practices` → `kubernetes` |
| **クラウド全体** | `dockerfile-best-practices` → `kubernetes` → `terraform` |
| **Docker トラブル** | `docker-troubleshoot` |

### 品質保証

| 用途 | スキル組み合わせ |
|------|-----------------|
| **コード品質** | `comprehensive-review --focus=quality` |
| **セキュリティ** | `comprehensive-review --focus=quality` → `comprehensive-review --focus=security` |
| **フルレビュー** | `comprehensive-review --focus=quality` → `comprehensive-review --focus=security` → `comprehensive-review --focus=docs` |
| **UI/UX** | `uiux-review` → `ui-skills` |

## スキル自動選択フロー

```mermaid
flowchart TD
    Input[ユーザー入力]

    Input --> FileCheck{ファイル検出}
    Input --> KeywordCheck{キーワード検出}
    Input --> ErrorCheck{エラーログ検出}
    Input --> GitCheck{Git状態検出}

    FileCheck -->|"*.go"| GO[go-backend]
    FileCheck -->|"*.ts/tsx"| TS[typescript-backend]
    FileCheck -->|"*.py"| Python[python-backend]
    FileCheck -->|"*.rs"| Rust[rust-backend]
    FileCheck -->|"*.java"| Java[java-backend]
    FileCheck -->|"*.vue"| Vue[vue-best-practices]
    FileCheck -->|"Dockerfile"| Docker[dockerfile-best-practices]

    KeywordCheck -->|"リファクタ"| CA[clean-architecture-ddd]
    KeywordCheck -->|"セキュリティ"| SE[comprehensive-review --focus=security]
    KeywordCheck -->|"テスト"| DT[comprehensive-review --focus=docs]

    ErrorCheck -->|"Docker接続"| DT2[docker-troubleshoot]
    ErrorCheck -->|"型エラー"| TS2[typescript-backend]
    ErrorCheck -->|"ModuleNotFoundError"| Python2[python-backend]

    GitCheck -->|"feature/api"| API[api-design]
    GitCheck -->|"refactor/"| CA2[clean-architecture-ddd]
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
| `go-backend` | `languages/go-backend.md` |
| `typescript-backend` | `languages/typescript-backend.md` |
| `react-best-practices` | `languages/react-best-practices.md` |
| `python-backend` | `languages/python-backend.md` |
| `rust-backend` | `languages/rust-backend.md` |
| `clean-architecture-ddd` | `design/clean-architecture-ddd.md` |
| `api-design` | `design/api-design.md` |
