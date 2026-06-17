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
  # hook が async subshell (&) で起動した孫プロセス (sqlite3 等) が
  # TEST_TMPDIR 配下に書き込み中の場合、macOS の rm -rf が失敗することがある。
  # 短い待機を入れて孫プロセスが終了するまで猶予を与える。
  sleep 0.1
  rm -rf "$TEST_TMPDIR"
}
