---
name: aliases
description: コマンドエイリアス定義
effort: low
---

# コマンドエイリアス

頻繁に使うコマンドの短縮形。

## 利用可能なエイリアス

| エイリアス | フルコマンド | 用途 |
|-----------|-------------|------|
| `/gp` | `/git-push` | Git統合（commit→push→PR/MR） |
| `/br` | `/brainstorm` | 設計相談・ブレインストーミング |
| `/dbg` | `/diagnose` | デバッグ支援 |
| `/ref` | `/refactor` | リファクタリング |
| `/doc` | `/docs` | ドキュメント作成 |
| `/rv` | `/review` | コードレビュー |
| `/ts` | `/test` | テスト作成 |
| `/cm` | `/commit` | コミットのみ |
| `/pl` | `/plan` | 設計・計画 |
| `/dd` | `/design-dog` | チーム共有用Design Doc作成 |
| `/mp` | `/git-push --main` | mainにコミット&プッシュ |

引数はフルコマンドと同様に指定可能。`/tdd`, `/flow`, `/dev` 等は既にコマンドとして存在するためエイリアス不要。
