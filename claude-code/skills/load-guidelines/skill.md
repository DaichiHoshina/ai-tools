---
name: load-guidelines
description: ガイドライン自動読み込み。技術スタック検出時に必要分のみ適用してトークン節約
---

# load-guidelines - ガイドライン自動読み込み

## 使用方法

```
/load-guidelines        # サマリーのみ（軽量、推奨）
/load-guidelines full   # サマリー + 詳細ガイドライン
```

> **⚠️ トークン節約**
> デフォルト（サマリーのみ）推奨。`full` は +約5,500トークン。詳細コード例は Context7 を活用。

## 使用タイミング

- 開発作業開始時（プロジェクトモード）
- Skill実行時（`requires-guidelines` 自動解決）

---

## モード1: プロジェクト検出（セッション開始時）

### Step 1: 技術スタック検出

| ファイル | 判定 |
|---------|------|
| `package.json` + next依存 | Next.js |
| `package.json` + react依存 | React |
| `package.json` + typescript依存 | TypeScript |
| `go.mod` | Go |
| `pyproject.toml` / `requirements.txt` / `Pipfile` | Python |
| `Cargo.toml` | Rust |
| `.eslintrc*` / `eslint.config.*` | ESLint（TypeScript時の補完） |
| `*.tf` | Terraform |
| `Dockerfile` / `docker-compose.yml` | Docker |
| `serverless.yml` / `template.yaml` | Lambda |
| `kubernetes/` / `k8s/` | Kubernetes |
| `package.json` + (express\|nest\|fastify\|koa) | Backend (Node) |
| `go.mod` + (gin\|echo\|fiber\|chi) | Backend (Go) |
| `requirements.txt` + (fastapi\|django\|flask) | Backend (Python) |

### Step 2: ガイドライン読込（2段階）

#### デフォルト: 必須コアのみ（~2,500トークン）

| 条件 | 必須読込 |
|-----|---------|
| 共通（必須） | `~/.claude/guidelines/common/code-quality-design.md` |
| TypeScript | `~/.claude/guidelines/languages/typescript.md` |
| Next.js/React | `~/.claude/guidelines/languages/nextjs-react.md` |
| Go | `~/.claude/guidelines/languages/golang.md` |

#### `full` オプション: 詳細追加（+~5,500トークン）

**共通（必須3本）**:
- `~/.claude/guidelines/common/claude-code-tips.md`
- `~/.claude/guidelines/common/code-quality-design.md`
- `~/.claude/guidelines/common/development-process.md`

**言語別（検出時のみ）**: `languages/{id}.md` を読込。追加例外:
- TypeScript + ESLint 検出 → `languages/eslint.md` 追加
- Go 検出 → `languages/go-test-stability.md` 追加
- Next.js/React + Tailwind 検出 → `languages/tailwind.md`
- Next.js/React + shadcn/ui 検出 → `languages/shadcn.md`

**インフラ（検出時のみ）**:
- Terraform → `infrastructure/terraform.md`
- Lambda → `infrastructure/aws-lambda.md`
- ECS/Fargate → `infrastructure/aws-ecs-fargate.md`
- EKS/Kubernetes → `infrastructure/aws-eks.md`
- EC2 → `infrastructure/aws-ec2.md`

**サブトピックキーワード検出時**: `~/.claude/references/guideline-triggers.md` を参照して該当1-2本のみ追加読込（Backend FW検出だけでの一括投入は禁止、トークン節約）。

### Step 3: 結果報告

検出結果を報告（カンマ区切りの検出言語 or `common`、モード `summary`/`full`）。

---

## モード2: Skill連携（requires-guidelines）

Skill frontmatter の `requires-guidelines` 識別子を skill実行時に自動読込（重複スキップ）。

### 識別子解決規約

基本: `~/.claude/guidelines/<category>/<id>.md` に解決。カテゴリは識別子から自動判定。

**例外（id → path）**:
- `common` → `common/code-quality-design.md`
- `ddd` → `design/domain-driven-design.md`
- `operations` → `operations/monitoring-runbook.md`

**カテゴリ判定**:
- `typescript|golang|nextjs-react|tailwind|shadcn|python|rust|eslint|go-test-stability|go-performance|go-concurrency` → `languages/`
- `terraform` → `infrastructure/terraform.md`、`kubernetes` → `infrastructure/aws-eks.md`
- `clean-architecture|ddd|async-job-patterns` → `design/`
- `database-performance|mysql-performance|caching-strategies|distributed-transactions|observability-design|security-hardening|scalability-patterns|event-driven-architecture|multi-tenancy` → `backend/`

---

## モード3: コマンド別 skill / agent 推奨

主要4コマンド（`/dev` `/plan` `/review` `/flow`）を活用する際、推奨される skill リストを以下に示す。

### `/dev` コマンド推奨

実装フェーズの skill:
- **UI開発時**: `ui-skills` - UI コンポーネント設計・Tailwind/shadcn 活用
- **Backend開発時**: `backend-dev` - API・ビジネスロジック実装
- **共通**: `simplify` - コード簡潔化、`cleanup-enforcement` - 品質・lint 違反検出

### `/plan` コマンド推奨

設計・計画フェーズの skill:
- `clean-architecture-ddd` - アーキテクチャ設計サポート
- `api-design` - API 仕様設計
- `microservices-monorepo` - マイクロサービス・モノレポ設計（該当時）
- `terraform` - IaC 計画・実装（インフラ計画時）
- `load-guidelines` - プロジェクト技術スタック検出

### `/review` コマンド推奨

コードレビューの skill:
- `comprehensive-review` - 総合レビュー（デフォルト）
- `uiux-review` - UI/UX 観点レビュー（UI 変更時）
- `cleanup-enforcement` - コード品質・スタイル違反チェック

### `/flow` コマンド推奨

タスクタイプ判定後の自動選択。主なパターン:
- **設計相談**: `clean-architecture-ddd`
- **インシデント/緊急対応**: `incident-response`
- **根本原因分析（RCA）**: `root-cause`
- **データ分析**: `data-analysis`
- **IaC 計画**: `terraform`

詳細なマッピングは `references/command-resource-map.md` を参照。

**読込方法**: 上記 skill が必要な場合は、個別に Skill ツール呼び出し、または Read で `skill.md` を参照。遅延読込パターン（トークン節約）を採用。
