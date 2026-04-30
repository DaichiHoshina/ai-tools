---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
description: Claude Codeアップデート対応 - 差分検出・自動適用・未採用機能トラッキング
---

# /claude-update-fix

CLIアップデートに合わせてリポジトリを能動的に追随させる。低リスク修正は即適用、未採用機能は継続追跡。

## Phase 1: 差分検出

```bash
claude --version                                      # 現行
cat claude-code/VERSION                               # 確認済み
cat claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md 2>/dev/null  # 未採用機能（前回蓄積）
```

差分なし かつ Opportunity 未解決なし → 「最新確認済み」で終了。
差分なし かつ Opportunity あり → Phase 3-B（再評価）のみ実行。
差分あり → Phase 2 へ（Phase 3 で 3-B も再評価）。

## Phase 2: CHANGELOG構造化抽出

取得（優先順）:
1. `WebFetch`: `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`
2. `npm view @anthropic-ai/claude-code time` → バージョン↔日付マップ取得
3. `WebSearch`: "claude code changelog {バージョン}"

確認済み〜現行の区間を切り出し、各エントリを下表のいずれかにタグ付け（複数可）。

| タグ | キーワード（case-insensitive） | 後段アクション |
|------|---------------------------|--------------|
| `RENAME` | removed, renamed, deprecated | → 3-1 |
| `HOOK` | hook, event, PreCompact, PostCompact, SessionStart | → 3-2 |
| `SETTING` | setting, config, option, env var, permission | → 3-3 |
| `MODEL` | model, claude-sonnet, claude-opus, claude-haiku | → 3-4 |
| `TOOL` | tool, parameter, Task, Bash, Edit, EnterWorktree | → 3-5 |
| `SKILL` | skill, frontmatter, description 文字数 | → 3-6 |
| `COMMAND` | slash command, `/` 始まりの新コマンド名 | → 3-7 |

タグなし（UI/perf/bugfix等）→ 無視。

## Phase 3: 拡張ポイントマップ（固定対応表）

各タグに対し**決定的な検出位置**で grep/read を実行。見つかれば修正案を生成。

| タグ | 検査対象 | 検出方法 |
|------|---------|---------|
| 3-1 RENAME | `claude-code/agents/*.md`, `commands/*.md`, `skills/*/skill.md`, `CLAUDE.md`, `hooks/*.sh`, `templates/settings.json.template` | 旧名を grep、該当行を新名に置換 |
| 3-2 HOOK | `claude-code/hooks/*.sh`, `templates/settings.json.template` の `hooks` セクション | 新イベント: 未登録なら雛形作成提案。I/O変更: 既存hookの入出力 schema を grep |
| 3-3 SETTING | `claude-code/templates/settings.json.template`, `.claude/settings.json` | 新キー: テンプレに追加提案。非推奨: 削除提案 |
| 3-4 MODEL | `claude-code/CLAUDE.md`, `agents/*.md` frontmatter, `skills/*/skill.md`, `scripts/**/*.{sh,py}` | 旧モデルID を grep、全置換 |
| 3-5 TOOL | `claude-code/agents/*.md` の `allowed-tools:` / tool 一覧 | ツール名変更: 置換。新ツール: 該当エージェントで有用なら追記提案 |
| 3-6 SKILL | `claude-code/skills/*/skill.md` frontmatter | description 長さ制約等の新ルール検証 |
| 3-7 COMMAND | `claude-code/commands/*.md` のファイル名 vs built-in 新コマンド名 | ファイル名衝突: 接頭辞付与リネーム提案（`_custom` 等） |

### 3-B. Opportunity 再評価

前回の `CLAUDE-CODE-OPPORTUNITIES.md` 各項目について現状を再チェック。採用済み/陳腐化 → クローズ。未採用かつ有効 → 継続。

## Phase 4: 適用（層別）

重要度: **Critical**（衝突・破壊） > **Warning**（非推奨削除） > **Auto**（機械的置換） > **Opportunity**（新機能活用） > **Info**

| 層 | 対象 | 動作 |
|----|------|------|
| **自動適用** | Auto（モデル名ID 置換、deprecated option 削除、frontmatter キー順序正規化）+ VERSION bump | 確認なしで Edit 実行。本文表現・説明文の書き換えは対象外 |
| **確認適用** | Critical + Warning | `AskUserQuestion` で 全適用 / 個別 / スキップ |
| **追跡のみ** | Opportunity + Info | `references/CLAUDE-CODE-OPPORTUNITIES.md` に追記（実行はしない） |

自動適用後、すべての変更を diff で出力してからユーザーに確認適用へ進む。

## Phase 5: 終了処理（Phase 4 の確認適用完了後）

1. `claude-code/VERSION` を現行版に更新
2. `claude-code-version`（リポルート）も `@anthropic-ai/claude-code@<現行版>` に同期（Renovate 起点と整合）
3. `./claude-code/sync.sh to-local --yes` 実行（このタイミングのみ）
4. Opportunity 追跡ファイル更新（Phase 3-B の差分反映）
5. 大きな変更（3+ファイル or 非自明判断）があれば Serena memory に `claude-update-YYYYMMDD` で保存

## Opportunity 追跡フォーマット

`claude-code/references/CLAUDE-CODE-OPPORTUNITIES.md`:

```markdown
## <version> (YYYY-MM-DD 検出)
- [ ] **<機能名>**: <概要> — 検討箇所: <ファイル/エージェント>
```

- 採用時: チェック済みにしてコミットメッセージで参照
- 陳腐化: `~~<機能名>~~ (obsolete YYYY-MM-DD)` で打ち消し

## 注意

- `claude doctor` は対話型で不可。`claude --version` を使用
- CHANGELOG 取得失敗時: `claude --help` + npm view で最小限分析
- 自動適用は**必ず** git 差分で確認可能な範囲に留める（sync.sh 実行は確認適用後）
