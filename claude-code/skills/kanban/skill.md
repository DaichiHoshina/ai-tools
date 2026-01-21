---
name: kanban
description: Kanbanタスク管理 - 複雑タスクの分解・進捗追跡・トークン圧縮38%
trigger:
  - /kanban
  - kanban
  - タスク管理
  - 複雑タスク
---

# Kanban タスク管理スキル

## 概要

複数プロジェクトで複雑タスクを安全かつ効率的に遂行するための、Kanbanベースのタスク管理システム。

## 特徴

- **汎用性**: どのリポジトリでも使用可能
- **Sub agent対応**: ロック機構による衝突回避
- **トークン最適化**: 圧縮JSON + 自動アーカイブ（**38%削減**）
- **6列Kanban**: Backlog → Ready → In Progress → Review → Test → Done
- **WIP制限**: In Progress列は同時1タスクのみ

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `kanban init "名前"` | ボード初期化 |
| `kanban add "タスク"` | タスク追加 |
| `kanban list` | タスク一覧 |
| `kanban start <id>` | タスク開始（In Progress移動） |
| `kanban move <id> <status>` | ステータス移動 |
| `kanban done <id>` | タスク完了 |
| `kanban show <id>` | タスク詳細 |
| `kanban boards` | 全ボード一覧 |
| `kanban archive` | アーカイブ確認 |
| `kanban cleanup` | 期限切れロッククリーンアップ |

## ステータス値

```
backlog → ready → in_progress → review → test → done
```

## ComplexityCheckとの連携

AI-THINKING-ESSENTIALS.mdの**ComplexityCheck射**と連携：

```
ComplexityCheck: UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

| 判定 | Kanbanアクション |
|------|-----------------|
| **Simple** | Kanban不要、直接実装 |
| **TaskDecomposition** | `kanban init` → タスク分解 → 並列実行 |
| **AgentHierarchy** | POがKanban管理、各Developerがタスク担当 |

## 使用例

### 1. 新機能実装（TaskDecomposition）

```bash
# 初期化
kanban init "認証機能実装"

# タスク分解
kanban add "DB設計" --priority=high
kanban add "API実装" --priority=high
kanban add "フロントエンド" --priority=medium
kanban add "テスト作成" --priority=medium

# 進捗管理
kanban start 1
# ... 作業 ...
kanban done 1
```

### 2. 並列Agent実行時

```bash
# Manager: タスク分解
kanban init "大規模リファクタ"
kanban add "dev1: Backend改修"
kanban add "dev2: Frontend改修"
kanban add "dev3: テスト更新"

# 各Developer: 自分のタスクをロック
kanban start 1  # dev1
kanban start 2  # dev2
kanban start 3  # dev3
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

## トークン最適化

### 圧縮JSON

フィールド名短縮により**38%削減**:

- `id` → `i`
- `title` → `t`
- `status` → `s`
- `priority` → `p`

### 自動アーカイブ

完了後7日経過したタスクを自動アーカイブ:
- active.jsonから削除（トークン削減）
- `archive/YYYY-MM-DD.json`に保存

## ロック機構

- **ファイルロック**: `.lock`による排他制御
- **タスクロック**: In Progressタスクは他Agentが取得不可
- **タイムアウト**: 1時間後に自動解放

## インストール確認

```bash
cd ~/ai-tools/tools/kanban
npm install && npm run build
```

## 関連ドキュメント

- `~/ai-tools/tools/kanban/README.md` - 詳細仕様
- `~/ai-tools/claude-code/references/AI-THINKING-ESSENTIALS.md` - ComplexityCheck射
