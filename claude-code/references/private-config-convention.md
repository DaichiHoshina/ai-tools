# Private 設定の保管規約

個人/プロジェクト固有の commands・skills・hooks を public repo に含めず、`~/.claude/` 直置きで運用するための規約。

## 動機

- public repo (`ai-tools`) は GitHub 公開・履歴永続。社名・案件名・コードネーム等の機密文字列は混入させない
- プロジェクト固有のコマンドやスキルは個人開発フローに必須だが、汎用化できないものを repo に置くと汚染される
- 既存の `~/.claude/references-private/` 運用を commands/skills/hooks に拡張

## 命名規約

| 用途 | 配置先 | 例 |
|------|-------|-----|
| 個人専用 command | `~/.claude/commands/private-*.md` | `private-deploy-staging.md` |
| 個人専用 skill | `~/.claude/skills/private-*/` | `private-domain-rules/` |
| 個人専用 hook | `~/.claude/hooks/private-*.sh` | `private-postedit-checker.sh` |
| 同等代替 | `local-*` prefix も同じ扱い | `local-foo.md` |

**禁止**: public repo (`ai-tools`) に `private-*` `local-*` prefix のファイル/ディレクトリを置かない。プロジェクト名・社名・コードネーム等の文字列も含めない（コメント・コミットメッセージ含む）。

## 保護メカニズム（install.sh / sync.sh）

`private-*` `local-*` prefix を破壊的同期から保護する仕組みが入っている:

- **install.sh**: skills/hooks の上書き時に `rsync --exclude='private-*' --exclude='local-*'` で除外
- **sync.sh sync_to_local**: 全ディレクトリで `preserve_private` → `rm -rf` → `cp -r` → `restore_private` の退避パターン
- **sync.sh sync_from_local**: rsync `--exclude` で repo への漏洩防止（最重要）

新規ディレクトリを SYNC_ITEMS / install 対象に追加する際は、同じ保護を継承すること。

## 想定運用フロー

1. プロジェクト固有のコマンドが必要になる
2. `~/.claude/commands/private-{purpose}.md` を直接作成（repo の `commands/` には作らない）
3. Claude Code が自動で読み込む
4. `install.sh` / `sync.sh` 実行しても保護機構により消えない
5. バックアップは個人責任（repo 管理外）。気になるなら別 private repo or tar で保管

## アンチパターン

- repo 内に `commands/private-foo.md` 置いて `.gitignore` で除外 → 誤コミット事故リスク
- repo 内のコメントにプロジェクト名記載 → grep で発見可能、漏洩
- 保護機構の実装にプロジェクト名 hardcode → public repo に文字列残る（汎用 prefix で実装すること）
