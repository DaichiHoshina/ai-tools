---
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, mcp__serena__*
description: Claude Codeアップデート対応 - バージョン差分検出・衝突分析・修正提案
---

# /claude-update-fix - Claude Codeアップデート対応

## Phase 1: バージョン差分検出

並列実行:

```bash
claude --version                # CLIバージョン
cat claude-code/VERSION         # 確認済みバージョン
```

差分なし → 「最新確認済み」で終了。差分あり → Phase 2へ。

## Phase 2: CHANGELOG取得・解析

取得（優先順）:
1. `WebFetch`: https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md
2. `WebSearch`: "claude code changelog {バージョン}"
3. `npm view @anthropic-ai/claude-code`

確認済み〜現在バージョン間の変更を抽出。以下のカテゴリに分類:

| カテゴリ | キーワード |
|---------|-----------|
| 新コマンド | command, slash command |
| 新/変更Hook | hook, event, PreCompact, PostCompact |
| 新設定 | setting, config, option |
| 破壊的変更 | breaking, removed, deprecated |
| モデル変更 | model, claude-sonnet, claude-opus |
| ツール変更 | tool, parameter, EnterWorktree |
| スキル仕様変更 | skill, description, frontmatter |

## Phase 3: アクティブ適応分析

各カテゴリについて**具体的な検出→修正案生成**を実行:

### 3-1. コマンド名衝突チェック

```bash
# 現在のbuilt-inコマンド一覧を取得
claude --help 2>&1
```

- `commands/*.md` の各ファイル名と照合
- 衝突あり → **Critical**: リネーム案を生成（例: `review.md` → `custom-review.md`）

### 3-2. Hook互換性チェック

CHANGELOGから抽出したHook変更について:

| 変更種別 | 検出 | アクション |
|---------|------|-----------|
| 新Hookイベント追加 | `hooks/` に対応スクリプトがない | 有用なら新hookスクリプト作成案を生成 |
| Hook入出力変更 | 既存hookの入出力と不一致 | 既存hookスクリプトの修正案を生成 |
| Hook新機能（decision blocking等） | 既存hookで活用可能か判定 | 活用案を生成（Info扱い） |
| Hook非推奨/削除 | `hooks/*.sh` + `templates/settings.json.template` でgrep | **Warning**: 該当hookの修正/削除案 |

### 3-3. 設定・テンプレート更新チェック

```bash
# 現在のsettingsテンプレートを確認
cat claude-code/templates/settings.json.template
```

- 新設定項目 → テンプレートへの追加案を生成
- 非推奨設定 → テンプレートからの削除案を生成

### 3-4. モデル名変更チェック

CHANGELOGにモデル変更がある場合:

```bash
# 旧モデル名の使用箇所を検索
grep -r "旧モデル名" claude-code/agents/ claude-code/CLAUDE.md claude-code/skills/
```

- 該当あり → 置換案を生成

### 3-5. 非推奨・削除機能チェック

```bash
# 非推奨/削除された機能名でリポジトリ全体をgrep
grep -r "非推奨機能名" claude-code/
```

- 該当あり → 削除/代替案を生成

### 3-6. スキル仕様変更チェック

- frontmatter制約変更（description文字数上限等）→ `skills/*/skill.md` の更新案
- 新パラメータ追加 → 活用案（Info扱い）

## Phase 4: 修正実行

### Step 1: 修正案一覧を重要度順に出力

重要度: **Critical**（衝突・破壊） > **Warning**（非推奨） > **Opportunity**（活用可能） > **Info**（参考のみ）

各項目に番号を振り、ファイルパス・変更内容・Before/Afterを明記。

### Step 2: ユーザー確認

AskUserQuestion: 全適用 / Critical+Warningのみ / 個別選択（番号） / VERSION更新のみ

### Step 3: 修正適用 → VERSION更新 → sync

Edit/Writeで修正適用後、`claude-code/VERSION` 更新 + `./claude-code/sync.sh to-local` 実行。

## Phase 5: 変更記録

Serena memoryに更新サマリを保存（`claude-update-YYYYMMDD`）:

保存内容:
- 旧→新バージョン
- 適用した修正の一覧
- 未対応のOpportunity項目（後日検討用）

## 注意事項

- `claude doctor` は対話的で使えない場合あり。`claude --version` を主に使用
- 修正実行は必ずユーザー確認後
- VERSION更新は全修正完了後
- CHANGELOGが取得できない場合、`claude --help` + ローカル情報で分析可能
