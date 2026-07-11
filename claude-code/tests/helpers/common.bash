# bats 共通 helper
# PROJECT_ROOT は claude-code/ ディレクトリ (= ~/ai-tools/claude-code)
PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
export PROJECT_ROOT

# テスト用一時ディレクトリを作成して TEST_TMPDIR に export する
setup_test_tmpdir() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
}

# TEST_TMPDIR を削除する
teardown_test_tmpdir() {
  rm -rf "$TEST_TMPDIR" 2>/dev/null && return 0
  # hook が async subshell (&) で起動した孫プロセス (sqlite3 等) が
  # TEST_TMPDIR 配下に書き込み中の場合、macOS の rm -rf が失敗することがある。
  # 失敗時のみ短い待機を入れて孫プロセスが終了するまで猶予を与える。
  sleep 0.1
  rm -rf "$TEST_TMPDIR"
}

# HOME を tmp dir に隔離する。本番 ~/.claude/logs/ の汚染を防ぐため。
# hooks-integration.bats や session-end.bats など、hook が HOME 配下に書き込む
# 場合に使う。
#
# 副作用:
#   - ORIGINAL_HOME に元 HOME を退避
#   - HOME を mktemp -d で作成した dir に置換
#   - $HOME/.claude/logs, $HOME/.claude/session-logs を作成
#   - CLAUDE_CTX_FILE, CLAUDE_SERENA_FAIL_COUNT を tmp 配下へ (実環境非依存化)
setup_home_isolated() {
  export ORIGINAL_HOME="$HOME"
  export HOME
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude/logs"
  mkdir -p "$HOME/.claude/session-logs"
  # テスト隔離: 実環境の /tmp/claude-ctx-pct, /tmp/claude-serena-fail-count を参照しない
  export CLAUDE_CTX_FILE="${HOME}/_ctx_pct_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${HOME}/_serena_unset"
}

# setup_home_isolated の後始末
teardown_home_isolated() {
  if [[ -n "${ORIGINAL_HOME:-}" ]] && [[ "$HOME" != "$ORIGINAL_HOME" ]] && [[ "$HOME" == /tmp/* || "$HOME" == /var/folders/* ]]; then
    rm -rf "$HOME"
  fi
  if [[ -n "${ORIGINAL_HOME:-}" ]]; then
    export HOME="$ORIGINAL_HOME"
  fi
}
