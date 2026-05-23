# CodeRabbit Claude Code プラグイン

## 構成

| 項目 | 値 |
|------|-----|
| marketplace | `claude-plugins-official` |
| ホスト | `coderabbitai/claude-plugin` |
| CLI | `~/.local/bin/coderabbit` (v0.4.3) |
| プラグインバージョン | v1.1.0 |

## セットアップ

```bash
# インストール
claude plugin install coderabbit@claude-plugins-official

# 認証（GitHub 連携）
coderabbit auth login
```

## コマンド

| コマンド | 対象 |
|---------|------|
| `/coderabbit:review` | 全変更をレビュー |
| `/coderabbit:review committed` | コミット済み変更のみ |
| `/coderabbit:review uncommitted` | 未コミット変更のみ |
| `/coderabbit:review --base main` | main との差分比較 |

自然言語「変更箇所のレビュー」でも起動する。

## 料金（2026-04 時点）

| プラン | 内容 |
|--------|------|
| Free | public / private 無制限、PR 要約、IDE レビュー |
| OSS public repo | 完全無料（永続） |
| Pro 試用 | 14 日間（クレジットカード不要） |
| Pro | $24/user/月 |
| Pro Plus | $48/user/月 |
| Enterprise | 要相談 |

## ドキュメント

https://docs.coderabbit.ai/cli/claude-code-integration

## 注意

`claude-plugins-official` marketplace を削除すると CodeRabbit プラグインは削除されない（別途管理されているため）。詳細は `references/plugin-marketplace-caveats.md` 参照。
