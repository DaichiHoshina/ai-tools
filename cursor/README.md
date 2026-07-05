# Cursor 設定

Cursor IDE の設定・ルール・推奨拡張を ai-tools で管理し、複数マシンで同じ開発体験を再現する。

Cursor には VS Code 形式のクラウド同期がないため、Git 管理 + 同期スクリプトで代替する。

---

## 構成

```
cursor/
├── README.md
├── install.sh              # User + rules を symlink 適用
├── install-extensions.sh   # 推奨拡張を一括インストール
├── setup-project.sh        # プロジェクトへ .vscode テンプレ配置
├── sync.sh                 # User 設定の to-local / from-local
├── User/
│   ├── settings.json       # テーマ・フォント・エディタ UX
│   └── keybindings.json    # ショートカット
├── rules/
│   └── ai-tools-agent.mdc  # グローバル Agent ルール
├── recommendations/
│   └── extensions.json     # 推奨拡張一覧
└── templates/
    └── project/
        └── .vscode/
            └── extensions.json
```

---

## 設定方法

### 1. 初回セットアップ（新しい Mac）

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/cursor
chmod +x install.sh sync.sh install-extensions.sh setup-project.sh
./install.sh
./install-extensions.sh   # 任意
```

**install.sh が行うこと**

| ソース | リンク先 (macOS) |
|--------|------------------|
| `User/settings.json` | `~/Library/Application Support/Cursor/User/settings.json` |
| `User/keybindings.json` | `~/Library/Application Support/Cursor/User/keybindings.json` |
| `rules/*.mdc` | `~/.cursor/rules/*.mdc` |

既存ファイルは `*.backup.YYYYMMDDHHMMSS` に退避してからリンクする。

**反映確認**

1. `Developer: Reload Window`
2. Tokyo Night 風ネイビーテーマ
3. SF Mono 16px
4. Cursor Settings → Rules に `ai-tools-agent` が表示される

---

### 2. 別マシンへ持っていく

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git pull
cd cursor && ./install.sh
```

コピー運用の場合: `./sync.sh to-local`

---

### 3. 新規プロジェクトへテンプレート配置

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/cursor
./setup-project.sh ~/path/to/your-project
```

`.vscode/extensions.json`（Prettier / ESLint / EditorConfig 推奨）が追加される。

プロジェクト固有ルールは `.cursor/rules/` と `.cursor/memories/` を各リポジトリで管理する。

---

### 4. ローカル変更をリポジトリへ保存

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/cursor
./sync.sh diff
./sync.sh from-local
cd .. && git add cursor/ && git commit -m "update cursor settings"
```

symlink 運用時は `User/settings.json` の編集がリポジトリに直接反映される。

---

## メンテナンス

設定の定期見直し・自動監査:

| 手段 | 用途 |
|------|------|
| [`MAINTENANCE.md`](MAINTENANCE.md) | 月次チェックリスト（人手） |
| `/cursor-review` | 矛盾・冗長・陳腐化の自動監査（Claude Code） |
| `/retrospective` | セッション履歴から Cursor friction を抽出 |

```bash
./sync.sh diff          # 差分確認
/cursor-review          # 監査レポート
```

---

## sync.sh

| コマンド | 方向 |
|---------|------|
| `./sync.sh to-local` | リポジトリ → Cursor User |
| `./sync.sh from-local` | Cursor User → リポジトリ |
| `./sync.sh diff` | 差分表示 |

---

## 含まれる設定

### 見た目

| 項目 | 内容 |
|------|------|
| テーマ | Tokyo Night 風ネイビー |
| フォント | SF Mono 16px + ヒラギノ |
| カーソル | expand + シアン |
| ターミナル | Tokyo Night ANSI / セッション一覧バー非表示 |
| UI | 右 AI パネル起動時非表示 |

### エディタ UX

- format on save（Prettier / gofmt）
- プレビュータブ無効（`enablePreview: false`）
- sticky scroll / bracket colorization
- smart search / word wrap diff
- node_modules 等の watcher 除外

### キーバインド

| キー | 動作 |
|------|------|
| `Cmd+E` | エクスプローラー |
| `Cmd+Option+B` | 右 AI パネル toggle |
| `Cmd+1/2/3` | タブ直接切替 |
| `Alt+Z` | word wrap toggle |

### Agent ルール (`rules/ai-tools-agent.mdc`)

- 日本語返信
- 明示指示まで commit しない
- ai-tools ガイドライン参照
- `.cursor/memories/` 確認

### 推奨拡張 (`install-extensions.sh`)

Prettier, ESLint, Tailwind CSS, Go, Rust, GitLens, Error Lens, EditorConfig 等

---

## 注意

- マシン固有設定（GitHub アカウント名等）は `User/settings.json` に入れない
- `install.sh` は macOS 向け。Linux / Windows は `sync.sh to-local` を使う
- rules は `~/.cursor/rules/` へ symlink。Cursor の Rules UI からも確認できる

---

## トラブルシュート

| 症状 | 対処 |
|------|------|
| 設定が反映されない | Reload Window |
| rules が効かない | `~/.cursor/rules/` に symlink があるか確認 → Reload |
| 拡張 install 失敗 | Cursor CLI が PATH にあるか `which cursor` |

---

## 関連

- ai-tools 全体: [`../README.md`](../README.md)
- メンテナンス: [`MAINTENANCE.md`](MAINTENANCE.md)
- 監査コマンド: [`../claude-code/commands/cursor-review.md`](../claude-code/commands/cursor-review.md)
- `.cursor/memories/`: [`../.cursor/memories/`](../.cursor/memories/)
