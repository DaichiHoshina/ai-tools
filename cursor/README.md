# Cursor 設定

Cursor IDE の `settings.json` / `keybindings.json` を ai-tools で管理し、複数マシンで同じ見た目・操作感を再現する。

Cursor には VS Code 形式のクラウド同期がないため、Git 管理 + 同期スクリプトで代替する。

---

## 構成

```
cursor/
├── README.md
├── install.sh          # 初回: シンボリックリンクで適用
├── sync.sh             # 設定変更後: ファイルコピーで同期
└── User/
    ├── settings.json   # テーマ・フォント・ターミナル等
    └── keybindings.json
```

---

## 設定方法

### 1. 初回セットアップ（新しい Mac / クリーンインストール後）

ai-tools を clone 済みであること。

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/cursor
chmod +x install.sh sync.sh
./install.sh
```

`install.sh` は次のファイルを **シンボリックリンク** で接続する:

| リポジトリ | リンク先 (macOS) |
|-----------|------------------|
| `cursor/User/settings.json` | `~/Library/Application Support/Cursor/User/settings.json` |
| `cursor/User/keybindings.json` | `~/Library/Application Support/Cursor/User/keybindings.json` |

既存ファイルがある場合は `*.backup.YYYYMMDDHHMMSS` に退避してからリンクする。

**反映確認**

1. Cursor を起動（または `Cmd + Shift + P` → `Developer: Reload Window`）
2. テーマが Tokyo Night 風ネイビーになっていること
3. フォントが SF Mono 16px になっていること

---

### 2. 別マシンへ設定を持っていく

```bash
# 1. ai-tools を pull
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git pull

# 2. Cursor 設定を適用
cd cursor
./install.sh
```

symlink ではなく **コピー** で運用したい場合:

```bash
./sync.sh to-local
```

---

### 3. ローカルで設定を変えたあと、リポジトリへ保存する

Cursor の Settings UI や `settings.json` を直接編集したあと:

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/cursor

# 差分確認
./sync.sh diff

# リポジトリへ取り込み
./sync.sh from-local

# コミット
cd ..
git add cursor/User/
git commit -m "update cursor settings"
git push
```

**symlink 運用 (`install.sh` 済み) の場合**

`settings.json` を編集すると **リポジトリ側が直接更新** される。`git diff cursor/User/` で確認して commit すればよい。

---

### 4. リポジトリの変更をローカルへ反映する

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git pull

cd cursor
./sync.sh to-local
# または symlink なら pull だけで自動反映
```

---

## sync.sh コマンド一覧

| コマンド | 方向 | 用途 |
|---------|------|------|
| `./sync.sh to-local` | リポジトリ → Cursor | pull 後にコピー運用で上書き |
| `./sync.sh from-local` | Cursor → リポジトリ | UI で変更した設定を保存 |
| `./sync.sh diff` | 差分表示 | commit 前の確認 |

---

## 含まれる設定

| カテゴリ | 内容 |
|---------|------|
| テーマ | Tokyo Night 風ネイビー（ウィンドウ全体） |
| フォント | SF Mono 16px + ヒラギノ（日本語 fallback） |
| カーソル | expand アニメーション + シアン |
| ターミナル | ANSI カラー / セッション一覧バー非表示 |
| UI | 右 AI パネル起動時非表示 / カスタムタイトルバー |
| エディタ | format on save / bracket colorization / sticky scroll |

---

## 注意事項

- **マシン固有の設定はリポジトリに入れない**  
  例: `github.copilot.preferredAccount` などアカウント名
- **拡張機能は同期対象外**  
  Prettier 等が必要なら各マシンで別途インストール
- **Linux / Windows**  
  リンク先パスが異なる。`install.sh` は macOS 向け。他 OS では `sync.sh to-local` を使う

### ローカル専用設定を残したい場合

`User/settings.local.json` のような別ファイルは現状未対応。  
マシン固有の項目だけ Cursor UI から設定し、リポジトリへ `from-local` しない運用にする。

---

## トラブルシュート

| 症状 | 対処 |
|------|------|
| 設定が反映されない | `Developer: Reload Window` |
| symlink が壊れた | `./install.sh` を再実行 |
| 以前の設定に戻したい | `~/Library/Application Support/Cursor/User/*.backup.*` から復元 |
| 差分が想定と違う | `./sync.sh diff` で確認 |

---

## 関連

- Claude Code 設定: [`../claude-code/README.md`](../claude-code/README.md)（存在する場合）
- ai-tools 全体: [`../README.md`](../README.md)
