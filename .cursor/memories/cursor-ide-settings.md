# Cursor IDE 設定メモ

更新: 2026-06-20

## 正本

```
ai-tools/cursor/
├── User/settings.json, keybindings.json
├── rules/ai-tools-agent.mdc      # ~/.cursor/rules/ へ install
├── recommendations/extensions.json
├── install.sh / install-extensions.sh / setup-project.sh
└── README.md
```

Git: main に push 済み (`56a4324`, `ab80ce7`)

## ユーザー好み

| 項目 | 設定 |
|------|------|
| テーマ | Tokyo Night 風ネイビー `#1a1b26` |
| フォント | SF Mono 16px + ヒラギノ |
| カーソル | expand + シアン `#7dcfff` |
| 右 AI パネル | 起動時非表示 |
| ターミナルセッション一覧 | 非表示 (`terminal.integrated.tabs.enabled: false`) |
| ターミナル ANSI | Tokyo Night 標準（ansiBlack `#414868`） |

## 同期

Cursor クラウド同期なし → Git + `cursor/sync.sh`

```bash
cd ai-tools/cursor
./install.sh              # 初回
./sync.sh from-local      # ローカル変更をリポジトリへ
./sync.sh to-local        # リポジトリをローカルへ
```

## ローカルパス (macOS)

`~/Library/Application Support/Cursor/User/settings.json`

## 注意

- マシン固有設定（GitHub アカウント名等）は `User/settings.json` に入れない
- Serena memory の代わりに `.cursor/memories/` で管理
