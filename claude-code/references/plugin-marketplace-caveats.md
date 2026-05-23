# Plugin marketplace 操作の caveats

## 警告: marketplace 削除は連鎖 uninstall を引き起こす

`/plugin marketplace` から marketplace を削除すると、その marketplace に紐づく全プラグインが `installed_plugins.json` から消える（連鎖 uninstall）。

Claude Code を再起動するだけでは復旧しない。個別に再インストールする必要がある。

## 過去事例（2026-04-27）

marketplace update 操作中に `claude-plugins-official` を誤って削除した。以下 11 プラグインが一斉消滅した。

| プラグイン | 用途 |
|-----------|------|
| typescript-lsp | TypeScript language server |
| frontend-design | フロントエンド支援 |
| code-review | コードレビュー |
| commit-commands | コミット補助 |
| claude-md-management | CLAUDE.md 管理 |
| code-simplifier | コード簡略化 |
| security-guidance | セキュリティ指導 |
| pr-review-toolkit | PR レビュー |
| gopls-lsp | Go language server |
| rust-analyzer-lsp | Rust language server |
| pyright-lsp | Python language server |

`coderabbit` は別途 marketplace 管理されていたため消滅を免れた。

## 事前防御

marketplace 操作（remove / 再追加 / update）の前に必ず実行する。

```bash
# 現状バックアップ
claude plugin list > ~/plugin-backup-$(date +%Y%m%d).txt
```

marketplace remove / 再追加を提案する前に、紐づくプラグインへの連鎖影響を確認してユーザーに警告する。

## 復旧手順

キャッシュが残っていれば即時再インストール可能。

```bash
# 個別再導入
claude plugin install <name>@claude-plugins-official

# bulk 復旧（リストから一括）
for p in typescript-lsp frontend-design code-review commit-commands \
  claude-md-management code-simplifier security-guidance pr-review-toolkit \
  gopls-lsp rust-analyzer-lsp pyright-lsp; do
  claude plugin install "${p}@claude-plugins-official"
done
```

## 関連

- `references/coderabbit-plugin.md`（CodeRabbit は別 marketplace のため連鎖影響なし）
