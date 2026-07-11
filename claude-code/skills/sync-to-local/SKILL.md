---
allowed-tools: Bash, Read
name: sync-to-local
description: ai-tools repo を ~/.claude へ反映する sync.sh to-local の実行 skill。定義 file の編集・merge 後の反映時に使用。「sync して」「同期して」で起動。
requires-guidelines:
  - common
---

# sync-to-local

`~/ai-tools/claude-code/` (SoT) を `~/.claude/` へ反映する。方向は to-local のみ (逆方向はほぼ使わないため本 skill の対象外)。

## When to Use

- claude-code 配下の定義 file (commands / skills / agents / hooks / rules / guidelines / templates) を編集・merge した後
- 「sync して」「同期して」「~/.claude に反映して」と言われた時
- 誤 sync からの復旧 (「sync 戻して」→ rollback)

## Steps

### 1. 実行場所と前提

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools/claude-code
```

worktree 作業中でも sync 元は merge 済みの main 側 (`~/ghq/.../ai-tools/claude-code/`) を使う。未 merge の worktree から sync しない。

### 2. Mode 判定

| 状況 | Command |
|---|---|
| 通常反映 (default) | `./sync.sh to-local --yes` |
| 影響範囲を先に見たい | `./sync.sh to-local --dry-run` → 差分確認後に `--yes` |
| hooks だけ等の部分反映 | `./sync.sh to-local --yes --only=hooks,commands` |
| 状態確認だけ | `./sync.sh status` |
| 誤 sync 復旧 | `./sync.sh rollback --yes` (直近 backup 3 世代から復元) |

### 3. 反映確認 (smoke test)

変更対象が実際に `~/.claude/` へ届いたか 1 点確認する。

```bash
ls ~/.claude/skills/<変更した skill>/  # 追加なら存在、削除なら不在を確認
```

## Guard

- `~/.claude/` を直接編集しない (次回 sync で wipe される)
- root keys (env / model / permissions 等) は template canonical。sync で消えた場合は template 側を直す
- rollback は破壊的操作なので実行前にユーザー確認する

## Out of Scope

- local → repo の逆方向取り込み (手動 diff で個別対応)
- Codex / Cursor 同期の個別調整 (sync.sh が一括で面倒を見る)
