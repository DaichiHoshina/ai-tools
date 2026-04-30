# スキル依存関係マップ

全21スキルの依存関係と推奨組み合わせ。各 skill の詳細は `skills/<name>/SKILL.md` 参照。

> **関連**: [QUICKSTART.md](QUICKSTART.md) | [SKILLS-USAGE.md](SKILLS-USAGE.md) | [COMMANDS-GUIDE.md](COMMANDS-GUIDE.md)

## カテゴリ別一覧

### レビュー系（3）

| skill | パラメータ | requires-guidelines | often-used-with |
|-------|-----------|---------------------|-----------------|
| comprehensive-review | `--focus={all\|architecture\|quality\|security\|...}` (11観点) | common, clean-architecture, ddd | - |
| uiux-review | - | common, nextjs-react, tailwind, shadcn | ui-skills, react-best-practices |
| ui-skills | - | nextjs-react, tailwind, shadcn | uiux-review, react-best-practices |

### 開発系（5）

| skill | パラメータ | requires-guidelines | often-used-with |
|-------|-----------|---------------------|-----------------|
| backend-dev | `--lang={auto\|go\|typescript\|python\|rust}` | common + 言語別 | api-design, clean-architecture-ddd |
| react-best-practices | - | nextjs-react | ui-skills, uiux-review |
| api-design | - | common, clean-architecture | backend-dev, grpc-protobuf |
| clean-architecture-ddd | - | common, clean-architecture, ddd | backend-dev, microservices-monorepo |
| grpc-protobuf | - | golang, common | backend-dev, api-design |

### インフラ系（3）

| skill | パラメータ | requires-guidelines | often-used-with |
|-------|-----------|---------------------|-----------------|
| container-ops | `--platform={auto\|docker\|kubernetes\|podman}`, `--mode={auto\|troubleshoot\|best-practices\|deploy}` | common (+kubernetes) | terraform |
| terraform | - | terraform, common | container-ops |
| microservices-monorepo | - | common, clean-architecture, ddd | container-ops, clean-architecture-ddd, grpc-protobuf |

### ユーティリティ（10）

| skill | requires-guidelines | often-used-with |
|-------|---------------------|-----------------|
| load-guidelines | - | 全 skill（前提） |
| cleanup-enforcement | common | comprehensive-review, 開発系全般 |
| mcp-setup-guide | - | - |
| session-mode | - | - |
| context7 | - | backend-dev, react-best-practices |
| data-analysis | common | - |
| techdebt | common, clean-architecture | cleanup-enforcement |
| incident-response | operations | comprehensive-review, root-cause |
| root-cause | common, clean-architecture | incident-response |
| architecture-diagram | - | clean-architecture-ddd, microservices-monorepo |

## 推奨組み合わせ

| シーン | スキル組み合わせ |
|-------|----------------|
| フルレビュー | `comprehensive-review --focus=all` |
| Go バックエンド開発 | `backend-dev --lang=go` + `clean-architecture-ddd` + `api-design` |
| TypeScript バックエンド | `backend-dev --lang=typescript` + `api-design` |
| React/Next.js | `react-best-practices` + `ui-skills` + `uiux-review` |
| コンテナ調査 | `container-ops --mode=troubleshoot` |
| インフラ全体 | `container-ops` + `terraform` |
| インシデント | `incident-response` + `root-cause` |

## スキル選択フロー

```
タスク開始
  ↓
レビュー系? → Yes → /skill comprehensive-review
  ↓ No
技術スタック検出済み? → No → /load-guidelines
  ↓ Yes
問題タイプ
  ├ バックエンド → backend-dev
  ├ フロント → react-best-practices, ui-skills
  ├ コンテナ → container-ops
  ├ API → api-design
  ├ UI/UX → uiux-review
  ├ インフラ → terraform, container-ops
  └ エラー・障害 → incident-response, root-cause
```

## 自動推奨の優先順位

`user-prompt-submit.sh` が以下順で検出して systemMessage で推奨スキルを表示:

1. エラーログ検出（最優先・問題解決）
2. ファイルパス検出（変更箇所推論）
3. Git状態検出（ブランチ名・コミット履歴）
4. キーワード検出（プロンプト内容）

## 廃止スキル（後方互換）

`detect-from-*.sh` が自動的に新スキル名+パラメータに変換。

| 旧名 | 新名 |
|------|------|
| code-quality-review | `comprehensive-review --focus=quality` |
| security-error-review | `comprehensive-review --focus=security` |
| docs-test-review | `comprehensive-review --focus=docs` |
| go-backend | `backend-dev --lang=go` |
| typescript-backend | `backend-dev --lang=typescript` |
| docker-troubleshoot | `container-ops --platform=docker --mode=troubleshoot` |
| kubernetes | `container-ops --platform=kubernetes` |

詳細: [SKILL-MIGRATION.md](./SKILL-MIGRATION.md)
