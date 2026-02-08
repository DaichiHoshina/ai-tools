# backend-dev スキル（プロトタイプ）

## 概要
go-backend と typescript-backend を統合し、言語パラメータで切り替え可能にする。

---

## パラメータ設計

### 環境変数方式
```bash
# Go開発
export BACKEND_LANG=go
/skill backend-dev

# TypeScript開発
export BACKEND_LANG=typescript
/skill backend-dev
```

### 自動検出方式（推奨）
```bash
# ファイル拡張子から自動検出
git diff --name-only | grep -q '\.go$' && LANG=go
git diff --name-only | grep -q '\.(ts|tsx)$' && LANG=typescript

# 明示的指定がない場合は、変更ファイルから推論
/skill backend-dev  # 自動検出
```

---

## SKILL.md 構造案

```yaml
---
name: backend-dev
description: バックエンド開発 - Go/TypeScript対応（言語自動検出）
requires-guidelines:
  - common
  - golang  # BACKEND_LANG=go の場合のみ
  - typescript  # BACKEND_LANG=typescript の場合のみ
parameters:
  language:
    type: enum
    values: [go, typescript, auto]
    default: auto
    description: 開発言語（auto の場合は変更ファイルから自動検出）
---
```

---

## ガイドライン動的ロード

### 実行時ロジック
```bash
#!/usr/bin/env bash

# パラメータ取得
LANG=${BACKEND_LANG:-auto}

# 自動検出
if [ "$LANG" = "auto" ]; then
  if git diff --name-only | grep -q '\.go$'; then
    LANG=go
  elif git diff --name-only | grep -q '\.(ts|tsx)$'; then
    LANG=typescript
  else
    echo "⚠️ 言語を自動検出できませんでした。BACKEND_LANG環境変数を設定してください。"
    exit 1
  fi
fi

# 言語別ガイドライン適用
case "$LANG" in
  go)
    # Goガイドライン適用
    source ~/.claude/guidelines/golang.md
    ;;
  typescript)
    # TypeScriptガイドライン適用
    source ~/.claude/guidelines/typescript.md
    ;;
  *)
    echo "⚠️ 不明な言語: $LANG"
    exit 1
    ;;
esac
```

---

## スキル内容の分岐

### Go固有の内容
```markdown
## Goイディオム

- エラーハンドリング: `if err != nil`
- 並行処理: goroutine + channel
- テスト: `*_test.go` + `go test`
```

### TypeScript固有の内容
```markdown
## TypeScript型安全

- 型推論の活用
- ジェネリクス
- テスト: Jest/Vitest
```

### 共通内容
```markdown
## 共通ベストプラクティス

- API設計原則
- エラーハンドリング戦略
- テストカバレッジ
- ドキュメンテーション
```

---

## 後方互換性（エイリアス）

### detect-from-*.sh での変換
```bash
# detect-from-errors.sh
if echo "$prompt" | grep -qE 'go build.*failed'; then
  _skills["backend-dev"]=1
  export BACKEND_LANG=go
  _context="${_context}\\n- ⚠️ Go compilation error detected"
fi

if echo "$prompt" | grep -qE 'typescript.*error'; then
  _skills["backend-dev"]=1
  export BACKEND_LANG=typescript
  _context="${_context}\\n- ⚠️ TypeScript type error detected"
fi
```

### シンボリックリンク（オプション）
```bash
# 旧スキル名での互換性維持
ln -s backend-dev claude-code/skills/go-backend
ln -s backend-dev claude-code/skills/typescript-backend
```

---

## マイグレーションガイド

### ユーザー向け
```markdown
## スキル統合のお知らせ

`go-backend` と `typescript-backend` が `backend-dev` に統合されました。

### 変更内容
- 自動検出: 変更ファイルから言語を推論
- 手動指定: `BACKEND_LANG=go` で明示的に指定可能
- 後方互換: 旧スキル名も引き続き動作（非推奨）

### 推奨アクション
1. 新スキル名を使用: `/skill backend-dev`
2. 自動検出を活用（パラメータ不要）
3. 必要に応じて `BACKEND_LANG` を設定
```

---

## テストケース

### Case 1: Go開発
```bash
# 変更ファイル: main.go
git add main.go
/skill backend-dev

# 期待: BACKEND_LANG=go が自動設定
# 期待: Goガイドラインが適用される
```

### Case 2: TypeScript開発
```bash
# 変更ファイル: server.ts
git add server.ts
/skill backend-dev

# 期待: BACKEND_LANG=typescript が自動設定
# 期待: TypeScriptガイドラインが適用される
```

### Case 3: 手動指定
```bash
# ファイル変更なし、手動でGo指定
export BACKEND_LANG=go
/skill backend-dev

# 期待: Goガイドラインが適用される
```

### Case 4: 旧スキル名（後方互換）
```bash
# 検出スクリプトが旧スキル名を使用
# detect-from-errors.sh で go-backend が検出された場合

# 期待: backend-dev + BACKEND_LANG=go に自動変換
# 期待: 正常に動作
```

---

## 実装優先度

1. ✅ パラメータ設計
2. ⏳ SKILL.md 作成
3. ⏳ 自動検出ロジック実装
4. ⏳ detect-from-*.sh 更新
5. ⏳ 後方互換性テスト
6. ⏳ マイグレーションガイド作成

---

## 関連ファイル

- `claude-code/skills/go-backend/SKILL.md` - 統合元
- `claude-code/skills/typescript-backend/SKILL.md` - 統合元
- `claude-code/lib/detect-from-*.sh` - 検出ロジック
- `claude-code/guidelines/golang.md` - Go固有ガイドライン
- `claude-code/guidelines/typescript.md` - TypeScript固有ガイドライン
