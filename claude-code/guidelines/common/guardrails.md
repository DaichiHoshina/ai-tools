# ガードレール

操作を3層（Safe/Boundary/Forbidden）に分類し、安全性を保証。

---

## Guard関手（圏論的定義）

```
Guard : Action → {Allow, AskUser, Deny}

Guard(a) = Allow   ⟺ a ∈ Mor(Safe)
Guard(a) = AskUser ⟺ a ∈ Mor(Boundary)
Guard(a) = Deny    ⟺ a ∈ Mor(Forbidden)
```

**安全性定理**:
- Safe圏は常に安全: `∀f ∈ Mor(Safe), ¬causes_harm(f)`
- Boundary圏はユーザー承認で安全: `user_approval(f) ⟹ ¬causes_harm(f)`
- Forbidden圏は実行不可能: `f ∉ Mor(Claude圏) ⟹ ¬executable(f)`

---

## 3層分類

| 層 | 処理 | 説明 |
|---|------|------|
| **Safe** | 即座に実行 | 害のない操作 |
| **Boundary** | 確認後に実行 | 影響がある操作（モードにより確認レベル変化） |
| **Forbidden** | 実行不可 | 危険な操作（常に拒否） |

---

## Safe（自動許可）

**害のない操作。即座に実行可能。**

### ファイル操作
- ファイル読み取り
- コード分析・検索
- ディレクトリ一覧

### 開発支援
- 提案・説明
- コードレビュー（読み取りのみ）
- ドキュメント参照

### 情報取得
- git status / log / diff（読み取り系）
- 環境情報の確認

---

## Boundary（確認必要）

**影響がある操作。モードに応じて確認レベルが変化。**

### Git 操作

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
| ファイル編集 | 確認 | 自動 | 自動 |
| ファイル作成 | 確認 | 自動 | 自動 |
| 通常ファイル削除 | 確認 | 確認 | 自動 |
| 重要ファイル削除 | 確認 | 確認 | 確認 |

**重要ファイル**: src/, .git/, node_modules/, .env, package.json, go.mod 等

### パッケージ管理

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| npm install（安全） | 確認 | 自動 | 自動 |
| npm install（未知） | 確認 | 確認 | 確認 |
| go get | 確認 | 自動 | 自動 |

**安全なパッケージ**: 高ダウンロード数、活発なメンテナンス、既知の脆弱性なし

### 設定変更

| 操作 | strict | normal | fast |
|------|--------|--------|------|
| .env 変更 | 確認 | 確認 | 確認 |
| package.json 変更 | 確認 | 確認 | 自動 |
| tsconfig.json 変更 | 確認 | 自動 | 自動 |
| Dockerfile 変更 | 確認 | 確認 | 自動 |

---

---

## ❗️ 禁止事項（Hooks自動検出）

| 禁止 | 理由 |
|------|------|
| format | prettier, eslint, go fmt はユーザーが実行 |
| commit | AI自動実行禁止（/commit-push-pr使用） |
| auto_test | テスト自動作成禁止（テンプレ提案は可） |
| unused | "念のため"のコード禁止（YAGNI） |

---

## 📊 品質基準

| メトリクス | 基準 |
|-----------|------|
| 関数サイズ | 50行以下 |
| 引数の数 | 3個以下 |
| 循環的複雑度 | 10以下 |
| ネスト | 3段以下 |

---

## Forbidden（実行不可）

**危険な操作。すべてのモードで拒否。**

### システム破壊
- `rm -rf /`
- `dd if=/dev/zero of=/dev/sda`
- `kill -9 -1`
- `shutdown -h now`（許可なし）
- `mkfs.*`（許可なし）

### セキュリティ問題
- `chmod 777 -R /`
- 秘密情報の漏洩（leak(secrets)）
- 認証情報の公開（expose(credentials)）
- .env のコミット
- secrets の push

### Git 危険操作
- `git push --force`（許可なし）
- `git reset --hard`（リモート、許可なし）
- `git clean -fdx`（許可なし）

### 外部接続危険
- `curl | bash`（許可なし）
- `wget | sh`（許可なし）
- `eval($(curl ...))`

### YAGNI 違反
- 未使用コードの生成
- 「念のため」の実装
- 「将来使うかも」の実装

---

## 確認フロー

### strict モード
```
操作検出 → Boundary? → Yes → 確認音 → ユーザー承認待ち → 実行
                    → No  → Safe? → Yes → 即座に実行
                                  → No  → Forbidden → 拒否
```

### normal モード
```
操作検出 → 重要Boundary? → Yes → 確認音 → ユーザー承認待ち → 実行
                        → No  → Boundary? → Yes → 即座に実行
                                          → No  → Safe? → Yes → 即座に実行
                                                        → No  → Forbidden → 拒否
```

### fast モード
```
操作検出 → 最重要Boundary? → Yes → 確認音 → ユーザー承認待ち → 実行
                          → No  → Forbidden? → Yes → 拒否
                                             → No  → 即座に実行
```

---

## 確認時の通知

```bash
# 確認が必要な場合
afplay ~/notification.mp3

# 完了時
afplay ~/notification.mp3
```

---

## 例外処理

### Boundary 操作が拒否された場合
- ユーザーに理由を説明
- 代替案を提案
- 必要に応じて `/protection-mode` で思考法を再確認

### Forbidden 操作が検出された場合
- 即座に拒否
- なぜ危険かを説明
- 安全な代替手段を提案

---

## 関連

- `session-modes.md` - モード定義
- `/protection-mode` コマンド - 圏論的思考法ロード
- `claude-code/references/AI-THINKING-ESSENTIALS.md` - 思考法エッセンス（5フェーズワークフロー含む）
- 10原則 - 基本動作原則
