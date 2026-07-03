---
allowed-tools: Bash, Read, Write, Edit, Agent, AskUserQuestion, TaskCreate, TaskUpdate
argument-hint: "<src-dir> [--apply] [--keep-src]"
description: 他 repo の memory から汎用 knowledge を抽出し ai-tools 側 (rules / guidelines / SKILL / memory) に反映する。既定は dry-run、`--apply` で採用 + 元 file 削除 + cross-ref 差替を実行する。
effort: medium
---

# /memory-import - 他 repo memory の汎用 knowledge 切り出し

`<src-dir>` (別 repo の `memory/` 配下) を scan し、汎用性の高い feedback / pattern を ai-tools 側の canonical file に反映する。採用後は元 file を削除し、生きた feedback からの cross-ref を ai-tools canonical への差替に置換する。

**Policy**:
- **汎用性 high のみ採用**: repo / user 依存しない rule / pattern に限る。単発 incident / project 固有情報は除外
- **非機密**: 社内 product 名 / 個人名 / 会社名 / 固有 path を含まない、または trivial に伏字化できる
- **既存 ai-tools と非重複**: `rules/` `guidelines/` `memory/` `skills/` に既に cover 済のものは skip
- **default dry-run**: 候補提示のみ、`--apply` で反映

## Arguments

| arg | 動作 |
|---|---|
| `<src-dir>` | 他 repo の memory root (例: `~/ghq/github.com/<org>/memory/`)。subdir 混在可 |
| (none) / `--dry-run` | 候補提示のみ (default) |
| `--apply` | 採用 file 反映 + 元 file 削除 + cross-ref 差替 |
| `--keep-src` | `--apply` 時も元 file を削除しない (反映のみ) |

## Flow

### Stage 1: scan + 抽出 (fan-out)

1. `<src-dir>` 配下 subdir を列挙 (`_org` / project 別 dir 等)
2. subdir ごとに `explore-agent` を並列 fan-out (parallelism = subdir 数、max 8)。各 agent への prompt:
   - 全 file を read、汎用性 high の候補を抽出
   - 除外基準: 固有名詞含み / 既存 ai-tools rule と重複 / 単発 log
   - 出力: 候補 file / 提案先 (rules / guidelines / SKILL / memory) / 汎用化後の要旨 / 伏字化対象
3. 結果を Tier 分類:
   - **Tier A**: `rules/` `guidelines/` に独立 file / 独立追記
   - **Tier B**: 既存 file への追記型 (差分小)
   - **Tier C**: `memory/` の feedback として保存
4. chat に一覧表示、user に採用 tier 選択させる (`AskUserQuestion` で 1 括採用 / 段階採用 / 個別選抜)

### Stage 2: `--apply` 実行

1. 対象 tier の各 file について、canonical 反映 (`Write` 新規 or `Edit` 追記)
2. 元 file 削除: `rm <src-dir>/<subdir>/<file>` (`--keep-src` なら skip)
3. 元 repo の MEMORY.md index prune: 削除 file の行を `sed` で除去
4. 生きた feedback からの dead cross-ref 修正:
   - 削除 file への `[[name]]` 参照を全 scan
   - ai-tools canonical への差替 (例: `[[foo]]` → ``ai-tools `rules/foo.md` — <説明>``)
   - work-context / .trash 系の履歴 log 内の dead ref は触らない (履歴保持)
5. 完了報告: 反映 file 数 / 削除 file 数 / 差替 cross-ref 数

## 抽出基準 (agent への prompt に含める)

- **汎用性**: どの repo / どの user でも通用する rule / pattern (例: git 運用 / commit 規約 / hook 設計 / test pattern)
- **非機密**: 社内 product 名 / 個人名 / repo path / URL を含まない、または trivial に伏字化できる
- **既存 ai-tools と非重複**: 以下を既知知識として渡す
  - `~/ai-tools/claude-code/CLAUDE.md` global rules
  - `~/ai-tools/claude-code/rules/*.md`
  - `~/ai-tools/claude-code/guidelines/writing/*.md`
  - `~/ai-tools/memory/feedback_*.md`
- **再利用価値**: 単発 incident の記録ではなく、rule / pattern として抽象化されている

## 出力 format (各 agent が返す形式)

```
### 候補 N: <slug>
- 元 file: <subdir>/<name>.md
- 汎用化後の要旨 (2-3 行、常体 plain JP)
- 提案先: rules/ or guidelines/ or SKILL/ or memory/
- 汎用性 confidence: high / medium / low
- 伏字化必要な固有名詞: あり (具体名列挙) / なし
```

候補ゼロなら「該当なし」と明記させる (捻出させない)。

## 適用範囲

- 他 repo (組織 repo / 個人 repo) の memory から ai-tools への切り出し
- 元 repo が git 対象外の memory dir でも動作 (削除の可逆性は `--keep-src` で確保)

## 前提と回避

- ai-tools は public repo、**社内 product 名 / 社内識別子 / 個人名 / 会社名を含む候補は不採用**
- 汎用化後の canonical file は `rules/public-repo-private-data-block.md` に従い伏字化する
- 元 file 削除は不可逆、`--apply` 前に dry-run で必ず確認する
- 大量削除時は git 対象 dir なら事前に commit しておくと rollback が効く

## 参照

- `/memory-clean` — 自 memory の orphan / dead cross-ref audit
- `/memory-save` — 個別 feedback 追加
- `rules/public-repo-private-data-block.md`
- `guidelines/writing/README.md`
