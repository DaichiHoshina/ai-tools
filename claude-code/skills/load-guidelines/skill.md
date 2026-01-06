---
name: load-guidelines
description: ガイドライン自動読み込み - プロジェクトの技術スタックを検出し、必要なガイドラインのみをセッションに適用。トークン節約。
---

# プロジェクト適応型ガイドライン読み込み

## 使用タイミング

- 開発作業開始時（プロジェクトモード）
- Skill実行時（Skillモード - requires-guidelines自動読み込み）

---

## モード1: プロジェクト検出（セッション開始時）

### Step 1: 技術スタック検出

以下のファイル存在を確認:

| ファイル | 判定 |
|---------|------|
| `package.json` + next依存 | Next.js |
| `package.json` + react依存 | React |
| `package.json` + typescript依存 | TypeScript |
| `go.mod` | Go |
| `*.tf` | Terraform |
| `Dockerfile` / `docker-compose.yml` | Docker |
| `serverless.yml` / `template.yaml` | Lambda |
| `kubernetes/` / `k8s/` | Kubernetes |

### Step 2: ガイドライン読み込み

**共通（必須）:**
- `~/.claude/guidelines/common/claude-code-tips.md`
- `~/.claude/guidelines/common/code-quality-design.md`
- `~/.claude/guidelines/common/development-process.md`

**言語別（検出時のみ）:**

| 条件 | ガイドライン |
|-----|-------------|
| TypeScript | `~/.claude/guidelines/languages/typescript.md` |
| Next.js/React | `~/.claude/guidelines/languages/nextjs-react.md` |
| Go | `~/.claude/guidelines/languages/golang.md` |

**インフラ（検出時のみ）:**

| 条件 | ガイドライン |
|-----|-------------|
| Terraform | `~/.claude/guidelines/infrastructure/terraform.md` |
| Lambda | `~/.claude/guidelines/infrastructure/aws-lambda.md` |
| ECS/Fargate | `~/.claude/guidelines/infrastructure/aws-ecs-fargate.md` |
| EKS/K8s | `~/.claude/guidelines/infrastructure/aws-eks.md` |
| EC2 | `~/.claude/guidelines/infrastructure/aws-ec2.md` |

### Step 3: 結果報告

検出結果を報告し、**検出された言語名を記憶**:
- 検出言語: go, ts, react など（カンマ区切り）
- 共通のみの場合: common

---

## モード2: Skill連携（requires-guidelines）

### 概要

Skillのフロントマターに`requires-guidelines`が定義されている場合、そのSkill実行時に関連ガイドラインを自動読み込み。

### Skillフロントマター例

```yaml
---
name: typescript-backend
description: TypeScriptバックエンド開発
requires-guidelines:
  - typescript
  - common
---
```

### ガイドライン識別子マッピング

| 識別子 | ガイドラインパス |
|--------|-----------------|
| `common` | `~/.claude/guidelines/common/*.md`（主要3ファイル） |
| `typescript` | `~/.claude/guidelines/languages/typescript.md` |
| `golang` | `~/.claude/guidelines/languages/golang.md` |
| `nextjs-react` | `~/.claude/guidelines/languages/nextjs-react.md` |
| `terraform` | `~/.claude/guidelines/infrastructure/terraform.md` |
| `kubernetes` | `~/.claude/guidelines/infrastructure/aws-eks.md` |
| `clean-architecture` | `~/.claude/guidelines/design/clean-architecture.md` |
| `ddd` | `~/.claude/guidelines/design/domain-driven-design.md` |
| `microservices` | `~/.claude/guidelines/design/microservices-kubernetes.md` |
| `uiux` | `~/.claude/guidelines/design/ui-ux-guidelines.md` |

### 自動読み込みフロー

1. Skill呼び出し時、フロントマターの`requires-guidelines`を確認
2. 未読み込みのガイドラインがあれば読み込み
3. 既に読み込み済みならスキップ（重複防止）

---

## ガイドライン一覧

### common（共通）
- `claude-code-tips.md` - Claude Code活用法
- `code-quality-design.md` - コード品質
- `development-process.md` - 開発プロセス
- `error-handling-patterns.md` - エラーハンドリング
- `testing-guidelines.md` - テスト指針
- `type-safety-principles.md` - 型安全性

### languages（言語）
- `typescript.md` - TypeScript
- `golang.md` - Go
- `nextjs-react.md` - Next.js/React

### infrastructure（インフラ）
- `terraform.md` - Terraform
- `aws-eks.md` - EKS/Kubernetes
- `aws-ecs-fargate.md` - ECS/Fargate
- `aws-lambda.md` - Lambda
- `aws-ec2.md` - EC2

### design（設計）
- `clean-architecture.md` - クリーンアーキテクチャ
- `domain-driven-design.md` - DDD
- `microservices-kubernetes.md` - マイクロサービス
- `ui-ux-guidelines.md` - UI/UX

---

## 使用例

### セッション開始時
```
/load-guidelines
→ プロジェクト検出 → 必要なガイドライン読み込み
```

### Skill実行時（自動）
```
/review でsecurity-reviewスキル実行
→ requires-guidelines: [common] を確認
→ common未読み込みなら読み込み
```
