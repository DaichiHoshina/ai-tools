# Cursor 設定メンテナンス

Cursor IDE 設定を定期的に見直し、エージェント体験の劣化を防ぐチェックリスト。

**推奨頻度**: 月1回、または `/retrospective` 実行時に併走。

---

## クイック実行

```bash
# 1. 差分確認（symlink 運用でもローカル直編集の検出に使う）
cd ~/ai-tools/cursor && ./sync.sh diff

# 2. 監査（Claude Code）
/cursor-review

# 3. セッション振り返り + Cursor 改善案（Claude Code）
/retrospective
```

---

## 月次チェックリスト

### A. User 設定 (`cursor/User/`)

| # | 確認項目 | 合格基準 |
|---|----------|----------|
| A1 | `sync.sh diff` が空 | リポジトリとローカルが一致 |
| A2 | マシン固有値がない | アカウント名・絶対パス・トークンが含まれない |
| A3 | 非推奨キーがない | Cursor / VS Code 更新で deprecated になった設定を除去 |
| A4 | format on save が意図通り | 主要言語ごとに formatter が設定されている |
| A5 | watcher 除外が過不足ない | `node_modules` 等は除外、必要な path は監視対象 |

### B. キーバインド (`keybindings.json`)

| # | 確認項目 | 合格基準 |
|---|----------|----------|
| B1 | 衝突がない | 同一キーに複数 command が割り当てられていない |
| B2 | 未使用バインドの整理 | 3 か月使っていないショートカットは削除候補 |

### C. グローバル rules (`cursor/rules/`)

| # | 確認項目 | 合格基準 |
|---|----------|----------|
| C1 | `alwaysApply: true` は最小限 | 1–2 ファイルに収まる共通ルールのみ |
| C2 | Claude Code ルールと矛盾しない | commit 方針・言語・品質基準が一致 |
| C3 | 陳腐化していない | 参照 path（`~/ai-tools/...`）が現行構成と一致 |

### D. 推奨拡張 (`recommendations/extensions.json`)

| # | 確認項目 | 合格基準 |
|---|----------|----------|
| D1 | 未使用拡張がない | 3 か月起動していない拡張は削除候補 |
| D2 | バージョン互換 | Cursor 本体更新後に主要拡張が動作する |
| D3 | 重複機能がない | 同種 linter / formatter が二重インストールされていない |

```bash
./install-extensions.sh   # 推奨拡張の再適用（任意）
```

### E. プロジェクト memories (`.cursor/memories/`)

| # | 確認項目 | 合格基準 |
|---|----------|----------|
| E1 | 日付・参照が最新 | `更新:` 行が 90 日以内、または内容が現行と一致 |
| E2 | rules と矛盾しない | memory の方針が `rules/` や `ai-tools-agent.mdc` と食い違わない |
| E3 | 重複がない | 同テーマの memory が複数ファイルに分散していない |
| E4 | 秘匿情報がない | トークン・社内 URL・個人名が含まれていない |

### F. 同期・インストール

| # | 確認項目 | コマンド |
|---|----------|----------|
| F1 | symlink が生きている | `ls -la ~/Library/Application\ Support/Cursor/User/settings.json` |
| F2 | rules symlink | `ls -la ~/.cursor/rules/` |
| F3 | 別マシン反映手順が通る | `git pull && ./install.sh` |

---

## 改善フロー

```
問題検出
  ├─ 設定値の修正     → cursor/User/ 編集 → sync.sh diff 確認 → commit
  ├─ ルールの修正     → cursor/rules/ または .cursor/rules/ 編集 → commit
  ├─ memory 整理      → .cursor/memories/ 統合・更新 → commit
  └─ 体系監査         → /cursor-review（3 軸自動分析）
```

**適用前**: ユーザー確認必須（`/cursor-review --apply` も同様）。

---

## 手段の役割分担

| 手段 | 用途 | 頻度 |
|------|------|------|
| 本チェックリスト | 人手での網羅確認 | 月1 |
| `/cursor-review` | 矛盾・冗長・陳腐化の自動検出 | 月1 または設定変更後 |
| `/retrospective` | セッション履歴から Cursor friction を抽出 | 週1 |

---

## 記録

改善を適用したら `.cursor/memories/` または commit message に理由を残す。

---

## 関連

- 設定同期: [`README.md`](README.md)
- 監査コマンド: [`../claude-code/commands/cursor-review.md`](../claude-code/commands/cursor-review.md)
- 振り返り: [`../claude-code/commands/retrospective.md`](../claude-code/commands/retrospective.md)
