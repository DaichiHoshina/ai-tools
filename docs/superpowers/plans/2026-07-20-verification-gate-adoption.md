# verification-before-completion 発火徹底 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** superpowers:verification-before-completion (既に enable 済) の発火を、ai-tools 側 rule / hook と統合して徹底する。「完了」宣言前に検証 command 実行を hard gate 化する。

**Architecture:** plugin skill は既に使える状態なので、install 作業は不要。CLAUDE.md rule 記述 + hook 補助 + trigger 語彙拡充の 3 点で発火頻度と精度を上げる。既存 jp-quality-block hook の「完了」検出 log を効果測定に流用する。

**Tech Stack:** bash hooks (`~/ai-tools/claude-code/hooks/`), CLAUDE.md rule (`~/ai-tools/claude-code/CLAUDE.md`), sync.sh 経路。

## Global Constraints

- **SoT 遵守**: 全 file 修正は `~/ai-tools/claude-code/` 配下で行い、`~/.claude/` は sync.sh 経由でしか触らない
- **worktree 必須**: 実装は `~/ai-tools/` の worktree に切ってから作業する (main 直接 edit 禁止)
- **可逆性優先**: 各 task は revert 可能な粒度で commit する
- **効果指標**: `~/.claude/logs/jp-quality-block.log` の「完了」件数 (現状 141 件 / 週) を beforeafter で計測する
- **既存 hook 非破壊**: jp-quality-block / raw XML guard など既存 hook を壊さない
- **文体**: すべての commit message / doc は `rules/plain-jp.md` に従う (体言止め連発禁止、「完了」で締めない)

---

### Task 1: 前提確認と worktree 準備

**Files:**
- 読取: `~/.claude/settings.json`, `~/ai-tools/claude-code/CLAUDE.md`, `~/ai-tools/claude-code/hooks/stop.sh`
- 作成: (worktree のみ)

**Interfaces:**
- Produces: worktree path `~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate/` (branch `feat/verification-gate`)

- [ ] **Step 1: superpowers plugin enable 状態を再確認**

Run: `grep -E "superpower|verification" ~/.claude/settings.json`
Expected 出力: `"superpowers@superpowers-marketplace": true` を含む

- [ ] **Step 2: verification-before-completion skill 実物を読む**

Run: `head -100 ~/.claude/plugins/cache/superpowers-marketplace/superpowers/6.1.1/skills/verification-before-completion/SKILL.md`
確認: trigger 条件 (「complete」「fixed」「passing」「commit」「PR」直前) と Iron Law を把握

- [ ] **Step 3: worktree 作成**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git worktree add -b feat/verification-gate ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate main
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate
git status
```
Expected: `On branch feat/verification-gate` + clean

- [ ] **Step 4: 現状 baseline 計測 (before 値)**

Run: `wc -l ~/.claude/logs/jp-quality-block.log; grep -c "完了" ~/.claude/logs/jp-quality-block.log`
Expected: 現時点の総 line 数と「完了」出現件数を記録。plan file 末尾の「効果測定」欄に転記

---

### Task 2: CLAUDE.md に verification gate rule を追記

**Files:**
- Modify: `~/ai-tools/claude-code/CLAUDE.md` (末尾 or `## Definition of Done (DoD)` 直後に節追加)

**Interfaces:**
- Consumes: Task 1 で読んだ Iron Law
- Produces: rule 節「Verification before completion」 (後続 hook が参照する keyword を含む)

- [ ] **Step 1: 追記文面を確定**

CLAUDE.md `## Definition of Done (DoD)` 節の直後に以下を追加する:

```markdown
## Verification before completion (evidence before claims)

「完了」「動く」「passing」「fixed」等の success 宣言前に、検証 command を fresh に実行して出力を確認する。command を打っていない状態での宣言を禁止する。canonical: `superpowers:verification-before-completion` skill (既に enable 済)。**gate 発火 trigger**: (a) commit / push / PR 作成前 (b) 「実装した / 修正した / 動くはず / 通るはず」を書く前 (c) subagent の success 報告を採用する前。**gate 動作**: (1) 検証 command を identify (2) 実行 (3) 出力全読 (4) 主張と出力が一致するか照合 (5) 一致したら evidence 付きで宣言する。skip したら「未検証」と明示する。ai-tools 側 hook (`hooks/stop.sh` の DoD check + `jp-quality-block` の「完了」検出) と併走する。
```

- [ ] **Step 2: 追記実行**

Edit tool で ai-tools/claude-code/CLAUDE.md を上記 diff 通り修正

- [ ] **Step 3: 検証 (rule が読める形か)**

Run: `grep -A5 "Verification before completion" ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate/claude-code/CLAUDE.md | head -10`
Expected: 追加した節が表示される

