---
name: load-guidelines
description: ガイドライン自動読み込み - プロジェクトの技術スタックを検出し、必要なガイドラインのみをセッションに適用。トークン節約。
---

# load-guidelines - ガイドライン自動読み込み

## 使用方法

```
/load-guidelines        # サマリーのみ（軽量、推奨）
/load-guidelines full   # サマリー + 詳細ガイドライン
```

> **⚠️ トークン節約注意**
> - デフォルト（サマリーのみ）を推奨。ほとんどの作業はサマリーで十分
> - `full`オプションは追加で約5,500トークン消費
> - 詳細なコード例が必要な場合はContext7を活用

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

### Step 2: ガイドライン読み込み（2段階）

#### デフォルト: サマリーのみ（~2,500トークン）

検出された技術スタックに応じてサマリーを読み込む:

| 条件 | サマリー |
|-----|---------|
| 共通（必須） | `~/.claude/guidelines/summaries/common-summary.md` |
| TypeScript | `~/.claude/guidelines/summaries/typescript-summary.md` |
| Next.js/React | `~/.claude/guidelines/summaries/nextjs-react-summary.md` |
| Go | `~/.claude/guidelines/summaries/golang-summary.md` |

#### `full` オプション: 詳細ガイドライン追加（+~5,500トークン）

サマリーに加えて詳細ガイドラインを読み込む:

**共通:**
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
- モード: summary | full

---

## モード2: Skill連携（requires-guidelines）

### 概要

Skillのフロントマターに`requires-guidelines`が定義されている場合、そのSkill実行時に関連ガイドラインを自動読み込み。

### Skillフロントマター例

```yaml
---
name: backend-dev
description: バックエンド開発（Go/TypeScript/Python/Rust対応）
requires-guidelines:
  - typescript
  - common
---
```

### ガイドライン識別子マッピング

**🎯 トークン効率化**: 全ての識別子は自動的にsummariesを優先読み込み

**共通**: `common` → `summaries/common-summary.md` (詳細: `common/*.md`)

**言語別**:
| 識別子 | パス |
|--------|------|
| `typescript` | `languages/typescript.md` |
| `golang` | `languages/golang.md` |
| `nextjs-react` | `languages/nextjs-react.md` |
| `tailwind` | - | `languages/tailwind.md` |
| `shadcn` | - | `languages/shadcn.md` |

**インフラ**: `terraform`, `kubernetes` → `infrastructure/`

**設計**: `clean-architecture`, `ddd` → `design/`

### 自動読み込みフロー

1. Skill呼び出し時、フロントマターの`requires-guidelines`を確認
2. 未読み込みのガイドラインがあれば読み込み
3. 既に読み込み済みならスキップ（重複防止）
