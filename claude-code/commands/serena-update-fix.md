---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, mcp__serena__*
description: Serena MCP アップデート対応 - 差分検出・自動適用・未採用機能トラッキング
---

# /serena-update-fix

Serena local clone (`~/serena`) を更新し、CHANGELOG 差分に応じて claude-code 側の設定・ドキュメント・全 activate プロジェクトを追随させる。

## Phase 1: 差分検出

```bash
cd ~/serena && git pull --rebase --autostash               # main 同期
git tag --sort=-v:refname | head -1                         # 最新タグ
cat ~/ai-tools/claude-code/SERENA_VERSION                   # 確認済み
cat ~/ai-tools/claude-code/references/SERENA-OPPORTUNITIES.md 2>/dev/null
```

差分なし かつ Opportunity 未解決なし → 「最新確認済み」で終了。
差分なし かつ Opportunity あり → Phase 3-B のみ実行。
差分あり → Phase 2 へ。

## Phase 2: CHANGELOG 構造化抽出

`~/serena/CHANGELOG.md` から確認済み〜現行の区間を抽出。各エントリを下表のいずれかにタグ付け（複数可）。

| タグ | キーワード | 後段アクション |
|------|-----------|--------------|
| `RENAME` | removed, renamed, deprecated, Breaking change | → 3-1 |
| `TOOL` | Add new tools, tool 名 (`find_*`, `get_*`, `jet_brains_*` 等) | → 3-2 |
| `CONFIG` | project.yml, setting, `base_modes`, `added_modes`, `language_backend` | → 3-3 |
| `MCP` | start-mcp-server, --context, --project, CLI 引数 | → 3-4 |
| `LSP` | language server, LSP, `ls_specific_settings`, 言語追加 | → 3-5 |
| `CONTEXT` | context (claude-code, agent), mode 追加 | → 3-6 |

タグなし（bugfix/perf/JetBrains 専用等）→ 無視。

## Phase 3: 拡張ポイントマップ

| タグ | 検査対象 | 検出方法 |
|------|---------|---------|
| 3-1 RENAME | `agents/README.md` Serena ツール表、`agents/*.md` allowed-tools、`commands/*.md`、`CLAUDE.md` | 旧名を grep、新名に置換 |
| 3-2 TOOL | `agents/README.md` ツールカタログ、`agents/*.md` `allowed-tools: ... mcp__serena__*` | 新ツール: ツールカタログに追記、関連 agent の allowed-tools 確認 |
| 3-3 CONFIG | 全 activate プロジェクトの `.serena/project.yml` | 新キー: テンプレに追加提案。非推奨キー: 削除提案。schema breaking change は影響範囲を全プロジェクト grep |
| 3-4 MCP | `templates/.mcp.json.template`、`settings/mcp-servers/serena.json.template`、`claude mcp list` の user-scope 登録引数 | 起動引数変更: 両 template 更新 + user-scope 再登録案内 |
| 3-5 LSP | `.serena/project.yml` `languages:` / `ls_specific_settings:` | 言語追加: 該当プロジェクトで活用可能か確認 |
| 3-6 CONTEXT | `templates/.mcp.json.template` `--context` 値、`settings/mcp-servers/serena.json.template` 同 | context 名変更/追加: template 更新 |

### 3-B. Opportunity 再評価

`references/SERENA-OPPORTUNITIES.md` 各項目を再チェック。採用済み/陳腐化 → クローズ。未採用かつ有効 → 継続。

### Activate プロジェクト一覧取得

```bash
grep -A 50 "^projects:" ~/.serena/serena_config.yml | grep "^- /"
```

CONFIG タグで schema breaking change がある時、全プロジェクトの `.serena/project.yml` を一斉確認・更新。

## Phase 4: 適用（層別）

重要度: **Critical**（schema 不整合・起動失敗）> **Warning**（非推奨削除）> **Auto**（ツール名置換等の機械的修正）> **Opportunity**（新機能活用）> **Info**

| 層 | 対象 | 動作 |
|----|------|------|
| **自動適用** | Auto（ツール名 ID 置換、template 引数更新、SERENA_VERSION bump） | 確認なしで Edit 実行 |
| **確認適用** | Critical + Warning（schema 変更、user-scope 再登録など） | `AskUserQuestion` で 全適用 / 個別 / スキップ |
| **追跡のみ** | Opportunity + Info | `references/SERENA-OPPORTUNITIES.md` に追記 |

自動適用後、すべての変更を diff で出力してから確認適用へ進む。

## Phase 5: 終了処理

1. `SERENA_VERSION` を現行タグに更新
2. 接続検証: `claude mcp list` で `serena: ... ✓ Connected` 確認
3. `./sync.sh to-local --yes` 実行（template 変更があった場合のみ）
4. Opportunity 追跡ファイル更新（Phase 3-B 差分反映）
5. 3+ファイル変更 or 非自明判断あれば Serena memory に `serena-update-YYYYMMDD` で保存

## 注意

- `~/serena` は local clone（user-scope MCP の起動元）。`git pull` は `--rebase --autostash` 限定
- CHANGELOG が main の `# Unreleased` セクションを含む場合、リリース前変更は基本無視（次回タグリリース時に取り込み）。ただし Breaking change は即時追従検討
- `--version` 確認は `uv run --directory ~/serena serena --version`（警告抑制は `hooks/serena-hook.sh` 同様 `PYTHONWARNINGS=ignore` で対応可）
- v1.3.0+ で `serena-mcp-server` 廃止、`serena start-mcp-server` 必須
- user-scope MCP は `--project-from-cwd` 起動が前提（全 activate プロジェクトで Connected）。project-scope `.mcp.json` を配置する場合は `${PROJECT_ROOT}` 明示
