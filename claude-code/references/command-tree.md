# Command / Skill Tree (全体見取り図)

全 command (`commands/*.md`) と全 skill (`skills/*/`) の位置関係を 1 file に収めた単一 SoT。作業 flow の幹 1 本と、検証 / 知識 / 保守の 3 根で構成する。詳細 (遷移条件 / resource 対応 / trigger 語) は各 doc に残し、本 file は全体像のみを持つ。

**記法 rule**: command / skill 名は必ず code span (`` `name` ``) で書く。`tests/unit/command-tree-coverage.bats` が、全 command / skill 名の code span 登場を検査する。素の文中言及 (review / flow 等の一般語) は登録として数えない。

## 作業の幹 (設計 → 実装 → 出荷)

### 上流: 設計フェーズ

要求の曖昧さに応じて入口を選び、下流へ流す。遷移条件の詳細は `design-phase-flow.md` を参照する。

- `/brainstorm` — 発散し、対話で要求を絞る (`--debate` で賛否 2 agent)
- `/fact-check` — 案の主張を grep / wc で実測と突き合わせ、採否を判定する
- `/grill` — 確定前の設計案を詰問し、前提の穴を出す (read-only)
- `/prd` — 要件定義 (11-persona review)
- `/design-doc` — 設計判断を team 共有する doc (12-section)
- 設計 skill (直接起動も可): `mino-problem-framing` (問題定義) → `mino-domain-model-completeness` (モデル監査) / `mino-design-by-contract` (契約化) / `mino-interface-implementation-separation` (境界監査) / `mino-architecture-quality-strategy` (system-wide 品質)。router は `mino-reproducible-development`、共通基盤は `mino-core`、設計原則は `clean-architecture-ddd`
- 相談: `/fable` — 難所だけ上位 model に助言を求める (定義 file 方針相談は `--consult`)

### 中央 hub: `/plan`

設計確定後の Phase 分解と実行 mode 判定 (Step 2) を担う。簡易判定だけなら `/mode` を使う (inline / agent 並列の 2 択、判定後そのまま実装)。Step 0 の guideline 読込は `load-guidelines` が担う。

`/plan` Step 2 が選ぶ実装 mode:

- inline — 親が直接 Edit する (1 file / 数行、または 3+ file でも各数行)
- `/dev` — developer-agent へ 1 委譲する (1-2 file 単発、または結合の強い 3+ file を直列)
- `/workflow` — deterministic な fan-out / pipeline (7 template: review / migrate / research / understand / judge-panel / scan / loop-until-dry)
- `/flow` — PO / Manager / Dev 階層 + 3 Gates (`--auto` で PR まで全自動、`--parallel` で worktree 並列)
- `/goal` — objective gate (exit code) 到達まで maker-checker で反復する (session 内短期)
- `/loop` — external headless loop (定期実行 / 無人 / >5 iter)
- 実装補助: `/refactor` — 既存 code を再構成する

実装中の葉 skill: `context7` (library API の最新 doc 取得) / `code-comment` (comment 品質)。UI は `frontend-design` + `baseline-ui`、tech-stack 別 guideline は `terraform` / `grpc-protobuf` / `container-ops` が担う。

### 下流: 出荷フェーズ

- `/review` — code review する (skill 実体: `comprehensive-review`。UI 評価は `uiux-review`)
- `/review-fix-push` — review → fix → 回帰確認 → push を一括で回す
- `/git-push` — commit + push + PR 作成 (`--pr`)。ai-tools の live 反映は `sync-to-local` が担う

## 検証の根

実装物の品質を確かめる独立系で、幹のどの段階からも呼べる。

- `/lint-test` — lint + test を一括で回す
- `/verify-once` — DoD bundle を 1 発で検証する
- `/test` — test を実行 / 追加する
- `/design-review` — Playwright で live UI/UX を評価する
- `/brushup` — 対象 file の自己レビューを収束まで反復する
- `/jp-fix` — 日本語出力の品質を直す (skill 実体: `jp-fix`)
- 障害時は `/diagnose` (debug 支援) → skill `root-cause` (5 Whys) の順で掘る。本番障害は `incident-response` を使う

## 知識・出力の根

作業成果の退避と共有を担う。出力先の使い分けは `work-output-routing.md` を参照する。

- `/docs` — Notion へ知識を退避する
- `/post-comment` — GitHub issue / PR へ進捗を報告する
- skill `local-docs` — 調査ログ / RCA を local HTML 化する (整理は `local-docs-cleanup`)
- `/memory-save` — auto-memory へ即時保存する (`/memory-clean` で整理する)
- `/promote` — memory 知見を CLAUDE.md / skill へ昇格する
- `/retrospective` — session を振り返り、改善を提案する
- `/onboard` — project 初回の context を収集して memory 化する
- `/reload` — compaction 後に CLAUDE.md + memory を再読込する

## 保守の根

config / 環境自体の手入れを担う。

- `/audit` — 設定を監査する
- `/analytics` — 利用実績を分析する
- `/claude-update-fix` / `/serena-update-fix` — tool update へ追随する
- `/cursor-review` — Cursor 設定を監査する
- `/skill-add` — skill を新設する (skill-creator → lint → sync)
- `/update-guidelines` — guideline の鮮度と冗長性を点検する
- `/sleep-review` — 夜間 pipeline の提案を朝に仕分けする
- `/protection-mode` — 操作単位の safety を守る (幹の全操作に横断適用)

## 直接起動 skill (command を経ない入口)

- `natural-japanese` — 日本語文書の自然さを直し、AI 臭を除く
- `impact-analysis` — 影響範囲を分析する (「影響分析して」)
- `issue-dev-flow` — issue 起点の開発 flow を回す (「issueベースで開発」)
- `chain-pr-update` — stacked PR chain を最新 main へ順に伝播する (「chain 更新」)
- `pr-review-digest` — 自分の PR への他者レビューを日次集約する (「PR コメント digest」)

## 詳細 pointer

| 知りたいこと | 参照先 |
|---|---|
| 設計フェーズの遷移条件 / skip 判断 | `design-phase-flow.md` |
| command ごとの rule / skill / agent 対応 | `command-resource-map.md` |
| 自然言語 trigger の全 list | `natural-language-triggers.md` |
| 実行 mode の判定表本体 | `commands/plan.md` Step 2 |
| /workflow と /flow の比較 | `commands/workflow.md` |
