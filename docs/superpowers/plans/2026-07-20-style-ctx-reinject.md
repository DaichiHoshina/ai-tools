# STYLE_CTX Re-inject (N turn ごと) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `_STYLE_CTX_FLAG` の「1 session 1 日 1 回だけ inject」を「N turn ごとに再 inject」に置き換える。長 session (150 turn 超) で chat 応答文体強化 reminder が消えて忘却する実害を直撃で塞ぐ。効果は今週入った `recall-surfaced` metric と `jp-quality-block.log` の 100 字超文 warn 数で計測する。

**Architecture:** flag file (`/tmp/claude-style-ctx-<session>-<date>`) を turn counter file (`/tmp/claude-style-ctx-turn-<session>-<date>`) に置き換える。毎 prompt で counter を read → increment → write し、`counter == 1` または `counter % N == 1` (= 1, N+1, 2N+1, ...) のとき inject する。N の初期値は 30。日付切替で自然にリセット、race なし (単一 process 1 turn 1 回)。

**Tech Stack:** bash (既存 hook と同じ)、bats (`claude-code/tests/unit/hooks/`)。

## Global Constraints

- 作業は worktree で行い、完了後 main へ cherry-pick する
- 既存 flag file path (`/tmp/claude-style-ctx-<session>-<date>`) は廃止する。新 counter file path (`/tmp/claude-style-ctx-turn-<session>-<date>`) と区別する
- N は 30 (hardcode 初期値、env override は当面持たない)
- inject 内容 (chat応答文体強化 reminder の text) は変えない。inject 判定 gate だけを変える
- code comment は最小限 (default 書かない / 上限 2 行 / What 言い換え禁止)。既存 `# 1 session 1 回のみ inject する ...` comment は差し替える
- 完了宣言前に fresh bats 実行 → 出力全読 → 主張と一致確認 (verification-before-completion)
- hook が failure で prompt を止めることは絶対にしない (counter file 操作は best-effort、set -euo pipefail 下でも `|| true` で握る)

---

### Task 1: hook の flag file を turn counter file に置き換え、bats を追加する

**Files:**
- Modify: `claude-code/hooks/user-prompt-submit.sh` (232-236 行あたりの STYLE_CTX inject block)
- Create: `claude-code/tests/unit/hooks/style-ctx-reinject.bats`

**Interfaces:**
- Consumes: 既存の `_SESSION_ID` / `_DATE_TODAY` / `_AI_TERMS_LINE` / `_KATAKANA_LINE` / `_AI_TERMS_CTX`
- Produces: `/tmp/claude-style-ctx-turn-<session>-<date>` に integer counter を保持する。counter が 1, 31, 61, ... のとき `_AI_TERMS_CTX` を注入する

#### Step 群

- [ ] **Step 1: bats test を先に書く**

`claude-code/tests/unit/hooks/style-ctx-reinject.bats` を作成する:

```bash
#!/usr/bin/env bats
# STYLE_CTX の N turn 再 inject 挙動を検証する。実 hook を呼ばず、hook が使う分岐条件だけを再現した検証 script を回す

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  HOOK="$REPO_ROOT/hooks/user-prompt-submit.sh"
  TMPDIR_T="$(mktemp -d)"
  export TMPDIR="$TMPDIR_T"
  # 固定 session + 固定 date で counter file path を予測可能にする
  export CLAUDE_CODE_SESSION_ID="test-session-reinject"
  # hook の N=30 分岐を検証するための helper: turn 数だけ counter file を進める
  helper_step() {
    local n="$1"
    local sess="test-session-reinject"
    local date_today
    printf -v date_today '%(%Y%m%d)T' -1
    local counter_file="$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
    local prev
    prev="$(cat "$counter_file" 2>/dev/null || echo 0)"
    prev=$((prev + 1))
    printf '%s' "$prev" > "$counter_file"
    # inject 判定 (hook と同じ式)
    if (( prev == 1 || prev % 30 == 1 )); then
      echo "INJECT"
    else
      echo "SKIP"
    fi
  }
}

teardown() { rm -rf "$TMPDIR_T"; }

@test "turn 1 (最初) は INJECT" {
  run helper_step 1
  [ "$status" -eq 0 ]
  [ "$output" = "INJECT" ]
}

@test "turn 2..30 は SKIP (連続)" {
  helper_step >/dev/null   # turn 1
  local i
  for i in $(seq 2 30); do
    run helper_step
    [ "$status" -eq 0 ]
    [ "$output" = "SKIP" ]
  done
}

@test "turn 31 (2 回目境界) は INJECT" {
  local i
  for i in $(seq 1 30); do helper_step >/dev/null; done
  run helper_step
  [ "$status" -eq 0 ]
  [ "$output" = "INJECT" ]
}

@test "turn 61 (3 回目境界) は INJECT" {
  local i
  for i in $(seq 1 60); do helper_step >/dev/null; done
  run helper_step
  [ "$status" -eq 0 ]
  [ "$output" = "INJECT" ]
}

@test "counter file が破損して非数値なら turn 1 相当で INJECT" {
  local sess="test-session-reinject"
  local date_today; printf -v date_today '%(%Y%m%d)T' -1
  echo "garbage" > "$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
  run helper_step
  [ "$status" -eq 0 ]
  [ "$output" = "INJECT" ]
}
```

