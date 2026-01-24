# コマンドエイリアス

頻繁に使うコマンドの短縮形。

## 利用可能なエイリアス

| エイリアス | フルコマンド | 用途 |
|-----------|-------------|------|
| `/cpr` | `/commit-push-pr` | コミット→プッシュ→PR作成を一括 |
| `/sk` | `/load-guidelines` | 技術スタック検出、ガイドライン読み込み |
| `/br` | `/superpowers:brainstorm` | 設計相談・ブレインストーミング |
| `/tdd` | `/superpowers:test-driven-development` | TDD開発モード |
| `/dbg` | `/superpowers:systematic-debugging` | 体系的デバッグ |
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

# 2. 技術スタック自動検出
/sk

# 3. ブレインストーミング
/br UI設計について相談したい
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
# 体系的デバッグ
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
    "sk": "load-guidelines",
    "br": "superpowers:brainstorm",
    "tdd": "superpowers:test-driven-development",
    "dbg": "superpowers:systematic-debugging",
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
    "quick": "dev --auto",
    "safe": "flow --interactive"
  }
}
```

## 推奨使用頻度

| エイリアス | 頻度 | 理由 |
|-----------|------|------|
| `/cpr` | ⭐⭐⭐⭐⭐ | 最頻出（毎PR作成時） |
| `/sk` | ⭐⭐⭐⭐ | 各プロジェクト初回 |
| `/br` | ⭐⭐⭐⭐ | 設計フェーズ |
| `/rv` | ⭐⭐⭐⭐ | 実装完了後 |
| `/tdd` | ⭐⭐⭐ | TDD採用時 |
| `/dbg` | ⭐⭐⭐ | デバッグ時 |
| `/ref` | ⭐⭐ | リファクタ時 |
| その他 | ⭐⭐ | 必要に応じて |

## 注意事項

- エイリアスは `/` プレフィックス必須
- 大文字小文字を区別
- 引数はフルコマンドと同様に指定可能

## 関連

- [QUICKSTART.md](../QUICKSTART.md) - 基本コマンド
- [commands/](.) - 全コマンド一覧
