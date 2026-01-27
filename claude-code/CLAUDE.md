# claude-code ディレクトリ固有設定

このディレクトリはClaude Code用の設定・スキル・フックを管理。

## 構造

```
claude-code/
├── commands/      スラッシュコマンド定義
├── skills/        スキル定義（レビュー、開発、インフラ等）
├── hooks/         イベントフック（session-start等）
├── guidelines/    言語・設計ガイドライン
├── agents/        エージェント定義
└── references/    参考資料
```

## 編集時の注意

- `install.sh`/`sync.sh` を更新したら `~/.claude/` に同期必要
- 🔒 PROTECTED SECTION（CLAUDE.md内）は変更禁止
- frontmatter（---で囲まれた部分）は正確なYAML形式を維持

## 同期コマンド

```bash
./claude-code/install.sh   # 初回インストール
./claude-code/sync.sh      # 更新時の同期
```

## 主要ファイル

| ファイル | 用途 |
|----------|------|
| install.sh | ~/.claude/への初回インストール |
| sync.sh | 設定変更後の同期 |
| QUICKSTART.md | 新規ユーザー向けクイックスタート |
| SKILLS-MAP.md | スキル一覧と依存関係 |
| GLOSSARY.md | 用語集 |