- [ ] **Step 2: RED — 未実装 hook 分岐を確認する**

test は helper 内で inject 判定式を持つので、hook 修正前でも一部は pass する。この step は「hook 側の実装が仕様と一致しているか」の確認前段として、下の Step 4 (実 hook 実行) の RED を作る差し替え作業だと位置付ける。

**test 差し替え**: 「turn 5 で hook を呼ぶと INJECT が起きる (現行 flag 方式では 2 回目以降 skip される)」を実 hook で確認する assert を 1 本足す。

同 bats file の末尾に追加:

```bash
@test "実 hook を 30 turn 分 dry-run 相当で回すと turn 31 で再 inject の証跡がある (counter 経路)" {
  # 既存 flag file 方式 (turn 2 以降 skip) が現行 hook に残っていれば、
  # 「counter file 存在 && 中身が 30 の倍数+1」で INJECT する新経路は fail する。
  # ここでは hook 実装後の期待値だけを assert し、初回 RED は counter file 未実装で file 不存在 → assert 失敗、で作る
  local sess="test-session-reinject"
  local date_today; printf -v date_today '%(%Y%m%d)T' -1
  local counter_file="$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
  # 30 turn 分 counter を進めておく
  printf '30' > "$counter_file"
  # 実 hook を stdin 空 JSON で呼ぶ (session_id は env で渡す)。inject 出力の代わりに counter file の更新だけ検査する
  echo '{}' | TMPDIR="$TMPDIR_T" bash "$HOOK" >/dev/null 2>&1 || true
  local after
  after="$(cat "$counter_file" 2>/dev/null || echo missing)"
  [ "$after" = "31" ]
}
```

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/unit/hooks/style-ctx-reinject.bats`
Expected: helper 系 5 tests は pass、実 hook 系 1 test は FAIL (counter file 未実装で `after` が `missing` になる)

- [ ] **Step 3: hook を書き換える**

`claude-code/hooks/user-prompt-submit.sh:230-236` の以下 block:

```bash
    # chat応答向け: AI定型語 + カタカナ造語を参照 1 行に圧縮 (list 展開は NG-DICTIONARY.md canonical へ委譲)
    # 1 session 1 回のみ inject する (毎 prompt 固定費 ~170B × 全 turn 再送を削減、内容は session 内で不変)
    _STYLE_CTX_FLAG="/tmp/claude-style-ctx-${_SESSION_ID:-$$}-${_DATE_TODAY:-0}"
    if [[ ! -f "${_STYLE_CTX_FLAG}" ]] && { [[ -n "${_AI_TERMS_LINE}" ]] || [[ -n "${_KATAKANA_LINE}" ]]; }; then
      _AI_TERMS_CTX="[chat応答文体強化] chat 応答で禁止: AI定型語 / カタカナ造語 / 日本語で言える一般語の英語化 (digest→要約 等) / 体言止めの連発 (単発は可)・助詞省略 / 冗長 (結論と根拠だけ書く)。模範: 「実装完了。テスト通過」→「実装した。テストは通過した」/「robust な設計」→「壊れにくい設計」/「まず A を確認し、次に B」→「A を確認してから B を確認する」。canonical: rules/plain-jp.md + guidelines/writing/NG-DICTIONARY.md。"
      touch "${_STYLE_CTX_FLAG}" 2>/dev/null || true
    fi
```

を以下に置き換える:

```bash
    # AI定型語とカタカナ造語を 1 行の参照に圧縮する。list は NG-DICTIONARY.md へ委譲する。
    # N=30 turn ごとに再 inject して長 session 150 turn 超の忘却を防ぐ。
    _STYLE_CTX_TURN_FILE="${TMPDIR:-/tmp}/claude-style-ctx-turn-${_SESSION_ID:-$$}-${_DATE_TODAY:-0}"
    _STYLE_CTX_TURN="$(cat "${_STYLE_CTX_TURN_FILE}" 2>/dev/null)"
    [[ "${_STYLE_CTX_TURN}" =~ ^[0-9]+$ ]] || _STYLE_CTX_TURN=0
    _STYLE_CTX_TURN=$((_STYLE_CTX_TURN + 1))
    printf '%s' "${_STYLE_CTX_TURN}" > "${_STYLE_CTX_TURN_FILE}" 2>/dev/null || true
    if (( _STYLE_CTX_TURN == 1 || _STYLE_CTX_TURN % 30 == 1 )) && { [[ -n "${_AI_TERMS_LINE}" ]] || [[ -n "${_KATAKANA_LINE}" ]]; }; then
      _AI_TERMS_CTX="[chat応答文体強化] chat 応答で禁止: AI定型語 / カタカナ造語 / 日本語で言える一般語の英語化 (digest→要約 等) / 体言止めの連発 (単発は可)・助詞省略 / 冗長 (結論と根拠だけ書く)。模範: 「実装完了。テスト通過」→「実装した。テストは通過した」/「robust な設計」→「壊れにくい設計」/「まず A を確認し、次に B」→「A を確認してから B を確認する」。canonical: rules/plain-jp.md + guidelines/writing/NG-DICTIONARY.md。"
    fi