- [ ] **Step 4: commit**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate
git add claude-code/CLAUDE.md
git commit -m "$(cat <<'EOF'
feat(rule): verification gate 節を CLAUDE.md に追加する

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```
Expected: 1 file changed, 3+ insertions

---

### Task 3: stop.sh hook に「完了宣言時の検証実行 reminder」を追加する

**Files:**
- Modify: `~/ai-tools/claude-code/hooks/stop.sh` (「完了」検出時の warning 分岐に 1 行追加)

**Interfaces:**
- Consumes: jp-quality-block.log の warn category `完了,Gate`
- Produces: turn 締めで「完了」検出時に verification-before-completion skill 発火を促す reminder 出力

- [ ] **Step 1: stop.sh の「完了」検出箇所を特定**

Run:
```bash
grep -n "完了\|jp-quality\|verification" ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate/claude-code/hooks/stop.sh | head -20
```
Expected: 該当 line number 一覧

- [ ] **Step 2: 既存の「完了」warn 分岐を read**

Run: `sed -n '<Step1で特定した lineの前後20行>' ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate/claude-code/hooks/stop.sh`
確認: 既存の warn 出力 format と、追記位置を決める

- [ ] **Step 3: reminder 出力を追記**

Edit tool で以下を該当 warn 分岐の直後に追加する (実際の関数名 / 変数名は Step 2 の read 結果に合わせて調整):

```bash
echo "[verification-gate] '完了' 系語を検出した。superpowers:verification-before-completion の Iron Law に従い、宣言前に検証 command を実行しているか確認する。未検証なら '未検証' と明示する。" >&2
```

**注意**: block ではなく warn (exit 0 で reminder のみ)。既存 jp-quality-block hook を壊さないよう、既存 warn の直後に追加する形にする。

- [ ] **Step 4: 手動発火試験**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate
# stop.sh を fake input で叩く (実装済みなら) or 次回 turn 締めで実挙動を観察
bash -n claude-code/hooks/stop.sh  # syntax check のみ
```
Expected: syntax error 無し (実発火試験は sync 後に別 session で行う)

- [ ] **Step 5: commit**

Run:
```bash
git add claude-code/hooks/stop.sh
git commit -m "$(cat <<'EOF'
feat(hook): '完了' 検出時に verification-gate reminder を出す

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: sync 実行と実発火確認

**Files:**
- 実行のみ (edit 無し)

**Interfaces:**
- Consumes: Task 2 + 3 で作った CLAUDE.md + stop.sh の変更
- Produces: `~/.claude/CLAUDE.md` および `~/.claude/hooks/stop.sh` に反映

- [ ] **Step 1: sync 実行**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate
bash claude-code/sync.sh
```
Expected: `~/.claude/CLAUDE.md` に新節、`~/.claude/hooks/stop.sh` に reminder line が反映される

- [ ] **Step 2: 反映確認**

Run:
```bash
grep "Verification before completion" ~/.claude/CLAUDE.md
grep "verification-gate" ~/.claude/hooks/stop.sh
```
Expected: 両方 hit する

- [ ] **Step 3: 実挙動確認 (別 session を開いて手動試験)**

user に依頼する: 「新 session を開いて、末尾を『実装完了。』で締めるだけの test turn を 1 回投げてほしい。stop hook が verification-gate reminder を出すか確認する」

Expected: stop hook stderr に `[verification-gate] '完了' 系語を検出...` が出力される (session 内では見えないので、`~/.claude/logs/stop-hook.log` 等の hook log に残るか user に確認依頼)

---

### Task 5: main merge + 効果測定 baseline 記録

**Files:**
- 更新: `docs/superpowers/plans/2026-07-20-verification-gate-adoption.md` の末尾に「効果測定」欄追加

**Interfaces:**
- Consumes: Task 1 Step 4 の before 値、Task 4 の反映結果
- Produces: 1 週間後 (2026-07-27) に after 値を計測する予約

- [ ] **Step 1: main へ ff-merge (ai-tools は worktree flow で main に戻す)**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git merge --ff-only feat/verification-gate
git status
```
Expected: fast-forward 成功

- [ ] **Step 2: worktree 削除**

Run:
```bash
git worktree remove ~/ghq/github.com/DaichiHoshina/ai-tools.wt/verification-gate
git branch -d feat/verification-gate
git worktree list
```
Expected: worktree list から消える

- [ ] **Step 3: 効果測定欄を plan に追記**

Edit tool で plan file 末尾に:
```markdown
## 効果測定

- **before (2026-07-20 記録)**: jp-quality-block.log 総 line 数 <Task 1 Step 4 の値>、うち「完了」出現 <Task 1 Step 4 の値> 件
- **after (2026-07-27 予定)**: 同 command で再計測、before との差分を記録
- **判定基準**: 「完了」件数が減少 → 効果あり (verification gate が実際に完了宣言を抑制した)。横ばい / 増加 → hook 設計を見直す
- **副作用監視**: jp-quality-block.log に verification-gate 起因の新規 warn / block が発生していないか、`grep verification-gate ~/.claude/logs/jp-quality-block.log` で 1 週間後に確認
```

- [ ] **Step 4: 最終 commit + push**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git add docs/superpowers/plans/2026-07-20-verification-gate-adoption.md
git commit -m "$(cat <<'EOF'
docs(plan): verification-gate 効果測定欄を追記する

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push
```
Expected: push 成功

---

## Rollback 手順

問題発生時は Task 2-3 の 2 commit を revert すれば元に戻る:

```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git revert <verification-gate 関連 commit ×2>
bash claude-code/sync.sh
```

## 未確定事項

- Task 3 の hook 追記が既存 jp-quality-block と重複 warn を出す可能性 → 実発火試験 (Task 4 Step 3) で確認して、二重出力なら片方 suppress する調整を追加 task に切る
- 効果指標「完了」件数減少が本 gate 効果か他要因 (session 数変動) かの切り分けは、after 計測時に session 数も併記して比率で見る
