# スキル統合マイグレーションガイド

Phase2-5スキル統合（24→20スキル、実質14機能）の移行ガイド

## 変更概要

### 統合されたスキル

| 旧スキル名 | 新スキル名 | パラメータ |
|----------|----------|----------|
| code-quality-review | comprehensive-review | --focus=quality |
| security-error-review | comprehensive-review | --focus=security |
| docs-test-review | comprehensive-review | --focus=docs |
| go-backend | backend-dev | --lang=go |
| typescript-backend | backend-dev | --lang=typescript |
| docker-troubleshoot | container-ops | --platform=docker --mode=troubleshoot |
| kubernetes | container-ops | --platform=kubernetes |

---

## 自動変換（後方互換性）

**重要**: 旧スキル名は引き続き使用可能です。detect-from-*.shが自動的に新スキル名+パラメータに変換します。

### 動作確認

```bash
# 旧スキル名での検出（自動変換される）
echo '{"prompt":"go build failed"}' | ~/.claude/hooks/user-prompt-submit.sh
# → backend-dev + BACKEND_LANG=go が検出される

echo '{"prompt":"security issue"}' | ~/.claude/hooks/user-prompt-submit.sh
# → comprehensive-review + REVIEW_FOCUS=security が検出される
```

---

## マイグレーション方法

### 1. comprehensive-review（レビュー系）

#### 旧: 個別スキル使用
```bash
# 品質レビュー
/skill code-quality-review

# セキュリティレビュー
/skill security-error-review

# ドキュメント/テストレビュー
/skill docs-test-review
```

#### 新: パラメータ指定
```bash
# 品質のみ
/skill comprehensive-review --focus=quality

# セキュリティのみ
/skill comprehensive-review --focus=security

# ドキュメント/テストのみ
/skill comprehensive-review --focus=docs

# 全観点（推奨）
/skill comprehensive-review --focus=all
# または
/skill comprehensive-review
```

#### 環境変数での指定
```bash
export REVIEW_FOCUS=quality
/skill comprehensive-review
```

---

### 2. backend-dev（バックエンド開発）

#### 旧: 言語別スキル
```bash
# Go開発
/skill go-backend

# TypeScript開発
/skill typescript-backend
```

#### 新: 言語パラメータ指定
```bash
# Go開発（明示的指定）
/skill backend-dev --lang=go

# TypeScript開発（明示的指定）
/skill backend-dev --lang=typescript

# 自動検出（推奨）
/skill backend-dev
# .goファイルを変更している場合 → 自動的にlang=go
# .ts/.tsxファイルを変更している場合 → 自動的にlang=typescript

# 新規追加: Python開発
/skill backend-dev --lang=python

# 新規追加: Rust開発
/skill backend-dev --lang=rust
```

#### 環境変数での指定
```bash
export BACKEND_LANG=go
/skill backend-dev
```

---

### 3. container-ops（コンテナ運用）

#### 旧: プラットフォーム別スキル
```bash
# Dockerトラブルシューティング
/skill docker-troubleshoot

# Kubernetes運用
/skill kubernetes
```

#### 新: プラットフォーム+モード指定
```bash
# Dockerトラブルシューティング
/skill container-ops --platform=docker --mode=troubleshoot

# Kubernetesデプロイ
/skill container-ops --platform=kubernetes --mode=deploy

# Dockerベストプラクティス
/skill container-ops --platform=docker --mode=best-practices

# 自動検出（推奨）
/skill container-ops
# "cannot connect to docker daemon" → 自動的にplatform=docker, mode=troubleshoot
# "CrashLoopBackOff" → 自動的にplatform=kubernetes, mode=troubleshoot
```

#### 環境変数での指定
```bash
export CONTAINER_PLATFORM=docker
export CONTAINER_MODE=troubleshoot
/skill container-ops
```

---

## 自動検出の仕組み

### ファイル変更からの検出

