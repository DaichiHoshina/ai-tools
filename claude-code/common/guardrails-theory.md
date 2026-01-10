# ガードレール（3層分類）

> **目的**: 操作を3層に分類し、安全性を数学的に保証

---

## 🛡️ Guard関手の定義

```
Guard : Action → {Allow, AskUser, Deny}

Guard(a) = Allow   ⟺ a ∈ Safe射
Guard(a) = AskUser ⟺ a ∈ Boundary射
Guard(a) = Deny    ⟺ a ∈ Forbidden射
```

---

## 1. Safe射（即実行可能）

自動許可される操作。リスクがゼロ。

**具体例**:
- ファイル読み取り（Read, Grep, Glob）
- コード分析（LSP, Serena検索）
- git status, git log, git diff
- 提案・説明・レビュー
- TodoWrite（進捗管理）

---

## 2. Boundary射（ユーザー確認必要）

実行前にユーザーの承認が必要な操作。

**具体例**:
- ファイル編集・作成（Edit, Write）
- git commit, git push
- パッケージ導入（npm install等）
- 設定ファイル変更
- Bash実行（読み取り以外）

**確認フロー**:
1. 操作内容を説明
2. 影響範囲を明示
3. ユーザーの承認を得る
4. 実行

---

## 3. Forbidden射（実行不可能）

絶対に実行してはいけない操作。未定義。

### 3-1. システム破壊

```
rm -rf /
dd if=/dev/zero of=/dev/sda
kill -9 -1
shutdown -h now（許可なし）
mkfs.*（許可なし）
```

### 3-2. セキュリティ問題

```
chmod 777 -R /
leak(secrets)
expose(credentials)
commit(.env)
push(secrets)
eval(user_input)
exec(untrusted_code)
```

### 3-3. Git危険操作

```
git push --force（mainブランチ、許可なし）
git reset --hard（リモート、許可なし）
git clean -fdx（許可なし）
git rebase -i（リモート、許可なし）
```

### 3-4. YAGNI違反

```
過度な抽象化（今必要ない機能）
不要なデザインパターン適用
「将来使うかも」の機能実装
```

---

## 📊 判定フロー

```
操作を受け取る
  ↓
[読み取りのみ?] → Yes → Safe射 → 即実行
  ↓ No
[破壊的/危険?] → Yes → Forbidden射 → 拒否
  ↓ No
Boundary射 → ユーザー確認 → 承認後実行
```

---

## 適用例

### ケース1: ファイル読み取り

```
操作: Read("src/main.ts")
判定: Safe射
結果: 即実行
```

### ケース2: ファイル編集

```
操作: Edit("src/main.ts", ...)
判定: Boundary射
結果: ユーザー確認 → 承認後実行
```

### ケース3: secrets漏洩

```
操作: commit(".env")
判定: Forbidden射
結果: 拒否 + 警告
```

---

## 参考

- 詳細な圏論的定義: iguchi版 `category-theory/GUARDRAILS.md`
- CLAUDE.mdの9原則「1. kenron」にも記載
- モード別の確認レベル: `guidelines/common/guardrails.md`
