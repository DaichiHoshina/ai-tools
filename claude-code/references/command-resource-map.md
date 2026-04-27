# 主要コマンド × リソース対応表

## 凡例

このマップは、主要4コマンド（`/dev` `/plan` `/review` `/flow`）の起動により、関連するすべてのリソース（skill、guideline、agent、hook、rule）を網羅できるかを可視化したもの。

| リソース種別 | 自動発火 | 備考 |
|-----------|---------|------|
| **rule** | 起動時自動適用 | `~/.claude/CLAUDE.md`、`~/.claude/rules/*.md`、`claude-code/CLAUDE.md`、`.claude/rules/*.md` から起動時に自動読み込み。改めて invoke 不要 |
| **hook** | settings.json 自動発火 | PreToolUse、PostToolUse、SessionStart、UserPromptSubmit、Stop、Notification イベント時に自動発火。改めて invoke 不要 |
| **agent** | Task ツール経由 | 親コマンドが `Task(subagent_type)` で起動。po-agent、manager-agent、developer-agent、reviewer-agent など |
| **skill** | 遅延読込 | Step 0 では skill 推奨リスト表示（テキストのみ、本体 read なし）。必要時に `Skill()` ツール呼び出し or 手動 Read |
| **guideline** | 技術スタック検出ベース | `load-guidelines` skill が自動検出実装。コマンド起動時に Step 0 で参照 |

---

## 主要4コマンド × リソース対応

### /dev - 実装モード

| リソース | 具体例・説明 |
|---------|-----------|
| **guideline** | **必須コア**: `common/code-quality-design.md` / 条件付き: TypeScript検出時 `languages/typescript.md`、Next.js検出時 `languages/nextjs-react.md`、Go検出時 `languages/golang.md` |
| **skill** | UI開発: `ui-skills`、Backend開発: `backend-dev`、共通: `simplify`、`cleanup-enforcement` |
| **agent** | なし（直接実行、Agent Team不使用） |
| **hook** | PreToolUse（ツール前）、PostToolUse（ツール後）で自動検証 |
| **rule** | genshijinモード、markdown ルール、エンタープライズセキュリティ、AI出力ルール（自動適用済み） |

**Step 0 内容**: 条件付きで `load-guidelines`（サマリーモード）実行。UI時は `ui-skills` 推奨リスト表示、Backend時は `backend-dev` 推奨リスト表示。詳細は `references/command-resource-map.md` 参照。

---

### /plan - 設計・計画モード

| リソース | 具体例・説明 |
|---------|-----------|
| **guideline** | **必須**: `design/clean-architecture.md`、`design/domain-driven-design.md` / 条件付き: Terraform検出時 `infrastructure/terraform.md`、Go検出時 `languages/golang.md` など |
| **skill** | 推奨: `clean-architecture-ddd`、`api-design`、`microservices-monorepo`（検出時）、`load-guidelines`、`terraform`（IaC計画時） |
| **agent** | po-agent（複雑な計画時） |
| **hook** | SessionStart（計画開始時）で自動トリガー |
| **rule** | genshijinモード、markdown ルール、git マージ禁止ルール（自動適用済み） |

**Step 0 内容**: 必須ガイドライン読み込み（A節）+ 言語別ガイドライン自動検出（B節）+ インフラ計画時ガイドライン（C節）+ Skill連携説明（D節）。`references/command-resource-map.md` への参照リンク追記。

---

### /review - レビューモード

| リソース | 具体例・説明 |
|---------|-----------|
| **guideline** | **必須**: `common/code-quality-design.md` / 条件付き: 言語・フレームワーク検出時に load-guidelines が自動読込 |
| **skill** | 推奨: `comprehensive-review`（メイン）、条件付き: `uiux-review`（UI時）、`cleanup-enforcement` |
| **agent** | reviewer-agent（PO/Manager経由時）、pr-review-toolkit:* 5種（--deep オプション時） |
| **hook** | PostToolUse（ファイル読み込み後）で自動フォーマットチェック |
| **rule** | AI出力ルール（自動適用済み、生成コメント禁止） |

**注**: comprehensive-review skill 内で `load-guidelines` 既存呼び出しあり。コマンド本体変更不要。

---

### /flow - 自動ワークフロー実行

| リソース | 具体例・説明 |
|---------|-----------|
| **guideline** | タスクタイプ判定後に対応 skill の guideline 読込（例：RCA判定時 `root-cause` skill が読込） |
| **skill** | タスクタイプに応じて動的選択。例: 設計相談 → `clean-architecture-ddd`、緊急対応 → `incident-response`、根本原因分析 → `root-cause`、データ分析 → `data-analysis`、IaC → `terraform` |
| **agent** | po-agent（Step 1: 設計相談時）→ manager-agent（Step 2: スケジュール作成）→ developer-agent×N（Step 3: 並列実装）→ reviewer-agent（最終レビュー） |
| **hook** | UserPromptSubmit（入力直後）でタスクタイプ自動判定、SessionStart でワークフロー初期化 |
| **rule** | genshijinモード、markdown ルール、git マージ禁止ルール、根本原因分析ルール（自動適用済み） |

**Step 0 内容**: 「Step 0: タスクタイプ判定後に対応する skill / agent を選択」と明記。判定表直前に配置。`references/command-resource-map.md` 参照リンク。

---

## 検証手順

### 静的検証

**リンク有効性確認（command-resource-map.md からの全参照先が存在するか）**:

```bash
grep -oE '\[.+?\]\([^)]+\)' claude-code/references/command-resource-map.md | \
  while read line; do
    path=$(echo "$line" | sed -E 's/.*\((.+)\)/\1/')
    if [[ ! "$path" =~ ^(http|/) ]]; then
      # 相対パスの場合 claude-code/ 基点で存在確認
      test -e "claude-code/$path" || echo "BROKEN: $path"
    fi
  done
```

**Markdown 構文チェック**:

```bash
mdl claude-code/references/command-resource-map.md
```

### 動的検証

実セッションでの確認:

1. **`/dev "テスト用ダミータスク"`** 実行 → Step 0 で skill 推奨リスト表示されるか
2. **`/flow "テスト用ダミータスク"`** 実行 → Step 0 で skill 推奨リスト表示されるか
3. **`/plan "テスト用ダミータスク"`** 実行 → Step 0 末尾に `command-resource-map.md` 参照あるか
4. **`/review`** 実行 → comprehensive-review skill 内で既存通り `load-guidelines` が呼ばれるか

### リソース網羅確認

対象ファイル: `commands/{dev,flow,plan,review}.md`、`skills/load-guidelines/SKILL.md`

```bash
# 行数確認（トークン節約原則準拠: コマンド150行以内、skill 300行以内）
wc -l claude-code/commands/{dev,flow,plan,review}.md
wc -l claude-code/skills/load-guidelines/SKILL.md
```

---

## 関連リファレンス

- `references/design-phase-flow.md` - 設計フェーズ遷移（brainstorm→prd→design-doc→plan）
- `references/flow-vs-groove.md` - `/flow` vs `/groove` 使い分け
- `references/natural-language-triggers.md` - 自然言語トリガー全リスト
