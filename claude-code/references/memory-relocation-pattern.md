# Memory relocation pattern (auto-memory → project-scoped path)

auto-memory (`~/.claude/projects/{encoded-cwd}/memory/`) の保存先を project repo 配下の user-readable な path に移す設計パターン。auto-load を諦める代わりに **user 自身が file を探せる / 編集できる / git ignore で管理できる** 利得を取る。

## 背景

auto-memory の問題点:

- 場所が encoded path (`-Users-foo-ghq-...-<project>`) で人間が辿りづらい
- worktree 違い / repo 違いで dir が大量増殖し、SoT が分散
- 横断検索 / 一括編集が GUI で困難
- 同一 user の知識が 10-数十 dir に重複する

## 移行先パターン

repo / org / user の scope 別に 3 typed:

| Scope | 推奨 path | 例 |
|---|---|---|
| **org 配下 N repo 共通** (org level user 私物 dir がある場合) | `<org-root>/memory/` | `~/ghq/github.com/<org>/memory/` |
| **単 repo + public な repo** | `<repo>/memory/` (`.gitignore` 必須) | `<repo-root>/memory/` + `.gitignore` に `/memory/` 追記 |
| **user 横断 (cross-project)** | 任意の user 私物 dir | `~/.config/claude/memory/` 等 |

`<org-root>/memory/` パターンの内部構造例:

```
<org-root>/memory/
├── MEMORY.md           # top index (sub dir 案内)
├── _org/               # org 全体に効くルール
├── <repo-1>/           # repo 固有
├── <repo-2>/
└── ...
```

各 sub dir に独自の `MEMORY.md` (file index) を置く。

## 移行手順

1. **重複 sweep** — 移行前に同名 file / 同 hash file の SoT を 1 個に絞る (上層 = `_org` 優先)
2. **新 dir 作成** — scope 別に sub dir
3. **cp + MEMORY.md 同梱** — 旧 dir → 新 dir 全 file を cp、各 sub dir の MEMORY.md もそのまま持っていく
4. **旧 dir 退避** — 旧 `~/.claude/projects/.../memory/*.md` を `.trash-<date>-migration/` に mv、`MEMORY.md` を「移行済み」スタブに置換
5. **broken link 検出** — 全 MEMORY.md の `[xxx](file.md)` を scan、参照先 file が新 dir にあるか確認
6. **public repo は gitignore** — repo 配下に置く場合は `.gitignore` の `/memory/` 追記を最初に行う (誤 commit 防止)

## auto-load 喪失への対応

新 path は Claude Code が auto-load しない。3 つの補い方:

| 対応 | 方法 | 効果 |
|---|---|---|
| **CLAUDE.md に保存先記述追加** | org-root の user 私物 CLAUDE.md / `~/.claude/CLAUDE.local.md` に「ナレッジ保存先 = <path>」を書く | session 開始時に CLAUDE.md 経由で Claude が path を知る |
| **MEMORY.md を index として明示 Read** | session 早期に対応 sub dir の MEMORY.md を user 指示 or Claude 自発で Read | 既存 auto-memory 同等の効果 (1 file 読むだけ) |
| **trigger word で書込先を固定** | CLAUDE.md に「永続化指示」trigger word リストと保存先 table を記載 | 「覚えて」「memory に保存」等で対応 sub dir に書く流れを固定 |

## 注意点

- **public repo の repo 配下に置く場合**: `.gitignore` を**先に**追記してから dir 作成、誤 commit / 公開を確実に避ける
- **org level user 私物 dir** (`~/ghq/github.com/<org>/` 直下) は git 管理外であることを前提とする。git 管理されていたら別 path にする
- **旧 auto-memory dir は空にする** — file が残ってると Claude が auto-load して**新旧両方**読み込む二重状態になる。MEMORY.md も「移行済み」stub に置換
- **復元可能性確保** — `.trash-<date>-migration/` に旧 file を mv 退避、即削除しない

## 適用実績

- **ai-tools repo** (2026-06-26): `~/.claude/projects/.../ai-tools/memory/` → `~/ai-tools/memory/` (`.gitignore` 済) に migration 済。CLAUDE.md `## Compounding Engineering` § Memory write target で `~/ai-tools/memory/` 固定を宣言、旧 path への write を禁止

## 関連

- `../CLAUDE.md` `## Compounding Engineering` § Memory write target — ai-tools repo 固有の write 先固定宣言 (本 pattern の機械強制 step)
- `memory-usage.md` — auto-memory / Serena memory の使い分け原則 (本 pattern の前提)
- `compounding-engineering-cycle.md` — 知識を config 側に昇格する原則 (memory より skill / hook / rule 優先)
- `../rules/public-repo-private-data-block.md` — public repo に private 情報を置かない原則 (本 pattern で gitignore が必須な理由)
