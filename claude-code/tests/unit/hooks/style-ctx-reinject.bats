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

@test "実 hook を 30 turn 分 dry-run 相当で回すと turn 31 で再 inject の証跡がある (counter 経路)" {
  # 既存 flag file 方式 (turn 2 以降 skip) が現行 hook に残っていれば、
  # 「counter file 存在 && 中身が 30 の倍数+1」で INJECT する新経路は fail する。
  # ここでは hook 実装後の期待値だけを assert し、初回 RED は counter file 未実装で file 不存在 → assert 失敗、で作る
  local sess="test-session-reinject"
  local date_today; printf -v date_today '%(%Y%m%d)T' -1
  local counter_file="$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
  # 30 turn 分 counter を進めておく
  printf '30' > "$counter_file"
  # 実 hook を stdin JSON で呼ぶ (session_id は env で渡す)。prompt が空だと hook が早期 exit するため
  # 非空の prompt を持たせる。inject 出力の代わりに counter file の更新だけ検査する
  echo '{"prompt":"hello"}' | TMPDIR="$TMPDIR_T" bash "$HOOK" >/dev/null 2>&1 || true
  local after
  after="$(cat "$counter_file" 2>/dev/null || echo missing)"
  [ "$after" = "31" ]
}

@test "実 hook: 30 turn 分進めた後の呼び出しで inject 文言が stdout に現れる (gate 実発火 lock)" {
  local sess="test-session-reinject-gate"
  local date_today; printf -v date_today '%(%Y%m%d)T' -1
  local counter_file="$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
  printf '30' > "$counter_file"
  export CLAUDE_CODE_SESSION_ID="$sess"
  local out
  out="$(echo '{"prompt":"hello","session_id":"'"$sess"'"}' | TMPDIR="$TMPDIR_T" bash "$HOOK" 2>&1)"
  echo "$out" | grep -q 'chat応答文体強化'
}

@test "実 hook: 30 turn 未満 (turn 15) は inject 文言が stdout に現れない (skip 経路 lock)" {
  local sess="test-session-reinject-skip"
  local date_today; printf -v date_today '%(%Y%m%d)T' -1
  local counter_file="$TMPDIR_T/claude-style-ctx-turn-${sess}-${date_today}"
  printf '15' > "$counter_file"
  export CLAUDE_CODE_SESSION_ID="$sess"
  local out
  out="$(echo '{"prompt":"hello","session_id":"'"$sess"'"}' | TMPDIR="$TMPDIR_T" bash "$HOOK" 2>&1)"
  run bash -c "echo \"\$1\" | grep -q 'chat応答文体強化'" _ "$out"
  [ "$status" -ne 0 ]
}
