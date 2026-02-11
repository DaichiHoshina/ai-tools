---
name: aliases
description: コマンドエイリアス定義
---

# コマンドエイリアス

頻繁に使うコマンドの短縮形。

## 利用可能なエイリアス

| エイリアス | フルコマンド | 用途 |
|-----------|-------------|------|
| `/cpr` | `/commit-push-pr` | コミット→プッシュ→PR作成を一括 |
| `/br` | `/brainstorm` | 設計相談・ブレインストーミング |
| `/dbg` | `/debug` | デバッグ支援 |
| `/ref` | `/refactor` | リファクタリング |
| `/doc` | `/docs` | ドキュメント作成 |
| `/rv` | `/review` | コードレビュー |
| `/ts` | `/test` | テスト作成 |
| `/cm` | `/commit` | コミットのみ |
| `/pl` | `/plan` | 設計・計画 |

## 使用例

### 最頻出（Top 3）

```bash
# 1. 一括コミット・PR作成
/cpr

# 2. ブレインストーミング
/br UI設計について相談したい

# 3. レビュー
/rv
```

### 開発フロー

```bash
# TDD開発
/tdd ユーザー認証機能を追加

# テスト作成
/ts LoginButton

# レビュー
/rv

# リファクタリング
/ref LoginButton を関数コンポーネント化

# PR作成
/cpr
```

### デバッグフロー

```bash
# デバッグ
/dbg CrashLoopBackOff エラーを解決

# 修正後にレビュー
/rv

# コミット
/cm
```

## エイリアス設定方法（オプション）

Claude Code設定に追加（`~/.claude/settings.json`）:

```json
{
  "aliases": {
    "cpr": "commit-push-pr",
    "br": "brainstorm",
    "dbg": "debug",
    "ref": "refactor",
    "doc": "docs",
    "rv": "review",
    "ts": "test",
    "cm": "commit",
    "pl": "plan"
  }
}
```

## カスタムエイリアス追加

プロジェクト固有のエイリアスを追加可能:

```json
{
  "aliases": {
    "myflow": "flow --skip-prd --skip-test",
    "quick": "dev --quick",
    "safe": "flow --interactive"
  }
}
```

## 注意事項

- エイリアスは `/` プレフィックス必須
- 大文字小文字を区別
- 引数はフルコマンドと同様に指定可能
- `/tdd`, `/flow`, `/dev` 等は既にコマンドとして存在するためエイリアス不要

## 関連

- [QUICKSTART.md](../QUICKSTART.md) - 基本コマンド
- [commands/](.) - 全コマンド一覧
