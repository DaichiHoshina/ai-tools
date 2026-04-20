---
allowed-tools: Read, Glob, Grep, Bash, Skill, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-reviewスキルで7観点統合レビュー）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで設計・品質・可読性・セキュリティ・ドキュメント/テスト・恒久対応・ログを統合レビュー

## 実行方法

| 引数 | 動作 |
|------|------|
| なし | `git diff` のローカル差分をレビュー |
| URL（http...） | `gh pr diff` / `glab mr diff` で差分取得→レビュー |
| 番号 | 現在リポジトリのMR/PR番号として差分取得→レビュー |
| `--focus=<観点>` | 指定観点のみレビュー（security等） |
| `--codex` | comprehensive-review + `codex review` 並列実行、結果統合 |
| `--devin` | Devin Reviewセカンドオピニオン（`npx devin-review {pr-url}`） |
| `--no-difit` | difit起動を抑制 |

**自動実行される内容**:

```
Skill("comprehensive-review")
```

comprehensive-reviewスキルが内部で以下を実行：

1. ガイドライン読み込み（load-guidelines）
2. 静的解析ツール（lint/tsc/go vet等）
3. cleanup-enforcement（未使用コード検出）
4. 7観点の統合レビュー（`--focus`で絞り込み可能）：
   - `--focus=architecture`（設計 — CA/DDD/依存関係）
   - `--focus=quality`（品質 — 型安全性・パフォーマンス・古いパターン）
   - `--focus=readability`（可読性 — 命名・構造・認知的複雑度）
   - `--focus=security`（セキュリティ — OWASP Top 10・エラーハンドリング）
   - `--focus=docs`（ドキュメント・テスト — 該当時）
   - `--focus=root-cause`（恒久対応 — 対症療法vs根本治療・パターン再発）
   - `--focus=logging`（ログ — レベル適切性・構造化・可観測性・機密保護）
5. uiux-review（UI変更時、別スキル）

> 各観点の詳細チェック項目は `comprehensive-review` スキル（`skills/comprehensive-review/SKILL.md`）を参照。

## 出力形式

```markdown
## 包括的レビュー結果
### 実行した観点
✅ architecture / quality / readability / security / docs / root-cause / logging

### 🔴 Critical（修正必須）
- [観点] 内容（ファイル:行）

### 🟡 Warning（要改善）
- [観点] 内容（ファイル:行）

Total: Critical N件 / Warning N件
```

## Codex統合（--codex）

comprehensive-review と `codex review --uncommitted` を**並列実行**し結果統合。

- 両方が指摘 → **確度高**（必ず修正）
- 片方のみ指摘 → 内容を精査して判断
- codex未インストール時（`which codex`で確認失敗）→ Codex部分スキップ

他モード: `codex review --base main` / `--commit HEAD`

## Devin統合（--devin）

on-demand でDevin Reviewを叩くセカンドオピニオン。auto-reviewは使わない。

**TTY要求の回避**: `devin-review` CLIは対話入力必須。`script -q /dev/null` でPTY偽装してClaudeから自動実行する。

手順:

1. PR URL確定（引数 or `gh pr view --json url -q .url`）
2. `expect` で対話プロンプト自動応答:

   ```bash
   expect -c '
     set timeout 600
     spawn npx --yes devin-review <PR_URL>
     expect {
       -re {Continue.*\(y/n\)} { send "y\r"; exp_continue }
       eof
     }
   ' 2>&1 | tee /tmp/devin-review.log
   ```

3. 完了後 `/tmp/devin-review.log` 読み取り → comprehensive-review と統合提示（両方指摘=確度高）
4. 初回認証のみユーザーに `! npx devin-review <URL>` で手動認証を依頼。以降は認証キャッシュ利用で完全自動

フォールバック: PTY実行失敗時は `devinreview.com/{owner}/{repo}/pull/{n}`（`github.com` 置換）をブラウザ案内。

## レビュー対象

含める: 変更ファイル（git diff）、新規追加ファイル
除外: auto-generated、vendor/node_modules、lockファイル

## レビュー方針

- **厳しめ**: レビュワーにapproveもらえる品質を目指す。見逃しより過検出を優先
- **差分のみ**: レビュー対象は変更差分に限定。既存コードへの指摘は行わない
- **大量の差分**: 1ファイルずつレビュー
- **優先度**: Critical → Warning の順で報告
- **具体的な修正案**: 問題指摘だけでなく改善方法も提示
- **並列実行がデフォルト**: 全7観点を並列で実行

## difit統合

ローカルレビュー（引数なし）時のみ、レビュー完了後に difit をバックグラウンド起動しブラウザで差分+コメント表示。`--no-difit`で抑制。要 `npm i -g difit`。

### コメントJSON形式

```json
{
  "type": "thread",
  "filePath": "src/domain/user.ts",
  "position": { "side": "new", "line": 45 },
  "body": "🔴 Critical: [設計] ...\n\n修正案: ..."
}
```

- body prefix: Critical → `🔴 Critical:` / Warning → `🟡 Warning:`
- 行番号不明時は `line: 1`
- 全findingを1つの `--comment '<JSON配列>'` で `difit staged` または `difit .` に渡す