```

**主な変更点**:
- flag file (touch のみ) → counter file (integer read/write)
- `[[ ! -f "${_STYLE_CTX_FLAG}" ]]` → `(( _STYLE_CTX_TURN == 1 || _STYLE_CTX_TURN % 30 == 1 ))`
- counter は非数値 (破損) だと 0 として扱い、+1 で 1 になるので inject する (safe fallback)
- path prefix は `TMPDIR` env を尊重 (bats test が `/tmp` 以外に隔離できる)
- 既存の `_STYLE_CTX_FLAG` 変数は廃止する

- [ ] **Step 4: bats 全 test が pass することを確認する**

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/unit/hooks/style-ctx-reinject.bats`
Expected: 6/6 pass (helper 系 5 + 実 hook counter update 1)

sibling test 群への regression 確認:
Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/unit/hooks/user-prompt-submit.bats claude-code/tests/unit/hooks/context-injectors-session-key.bats`
Expected: 全 test pass (STYLE_CTX 経路以外を触っていないので regression しないはず。fail したら書き換えを見直す)

- [ ] **Step 5: 手動 smoke — 実 hook を 2 回連続で叩いて counter file の中身を確認する**

```bash
sess="smoke-$(date +%s)"
CLAUDE_CODE_SESSION_ID="$sess" echo '{}' | bash claude-code/hooks/user-prompt-submit.sh >/dev/null 2>&1 || true
cat "/tmp/claude-style-ctx-turn-${sess}-$(date +%Y%m%d)"
CLAUDE_CODE_SESSION_ID="$sess" echo '{}' | bash claude-code/hooks/user-prompt-submit.sh >/dev/null 2>&1 || true
cat "/tmp/claude-style-ctx-turn-${sess}-$(date +%Y%m%d)"
rm "/tmp/claude-style-ctx-turn-${sess}-$(date +%Y%m%d)"
```

Expected: 1 回目 `1`、2 回目 `2`。counter が正しく increment されている。

- [ ] **Step 6: commit**

```bash
git add claude-code/hooks/user-prompt-submit.sh claude-code/tests/unit/hooks/style-ctx-reinject.bats
git commit -m "feat(hook): STYLE_CTX を 30 turn ごと再 inject に変えて長 session 忘却を塞ぐ"
```

---

### Task 2: 効果測定 target を Verification 節に足す

**Files:**
- Modify: `~/ai-tools/memory/pending-improvements.md` (live memory file、commit 対象外)

**Interfaces:**
- Consumes: 既存の Verification 節、`recall-surfaced` metric
- Produces: Verification 節末尾に「今回 B 実装後の効果測定 target」1-2 行を追加する

- [ ] **Step 1: Verification 節末尾に target を追記する**

`~/ai-tools/memory/pending-improvements.md` の Verification 節末尾 (前回 verification target 群と同じ書式) に以下を追加する:

```markdown
- `jp-quality-block.log` の 100字超文 warn/block: 現 **1275 件 (7 日、7-20 recall-surfaced 導入時計測)** → 30 turn 再 inject 後の 1 週後値と比較する
- `jp-quality-block.log` の 完了 warn: 現 **421 件 (7 日、同上)** → 30 turn 再 inject 後の 1 週後値と比較する
- `recall-surfaced` metric: 現 **2 (100字超文 / 完了)** → 1-2 のまま推移すれば効果あり、増加なら別対策要
```

- [ ] **Step 2: 追記結果を確認する**

```bash
tail -6 ~/ai-tools/memory/pending-improvements.md
```

Expected: 3 行が末尾直前 (直近自動計測 block の前) に入っている。

## 完了後

- worktree から main へ cherry-pick で反映して push する
- 1 週後 (2026-07-27) の週次 verification block と Verification 節 target を突き合わせて効果を判定する
- 効果あり (100字超文 warn 数が減) なら retrospective で `_STYLE_CTX_FLAG` 廃止経路を規範化する。効果なし・悪化なら N の tuning か別対策 (案 C 生成直前 self-check 強制化) に切り替える
