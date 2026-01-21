# Kanban - タスク管理システム

複数プロジェクトで複雑タスクを安全かつ効率的に遂行するための、Kanbanベースのタスク管理システム。

## 特徴

- **汎用性**: どのリポジトリでも使用可能
- **Sub agent対応**: ロック機構による衝突回避
- **トークン最適化**: 圧縮JSON + 自動アーカイブ
- **6列Kanban**: Backlog → Ready → In Progress → Review → Test → Done
- **WIP制限**: In Progress列は同時1タスクのみ
- **自動アーカイブ**: 完了後7日経過で自動アーカイブ

## インストール

```bash
# 依存関係インストール
cd ~/ai-tools/tools/kanban
npm install

# ビルド
npm run build

# エイリアス設定（推奨）
echo 'alias kanban="node ~/ai-tools/tools/kanban/dist/cli.js"' >> ~/.zshrc
source ~/.zshrc
```

## 使い方

### 初期化

```bash
# プロジェクトディレクトリで実行
cd /path/to/your/project
kanban init "Project Name"
```

### タスク追加

```bash
# 基本
kanban add "タスクタイトル"

# オプション付き
kanban add "機能X実装" --priority=high --description="詳細説明"
```

### タスク一覧表示

```bash
# Kanbanボード形式
kanban list

# 特定ステータスのみ
kanban list --status=in_progress
```

### タスク開始

```bash
# In Progressに移動（自動でロック取得）
kanban start <task_id>
```

### タスク移動

```bash
# 任意のステータスに移動
kanban move <task_id> review
kanban move <task_id> test
```

### タスク完了

```bash
# Doneに移動（自動でロック解放）
kanban done <task_id>
```

### その他

```bash
# タスク詳細表示
kanban show <task_id>

# 全ボード一覧
kanban boards

# アーカイブ確認
kanban archive
kanban archive --date=2026-01-10

# 期限切れロッククリーンアップ
kanban cleanup
```

## Kanbanボード構造

```
┌─────────┬────────┬────────────┬─────────┬───────┬──────┐
│ Backlog │ Ready  │ In Progress│ Review  │ Test  │ Done │
├─────────┼────────┼────────────┼─────────┼───────┼──────┤
│ WIP無制限│準備完了│  WIP=1     │レビュー │テスト │完了  │
│         │        │  (locked)  │待ち     │       │      │
└─────────┴────────┴────────────┴─────────┴───────┴──────┘
                                                      ↓
                                              自動アーカイブ
                                              （7日後）
```

## データ保存先

```
~/.config/claude/kanban/
├── boards/
│   ├── project-{id}/
│   │   ├── config.json       # ボード設定
│   │   ├── active.json       # アクティブタスク（圧縮JSON）
│   │   ├── archive/          # アーカイブ
│   │   └── .lock             # ロックファイル
│   └── global/
│       └── index.json        # 全プロジェクト索引
└── templates/
```

## Claude Code統合

### `/kanban` スキル

Claude Codeから直接実行可能：

```
> /kanban を実行すれば、どのリポジトリでも複雑なタスクを遂行できます
```

詳細は `~/ai-tools/claude-code/skills/kanban/skill.md` を参照。

## トークン最適化

### 圧縮JSON

フィールド名短縮：

- `id` → `i`
- `title` → `t`
- `status` → `s`

**圧縮効果**: 約38%削減

### 自動アーカイブ

完了後7日経過したタスクを自動アーカイブ：

- `boards/project-{id}/archive/YYYY-MM-DD.json`
- active.jsonから削除（トークン削減）

## セキュリティ

### ロック機構

- ファイルロック（.lock）による排他制御
- タスク単位のロック情報
- タイムアウト：1時間後に自動解放

### 原子性保証

- 書き込みは一時ファイル経由（.tmp → rename）
- ロック取得・解放の原子性保証

## 開発

### ビルド

```bash
npm run build
```

### ウォッチモード

```bash
npm run dev
```

### クリーン

```bash
npm run clean
```

## 仕様書

詳細な仕様は以下を参照：

- `~/ai-tools/docs/kanban-spec.md`

## ライセンス

MIT