```bash
# Goファイル変更 → backend-dev (lang=go)
git diff --name-only | grep '\.go$'

# TypeScriptファイル変更 → backend-dev (lang=typescript)
git diff --name-only | grep '\.(ts|tsx)$'

# Dockerfile変更 → container-ops (platform=docker, mode=best-practices)
git diff --name-only | grep 'Dockerfile'

# Kubernetesマニフェスト変更 → container-ops (platform=kubernetes)
git diff --name-only | grep 'deployment\.yaml$'
```

### エラーログからの検出

```bash
# Dockerエラー → container-ops (platform=docker, mode=troubleshoot)
echo "cannot connect to docker daemon"

# TypeScriptエラー → backend-dev (lang=typescript)
echo "Type error TS2304"

# Goエラー → backend-dev (lang=go)
echo "go build failed"
```

### Git branchからの検出

```bash
# fix/ブランチ → comprehensive-review (focus=security)
git checkout -b fix/security-issue

# feature/api-ブランチ → api-design
git checkout -b feature/api-users
```

---

## テスト方法

### 後方互換性テスト

```bash
# 全14テスト実行
cd /path/to/ai-tools
bats claude-code/tests/unit/hooks/user-prompt-submit.bats

# 期待結果: すべてok（14/14）
```

### 手動テスト

```bash
# 1. 旧スキル名での検出
echo '{"prompt":"go backend development"}' | ~/.claude/hooks/user-prompt-submit.sh | jq .

# 期待: backend-dev が検出され、BACKEND_LANG=go が設定される

# 2. 新スキル名での検出
echo '{"prompt":"backend development"}' | ~/.claude/hooks/user-prompt-submit.sh | jq .

# 期待: backend-dev が検出される（自動検出）
```

---

## トラブルシューティング

### Q1: 旧スキル名が検出されない

**原因**: detect-from-*.shのマッピングテーブルが読み込まれていない

**解決**:
```bash
# キャッシュクリア
rm -rf ~/.claude/cache/keyword-patterns.json

# hookを再実行
source ~/.claude/hooks/user-prompt-submit.sh
```

### Q2: パラメータが環境変数に設定されない

**原因**: _apply_skill_aliases関数が呼ばれていない

**解決**:
```bash
# detect-from-keywords.shの再読み込み
source ~/.claude/lib/detect-from-keywords.sh

# 関数が定義されているか確認
declare -f _apply_skill_aliases
```

### Q3: 新スキル名でSKILL.mdが見つからない

**原因**: スキルディレクトリが作成されていない

**解決**:
```bash
# 新スキルディレクトリの存在確認
ls -la ~/.claude/skills/backend-dev/
ls -la ~/.claude/skills/container-ops/

# なければ同期実行
cd /path/to/ai-tools
./claude-code/sync.sh
```

---

## ロールバック方法（非推奨）

統合前の状態に戻す場合（緊急時のみ）:

```bash
# 1. Gitで統合前のコミットに戻る
git log --oneline | grep "phase2-5"
git checkout <統合前のコミットID>

# 2. detect-from-*.shのマッピングテーブルをコメントアウト
# claude-code/lib/detect-from-keywords.sh の SKILL_ALIASES をコメントアウト

# 3. キャッシュクリア
rm -rf ~/.claude/cache/

# 4. sync実行
./claude-code/sync.sh
```

---

## 参照

- [SKILLS-MAP.md](SKILLS-MAP.md): 統合後のスキル一覧
- [skills/comprehensive-review/SKILL.md](skills/comprehensive-review/SKILL.md): パラメータ詳細
- [skills/backend-dev/SKILL.md](skills/backend-dev/SKILL.md): 言語別ベストプラクティス
- [skills/container-ops/SKILL.md](skills/container-ops/SKILL.md): プラットフォーム別運用

---

## フィードバック

統合に関する問題や改善提案は、Issueで報告してください:
https://github.com/your-org/ai-tools/issues
