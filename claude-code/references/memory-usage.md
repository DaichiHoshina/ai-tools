# Memory Usage Guide

保存先は `~/ai-tools/memory/` の一本 SoT (Claude Code のみ write、Codex / Cursor は symlink 経由で read-only 共有)。

| Memory | Purpose | Auto-loaded |
|--------|---------|------------|
| auto-memory (`~/ai-tools/memory/`、`.gitignore` 済) | work-context (進捗) + 恒久ナレッジ (feedback / project / user / reference) | `MEMORY.md` を session-start hook が 200 行まで自動注入。個別 file 本文は `/reload <topic>` で明示復元する |
| Serena memory | write 禁止 (`.serena/memories/`)。過去分の read は可だが新規保存には使わない | — |

`~/.claude/projects/{project}/memory/` は post-compact hook が一時 file (`compact-restore-*.md`) を書く場所のみで、`/reload` がその場で read + rm する使い捨て経路になる (auto-memory の保存先とは別物)。

## Modes (`/memory-save`)

| Mode | 用途 | 書込先 |
|------|------|--------|
| `clear` (default、無引数) | session 終了時の状態を保存する (task / progress / next-action) | `work-context-YYYYMMDD-<topic>.md` + MEMORY.md 1 行 index |
| `<topic>` | 同日同 topic の作業を集約する | 同上 (auto merge / new) |
| `exit` | task が完全に終わった時に呼ぶ。clear の全処理をした上で恒久ナレッジを抽出する | 上記 + `feedback-<slug>.md` / `project-<slug>.md` |

詳細 flow は `commands/memory-save.md` を参照する。

- **Task Diary**: `/memory-save` を明示提案するのは以下のいずれかに当てはまる時のみ。それ以外は `~/.claude/logs/task-diary.log` への自動蓄積で足りる
  - 3 file 以上を変更した
  - 非自明な設計判断を伴う refactor をした
  - incident response をした

## Recording Targets (Compounding Engineering)

misbehavior だけでなく **non-obvious な成功パターン**も記録対象にする。再現性を持たせるための積み上げ改善という考え方だ。

config 側 (CLAUDE.md / skill / hook) を主保存先とし、auto-memory は補助にする。理由は、auto-memory が Claude の自動判断で書かれ古くなりやすいのに対して、config 側は明示的で再現性が高いからだ。

| Type | Example | Primary storage | Supplementary | Write method |
|------|---------|----------------|--------------|--------------|
| Misbehavior (再発防止) | 同じ path error、想定外の file 削除 | CLAUDE.md / skill / hook | `feedback-*.md` (`/memory-save exit`) | User Edit / Claude auto |
| Non-obvious success (再現用) | 試行錯誤で当てた非標準 approach | CLAUDE.md / skill | `feedback-*.md` (`/memory-save exit`) | User instruction / Claude |
| Project constraint / decision | repo から導出できない制約とその理由 | `project-*.md` (`/memory-save exit`) | — | Claude auto (exit 時) |
| Transient work state | 進行中 session の進捗・再開手順 | `work-context-*.md` (`/memory-save` clear/topic) | — | Claude auto |

**Write path notes:**

- **CLAUDE.md / skill / hook**: user が直接 Edit するか、同一会話内で「CLAUDE.md か該当 skill を更新して」と指示された時に Claude が追記する
- **auto-memory (`~/ai-tools/memory/`)**: `/memory-save` が全 mode で個別 file を書く。`exit` mode のみ `feedback-*` / `project-*` の恒久 file を追加抽出する。再現可能な手順や全 session 共通 rule は `/promote` で config 側へ昇格させ、memory 側は削除する
- **housekeeping**: `/memory-clean` が `~/ai-tools/memory/` 配下 (work-context / feedback / project 問わず全 file) を対象に trash / prune / 表記揺れ修正をする (`commands/memory-clean.md` 参照)

config で再現できることは skill / CLAUDE.md を優先する。memory は再現しづらい文脈や進行中の状態を保つ場所だ。

## Relocation pattern (背景、optional)

auto-memory dir が encoded path で人間には辿りづらく、project をまたぐと散逸しやすい。この問題への対処として、auto-memory dir をやめて project / org / user の scope 別に repo 配下や user 私物 dir へ集約する pattern がある。auto-load は失うが、user-readable / git 管理可能 / 横断検索が容易という利得を取る考え方だ。`~/ai-tools/memory/` への一本化はこの pattern の適用結果になる。詳細: `memory-relocation-pattern.md`。
