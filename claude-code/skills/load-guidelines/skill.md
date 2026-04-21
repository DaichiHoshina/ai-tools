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

**規約**: 検出した言語の `languages/{id}.md`、検出したインフラの `infrastructure/{id}.md` を追加読込。共通は `common/*.md` 全件。

**例外（追加読込）**:
- TypeScript + ESLint 検出 → `languages/eslint.md` 追加
- Go 検出 → `languages/go-test-stability.md` 追加
- Next.js/React 検出 + Tailwind → `languages/tailwind.md`
- Next.js/React 検出 + shadcn/ui → `languages/shadcn.md`

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
- `terraform|kubernetes` → `infrastructure/`
- `clean-architecture|ddd|async-job-patterns` → `design/`
- `database-performance|mysql-performance|caching-strategies|distributed-transactions|observability-design|security-hardening|scalability-patterns` → `backend/`
