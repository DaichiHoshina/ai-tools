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
  rm -rf "$TEST_TMPDIR"
}
