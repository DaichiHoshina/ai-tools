# スキル一覧・使い分け（SKILLS-MAP）

全21スキルの依存関係・使い分け・自動選択の仕組み。各 skill 詳細は `skills/<name>/SKILL.md`。

> **関連**: [QUICKSTART.md](QUICKSTART.md) | [COMMANDS-GUIDE.md](COMMANDS-GUIDE.md)

## 原則: 自動選択に任せる

ほとんどのスキルは**自動選択**される。明示指定は不要。

- **UserPromptSubmit Hook**: プロンプトから技術スタック自動検出
- **`/review` コマンド**: 問題タイプに応じてスキル選択
- **`requires-guidelines`**: スキル実行時に関連ガイドライン自動読込

明示指定が必要なケース: 自動検出されない専門領域（data-analysis, context7）/ 特定レビュー観点のみ（uiux-review）/ 設定・運用（mcp-setup-guide, session-mode）。

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

詳細: [SKILL-MIGRATION.md](./tutorials/SKILL-MIGRATION.md)

## skill-lint（品質検証）

`scripts/skill-lint.sh` で `skills/*/SKILL.md` の frontmatter 検証。

```bash
./claude-code/scripts/skill-lint.sh                 # 全スキル
./claude-code/scripts/skill-lint.sh --skill <name>  # 単一
./claude-code/scripts/skill-lint.sh --strict        # warning も exit 1（push 前 hook 用）
```

検査項目: `name` 必須+ディレクトリ名一致 / `description` 必須・30〜200字 / トリガー語（`〜時`、`使用`、`Use this`等）/ `requires-guidelines` 配列形式。

## skill-eval（発火率計測）

`scripts/skill-eval.sh` で `~/.claude/projects/*/*.jsonl` から Skill ツール発火回数を集計、死蔵スキル可視化。

```bash
./claude-code/scripts/skill-eval.sh             # 直近30日
./claude-code/scripts/skill-eval.sh --all       # 全期間
./claude-code/scripts/skill-eval.sh --unused    # 死蔵のみ
./claude-code/scripts/skill-eval.sh --skill <name>
```

注: Skill ツール明示呼び出しのみカウント。コマンド経由（`/dev` 等）の暗黙呼び出しは別計測。

## 新規スキル追加

`/skill-add <name>` で skill-creator → skill-lint → 同期を一括実行。詳細: `commands/skill-add.md`。

## ベストプラクティス

```
# NG: スキル列挙
backend-dev --lang=go、api-design、clean-architecture-dddで

# OK: 自動選択
/dev ユーザー認証APIを実装して
```

`/load-guidelines` は毎セッション推奨（軽量サマリのみ、必要に応じ `full`）。
