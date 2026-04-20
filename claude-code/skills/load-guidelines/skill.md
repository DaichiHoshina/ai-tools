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

#### デフォルト: 必須コアのみ（軽量、~2,500トークン）

検出された技術スタックに応じて、各カテゴリの代表ファイルのみ読み込む:

| 条件 | 必須読込 |
|-----|---------|
| 共通（必須） | `~/.claude/guidelines/common/code-quality-design.md` |
| TypeScript | `~/.claude/guidelines/languages/typescript.md` |
| Next.js/React | `~/.claude/guidelines/languages/nextjs-react.md` |
| Go | `~/.claude/guidelines/languages/golang.md` |

#### `full` オプション: 詳細ガイドライン追加（+~5,500トークン）

必須コアに加えて関連ファイル群を読み込む:

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

Skill frontmatter の `requires-guidelines` に記載された識別子を、Skill実行時に自動読込（重複読込はスキップ）。

### ガイドライン識別子マッピング

| カテゴリ | 識別子 → パス |
|---------|--------------|
| 共通 | `common` → `common/code-quality-design.md`（必須コア、詳細は `common/*.md` 各種） |
| 言語 | `typescript`, `golang`, `nextjs-react`, `tailwind`, `shadcn` → `languages/{id}.md` |
| インフラ | `terraform`, `kubernetes` → `infrastructure/{id}.md` |
| 設計 | `clean-architecture`, `ddd` → `design/{id}.md` |
| 運用 | `operations` → `operations/monitoring-runbook.md` |
