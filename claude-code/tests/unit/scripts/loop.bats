#!/usr/bin/env bats
#
# loop.sh テストスイート
#
# 方針: PATH 先頭の fake `claude` (env 駆動で挙動切替) と counter 式 fake gate で
#   exit code 規約 (0/2/4/5/6) と state.md の更新を検証する。
#   HOME を tmpdir に差し替え、~/.claude/loops/ への書込を隔離する。
#

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR

  LOOP_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)/scripts/loop.sh"
  export LOOP_SCRIPT

  # HOME 隔離 (state / log の書込先)
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  # test 用 git repo (tracked file 1 つを commit 済み)
  REPO="$TEST_DIR/repo"
  export REPO
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  echo base > "$REPO/file.txt"
  git -C "$REPO" add file.txt
  git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm init

  # fake claude: env 駆動
  #   FAKE_MODE=touch   → repo の tracked file に追記 (進捗あり)
  #   FAKE_MODE=noop    → 何もしない (進捗なし)
  #   FAKE_MODE=corrupt → state.md の必須 heading を破壊
  #   FAKE_COST         → total_cost_usd の値 (default 0.1)
  mkdir -p "$TEST_DIR/bin"
  cat > "$TEST_DIR/bin/claude" <<'FAKE'
#!/usr/bin/env bash
cat > /dev/null
case "${FAKE_MODE:-touch}" in
  touch) echo x >> "$REPO/file.txt" ;;
  corrupt) grep -v '^## Lessons learned' "$FAKE_STATE" > "$FAKE_STATE.t" && mv "$FAKE_STATE.t" "$FAKE_STATE" ;;
  noop) : ;;
esac
printf '{"result":"ok","total_cost_usd":%s}\n' "${FAKE_COST:-0.1}"
FAKE
  chmod +x "$TEST_DIR/bin/claude"
  export PATH="$TEST_DIR/bin:$PATH"

  # PROMPT.md scaffold + state path (fake claude の corrupt 用)
  LOOP_NAME="t1"
  export LOOP_NAME
  mkdir -p "$HOME/.claude/loops/$LOOP_NAME"
  echo "## Objective: test" > "$HOME/.claude/loops/$LOOP_NAME/PROMPT.md"
  FAKE_STATE="$HOME/.claude/loops/$LOOP_NAME/state.md"
  export FAKE_STATE

  # counter 式 fake gate: PASS_AT 回目以降の呼出で exit 0
  GATE_COUNT="$TEST_DIR/gate-count"
  export GATE_COUNT
  cat > "$TEST_DIR/bin/fake-gate" <<'GATE'
#!/usr/bin/env bash
n=$(cat "$GATE_COUNT" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$GATE_COUNT"
[[ "$n" -ge "${PASS_AT:-1}" ]] && exit 0
echo "gate fail (call $n)"
exit 1
GATE
  chmod +x "$TEST_DIR/bin/fake-gate"
}

teardown() {
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

_run_loop() {
  run bash "$LOOP_SCRIPT" --name "$LOOP_NAME" --repo "$REPO" "$@"
}

@test "gate green (iter 1) → exit 0、state done + PASS row" {
  export PASS_AT=1 FAKE_MODE=touch
  _run_loop --gate fake-gate --max-iter 3
  [[ $status -eq 0 ]]
  grep -q '^- Status: done' "$FAKE_STATE"
  grep -q '| 1 | .* | PASS |' "$FAKE_STATE"
}

@test "gate 常時 fail + 進捗あり → max-iter で exit 2" {
  export PASS_AT=999 FAKE_MODE=touch
  _run_loop --gate fake-gate --max-iter 2 --gate-retries 0
  [[ $status -eq 2 ]]
  grep -q '^- Status: aborted(max-iter)' "$FAKE_STATE"
  # FAIL row が 2 行 (iter 1, 2)
  [[ "$(grep -c '| FAIL |' "$FAKE_STATE")" -eq 2 ]]
}

@test "working tree 不変 2 連続 → exit 4 (no-progress)" {
  export PASS_AT=999 FAKE_MODE=noop
  _run_loop --gate fake-gate --max-iter 5 --gate-retries 0
  [[ $status -eq 4 ]]
  grep -q '^- Status: aborted(no-progress)' "$FAKE_STATE"
}

@test "flaky gate (1 回目 fail、2 回目 pass) → --gate-retries 1 で exit 0" {
  export PASS_AT=2 FAKE_MODE=touch
  _run_loop --gate fake-gate --max-iter 3 --gate-retries 1
  [[ $status -eq 0 ]]
  grep -q '^- Status: done' "$FAKE_STATE"
}

@test "agent が state heading を破壊 → .bak 復元 + exit 6" {
  export PASS_AT=999 FAKE_MODE=corrupt
  _run_loop --gate fake-gate --max-iter 3
  [[ $status -eq 6 ]]
  # 復元済み: 必須 heading が残っている
  grep -qF '## Lessons learned' "$FAKE_STATE"
  grep -q '^- Status: aborted(state-corrupt)' "$FAKE_STATE"
}

@test "累積 cost が上限到達 → exit 5" {
  export PASS_AT=999 FAKE_MODE=touch FAKE_COST=3.0
  _run_loop --gate fake-gate --max-iter 10 --max-cost-usd 5 --gate-retries 0
  [[ $status -eq 5 ]]
  grep -q '^- Status: aborted(cost-budget)' "$FAKE_STATE"
}

@test "--dry-run → 組立 prompt を表示して無実行 (gate 呼出 0 回)" {
  export FAKE_MODE=touch
  _run_loop --gate fake-gate --dry-run
  [[ $status -eq 0 ]]
  grep -q 'assembled prompt' <<< "$output"
  [[ ! -f "$GATE_COUNT" ]]
}

@test "PROMPT.md 不在 → exit 1 (usage error)" {
  rm "$HOME/.claude/loops/$LOOP_NAME/PROMPT.md"
  _run_loop --gate fake-gate
  [[ $status -eq 1 ]]
}

@test "gate fail 出力の private term が state 上で REDACT される" {
  mkdir -p "$HOME/.claude/references-private"
  echo "secret-product" > "$HOME/.claude/references-private/private-name-list.txt"
  cat > "$TEST_DIR/bin/leaky-gate" <<'GATE'
#!/usr/bin/env bash
echo "error in secret-product module"
exit 1
GATE
  chmod +x "$TEST_DIR/bin/leaky-gate"
  export FAKE_MODE=touch
  _run_loop --gate leaky-gate --max-iter 1 --gate-retries 0
  [[ $status -eq 2 ]]
  grep -q '\[REDACTED\] module' "$FAKE_STATE"
  ! grep -q 'secret-product' "$FAKE_STATE"
}
