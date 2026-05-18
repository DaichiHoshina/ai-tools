# ガードレール

操作を3層（Safe/Boundary/Forbidden）に分類し、安全性を保証。

## 操作ガード

```
Guard : Action → {Allow, AskUser, Deny}
Guard(a) = Allow   ⟺ a ∈ Mor(Safe)
Guard(a) = AskUser ⟺ a ∈ Mor(Boundary)
Guard(a) = Deny    ⟺ a ∈ Mor(Forbidden)
```

安全性定理: Safeは常に安全 / Boundaryは承認で安全 / Forbiddenは実行不可。

| 層 | 処理 | 説明 |
|----|------|------|
| **Safe** | 即実行 | 害のない操作 |
| **Boundary** | 確認後実行 | 影響あり（モードで確認レベル変化） |
| **Forbidden** | 実行不可 | 危険、常に拒否 |

## Safe（自動許可）

- ファイル読取、コード分析・検索、ディレクトリ一覧
- 提案・説明、コードレビュー（読取のみ）、ドキュメント参照
- git status / log / diff、環境情報確認

## Boundary（確認必要、モード別）

### Git操作

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| git add | 確認 | 自動 | 自動 |
| git commit | 確認 | 確認 | 自動 |
| git push | 確認 | 確認 | 確認 |
| git merge | 確認 | 確認 | 確認 |
| git rebase（ローカル） | 確認 | 確認 | 自動 |

### ファイル操作

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| 編集 | 確認 | 自動 | 自動 |
| 作成 | 確認 | 自動 | 自動 |
| 通常削除 | 確認 | 確認 | 自動 |
| 重要削除 | 確認 | 確認 | 確認 |

重要ファイル: `src/`, `.git/`, `node_modules/`, `.env`, `package.json`, `go.mod` 等。

### パッケージ管理

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| npm install（安全） | 確認 | 自動 | 自動 |
| npm install（未知） | 確認 | 確認 | 確認 |
| go get | 確認 | 自動 | 自動 |

安全パッケージ: 高DL数 + 活発メンテ + 既知脆弱性なし。

### 設定変更

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| .env変更 | 確認 | 確認 | 確認 |
| package.json | 確認 | 確認 | 自動 |
| tsconfig.json | 確認 | 自動 | 自動 |
| Dockerfile | 確認 | 確認 | 自動 |

## ❗️禁止事項（Hooks自動検出）

| 禁止 | 理由 |
|------|------|
| format | prettier/eslint/go fmtはユーザー実行 |
| commit | AI自動実行禁止（/git-push使用） |
| auto_test | テスト自動作成禁止（テンプレ提案は可） |
| unused | 「念のため」コード禁止（YAGNI） |

## 📊 品質基準

| メトリクス | 基準 |
|-----------|------|
| 関数サイズ | 50行以下 |
| 引数 | 3個以下 |
| 循環的複雑度 | 10以下 |
| ネスト | 3段以下 |

## Forbidden（実行不可、全モード拒否）

- **システム破壊**: `rm -rf /`, `dd if=/dev/zero of=/dev/sda`, `kill -9 -1`, `shutdown -h now`, `mkfs.*`
- **セキュリティ**: `chmod 777 -R /`, 秘密情報漏洩、認証情報公開、`.env` コミット、secrets push
- **Git危険**: `git push --force` / `git reset --hard` リモート / `git clean -fdx`
- **外部接続**: `curl | bash`, `wget | sh`, ユーザー入力の任意コード評価
- **YAGNI違反**: 未使用コード生成 / 「念のため」「将来使うかも」の実装

## 確認フロー

```
strict: Boundary 全て確認 → 通知音 → 承認待ち → 実行
normal: 重要 Boundary のみ確認、その他は自動
fast:   最重要 Boundary のみ確認、Forbidden は拒否、その他は自動
```

通知: 確認時 / 完了時に `afplay ~/notification.mp3`。

## 例外処理

- Boundary拒否時: 理由説明 → 代替案 → 必要なら `/protection-mode` で思考法再確認
- Forbidden検出時: 即拒否 → 危険性説明 → 安全な代替手段提案

## 関連

- `session-modes.md` - モード定義
- `/protection-mode` - 圏論的思考法ロード
- `claude-code/references/AI-THINKING-ESSENTIALS.md` - 5フェーズワークフロー含む
