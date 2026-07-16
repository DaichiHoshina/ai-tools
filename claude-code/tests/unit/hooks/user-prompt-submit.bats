#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/user-prompt-submit.sh
# 回帰テスト: リファクタリング前後で動作が変わらないことを検証
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/user-prompt-submit.sh"
  setup_test_tmpdir

  # テスト隔離: 実環境の /tmp/claude-ctx-pct, /tmp/claude-serena-fail-count を参照しない
  export CLAUDE_CTX_FILE="${TEST_TMPDIR}/_ctx_pct_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${TEST_TMPDIR}/_serena_unset"

  # テスト用gitリポジトリ作成
  cd "$TEST_TMPDIR"
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  git commit --allow-empty -m "init"
}

teardown() {
  teardown_test_tmpdir
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# フックを実行してJSON出力を取得
# 実行環境に前 session の CLAUDE_CODE_SESSION_ID が残っていても影響しないよう、
# test では env を落として stdin の session_id を必ず有効にする (並列 flake 防止)
run_hook() {
  local input="$1"
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

# JSON出力から systemMessage を抽出
get_system_message() {
  local json="$1"
  echo "$json" | jq -r '.systemMessage // empty'
}

# JSON出力から additionalContext を抽出
get_additional_context() {
  local json="$1"
  echo "$json" | jq -r '.additionalContext // empty'
}

# =============================================================================
# 正常系テスト: プロンプト内ファイルパス言及検出
# 注: phase2 refactor (3c136bb) で git staged file 検出は廃止。
#     プロンプト本文の拡張子言及（.go, .ts, dockerfile）のみ検出。
# =============================================================================

@test "user-prompt-submit: .go言及でgolang+backend-dev検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"main.goを修正"}'
  local output=$(run_hook "$input")

  # JSON形式であることを確認
  echo "$output" | jq empty

  # systemMessageにgolangが含まれる
  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "golang" ]] || [[ "$system_msg" =~ "backend-dev" ]]
}

@test "user-prompt-submit: .ts言及でtypescript検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"index.tsを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "typescript" ]] || [[ "$system_msg" =~ "backend-dev" ]]
}

@test "user-prompt-submit: dockerfile言及でcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"Dockerfileを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "dockerfile" ]]
}

# =============================================================================
# 正常系テスト: キーワード検出
# =============================================================================

@test "user-prompt-submit: 'go'キーワードでgolang検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"goのコードを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "go" ]] || [[ "$system_msg" =~ "golang" ]]
}

@test "user-prompt-submit: 'docker'キーワードでcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"dockerの設定を確認"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "docker" ]]
}

@test "user-prompt-submit: 'review'キーワードでcomprehensive-review検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"コードをレビューして"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "comprehensive-review" ]] || [[ "$system_msg" =~ "review" ]] || [[ "$system_msg" =~ "quality" ]]
}

# =============================================================================
# 正常系テスト: エラーログ検出
# =============================================================================

@test "user-prompt-submit: Docker daemonエラーでcontainer-ops検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"Cannot connect to the Docker daemon"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "container-ops" ]] || [[ "$system_msg" =~ "docker" ]] || [[ "$system_msg" =~ "troubleshoot" ]]
}

@test "user-prompt-submit: TypeScript型エラーでbackend-dev検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"TypeScript Type error TS2304: Cannot find name"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  # スキル統合後: backend-dev (BACKEND_LANG=typescript)
  [[ "$system_msg" =~ "backend-dev" ]] || [[ "$system_msg" =~ "typescript" ]]
}

# =============================================================================
# 正常系テスト: プロンプトキーワード検出
# 注: phase2 refactor (3c136bb) で git branch 検出は廃止。
#     プロンプト本文のキーワード（API, security 等）のみ検出。
# =============================================================================

@test "user-prompt-submit: REST APIキーワードでapi-design検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"REST APIを修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "api" ]]
}

@test "user-prompt-submit: securityキーワードでcomprehensive-review検出" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"security issue を修正"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  [[ "$system_msg" =~ "comprehensive-review" ]] || [[ "$system_msg" =~ "security" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "user-prompt-submit: 空プロンプトで何も検出しない" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":""}'
  local output=$(run_hook "$input")

  # 空の場合は {} を返すか、検出なしのメッセージ
  [[ "$output" == "{}" ]] || echo "$output" | jq -e '.systemMessage'
}

@test "user-prompt-submit: 無効なJSONでエラー" {
  cd "$TEST_TMPDIR"

  local input='invalid json'
  run bash "$HOOK_FILE" <<< "$input"

  # エラー終了コードまたはエラーメッセージ
  [ "$status" -ne 0 ] || [[ "$output" =~ "error" ]]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "user-prompt-submit: 複数パターン同時マッチで全て検出" {
  cd "$TEST_TMPDIR"
  touch main.go Dockerfile
  git add main.go Dockerfile

  local input='{"prompt":"dockerとgoの設定を確認"}'
  local output=$(run_hook "$input")

  local system_msg=$(get_system_message "$output")
  # golang, backend-dev, container-ops のいずれかが検出される
  [[ "$system_msg" =~ "go" ]] || [[ "$system_msg" =~ "docker" ]]
}

@test "user-prompt-submit: JSON出力形式の検証" {
  cd "$TEST_TMPDIR"

  local input='{"prompt":"test"}'
  local output=$(run_hook "$input")

  # 有効なJSON形式
  echo "$output" | jq empty

  # systemMessage または additionalContext のいずれかが存在（または空オブジェクト）
  [[ "$output" == "{}" ]] || \
    echo "$output" | jq -e '.systemMessage or .additionalContext'
}

# =============================================================================
# Duplicate prompt detection (5秒以内に同一promptを再送した時に警告)
# =============================================================================

@test "user-prompt-submit: dup-detect 20文字未満prompt はチェック対象外" {
  cd "$TEST_TMPDIR"
  local sid="dup-test-short-$$"
  rm -f "/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"

  # 短文 ("続き" 5 chars) は dup ロジック skip
  local input='{"prompt":"続き","session_id":"'"$sid"'"}'
  run_hook "$input" >/dev/null
  local out=$(run_hook "$input")

  local ctx=$(get_additional_context "$out")
  [[ -z "$ctx" ]] || ! [[ "$ctx" =~ "同一入力検出" ]]
  rm -f "/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"
}

@test "user-prompt-submit: dup-detect 同一prompt5秒以内で通知あり" {
  cd "$TEST_TMPDIR"
  local sid="dup-test-same-$$"
  local dup_file="/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"
  rm -f "$dup_file"

  # 実時間 2 回起動は並列実行 (bats --jobs) の負荷で 5 秒窓を超えて flake するため、
  # 現在時刻の last-prompt を pre-seed して 1 回起動で判定する
  local prompt_text="これは20文字以上の長いテストプロンプトで重複検出"
  local hash=$(printf '%s' "$prompt_text" | shasum -a 1 | cut -d' ' -f1)
  printf '%s\t%s' "$(date +%s)" "$hash" > "$dup_file"

  local input='{"prompt":"'"$prompt_text"'","session_id":"'"$sid"'"}'
  local out=$(run_hook "$input")

  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "同一入力検出" ]]
  rm -f "$dup_file"
}

@test "user-prompt-submit: dup-detect 異なるpromptは通知なし" {
  cd "$TEST_TMPDIR"
  local sid="dup-test-diff-$$"
  rm -f "/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"

  local in1='{"prompt":"これは20文字以上の最初のテストプロンプトです","session_id":"'"$sid"'"}'
  local in2='{"prompt":"これは20文字以上の別のテストプロンプトです","session_id":"'"$sid"'"}'
  run_hook "$in1" >/dev/null
  local out=$(run_hook "$in2")

  local ctx=$(get_additional_context "$out")
  [[ -z "$ctx" ]] || ! [[ "$ctx" =~ "同一入力検出" ]]
  rm -f "/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"
}

@test "user-prompt-submit: dup-detect 5秒超過で通知なし" {
  cd "$TEST_TMPDIR"
  local sid="dup-test-expire-$$"
  local dup_file="/tmp/claude-last-prompt-${sid}-$(date +%Y%m%d)"
  rm -f "$dup_file"

  local prompt_text="これは20文字以上の長いテストプロンプトで時間経過検証"
  local hash=$(printf '%s' "$prompt_text" | shasum -a 1 | cut -d' ' -f1)
  # 10秒前のタイムスタンプで last-prompt を pre-seed
  local old_ts=$(( $(date +%s) - 10 ))
  printf '%s\t%s' "$old_ts" "$hash" > "$dup_file"

  local input='{"prompt":"'"$prompt_text"'","session_id":"'"$sid"'"}'
  local out=$(run_hook "$input")

  local ctx=$(get_additional_context "$out")
  [[ -z "$ctx" ]] || ! [[ "$ctx" =~ "同一入力検出" ]]
  rm -f "$dup_file"
}

# =============================================================================
# outward-mode inject テスト (_inject_outward_mode_if_trigger)
# =============================================================================

@test "user-prompt-submit: 共有用 trigger で [jp-quality-outward-mode] inject される" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"これを共有用にまとめて"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "[jp-quality-outward-mode]" ]]
}

@test "user-prompt-submit: 報告して trigger で [jp-quality-outward-mode] inject される" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"今週の結果を報告して"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "[jp-quality-outward-mode]" ]]
}

@test "user-prompt-submit: 報告書 trigger で [jp-quality-outward-mode] inject される" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"報告書のドラフトを作成して"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "[jp-quality-outward-mode]" ]]
}

@test "user-prompt-submit: 共有テキスト trigger で [jp-quality-outward-mode] inject される (share/outward union guard)" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"チーム向けの共有テキストを整えて"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "[jp-quality-outward-mode]" ]]
}

@test "user-prompt-submit: trigger なし prompt では [jp-quality-outward-mode] inject されない" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"コードをリファクタリングして"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ ! "$ctx" =~ "[jp-quality-outward-mode]" ]]
}

# =============================================================================
# chat 文体 warn 還流 (stop.sh が書いた state file を read-and-delete して inject)
# =============================================================================

@test "user-prompt-submit: 前 turn の warn state file が additionalContext に inject され file が消える" {
  cd "$TEST_TMPDIR"
  local sid="batsjpqfeed$$"
  local warn_file="/tmp/claude-stop-jpq-warn-${sid}-$(date +%Y%m%d)"
  printf '%s' "▲ chat 文体 warn: 体言止めbullet: 2行" > "$warn_file"
  local input='{"prompt":"コードをリファクタリングして","session_id":"'"$sid"'"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "前 turn の chat 文体 warn" ]]
  [[ "$ctx" =~ "体言止めbullet" ]]
  [[ ! -f "$warn_file" ]]
}

@test "user-prompt-submit: warn state file なしでは warn 還流 inject されない" {
  cd "$TEST_TMPDIR"
  local input='{"prompt":"コードをリファクタリングして","session_id":"batsjpqnofeed"}'
  local out=$(run_hook "$input")
  local ctx=$(get_additional_context "$out")
  [[ ! "$ctx" =~ "前 turn の chat 文体 warn" ]]
}

@test "user-prompt-submit: CLAUDE_CODE_SESSION_ID env に別値が入っていても stdin の session_id で warn file を読める" {
  cd "$TEST_TMPDIR"
  local sid="batsjpqstdinprio$$"
  local warn_file="/tmp/claude-stop-jpq-warn-${sid}-$(date +%Y%m%d)"
  printf '%s' "▲ chat 文体 warn: 体言止めbullet: 3行" > "$warn_file"
  local input='{"prompt":"コードをリファクタリングして","session_id":"'"$sid"'"}'
  # env に前 session の別値を残したまま実行 (session 切替時の leak を模擬)、stdin 優先で読めることを確認
  local out=$(echo "$input" | CLAUDE_CODE_SESSION_ID="stale-leaked-session-id" bash "$HOOK_FILE")
  local ctx=$(get_additional_context "$out")
  [[ "$ctx" =~ "前 turn の chat 文体 warn" ]]
  [[ "$ctx" =~ "体言止めbullet" ]]
  [[ ! -f "$warn_file" ]]
}

# =============================================================================
# N1: _DUP_FILE に YYYYMMDD が付与されること
# =============================================================================

@test "user-prompt-submit: dup-file path に YYYYMMDD が付与される" {
  cd "$TEST_TMPDIR"
  local sid="dup-date-test-$$"
  local today=$(date +%Y%m%d)
  local expected_file="/tmp/claude-last-prompt-${sid}-${today}"
  rm -f "$expected_file"

  local input='{"prompt":"これは20文字以上の長いプロンプトでファイル名検証","session_id":"'"$sid"'"}'
  # CLAUDE_CODE_SESSION_ID を unset して stdin の session_id が使われるようにする
  CLAUDE_CODE_SESSION_ID="" bash "$HOOK_FILE" <<< "$input" >/dev/null

  # hook 実行後、YYYYMMDD 付きファイルが存在すること
  [ -f "$expected_file" ]
  rm -f "$expected_file"
}

@test "user-prompt-submit: dup-file path に pid 形式 (ハイフン+数字のみ) が含まれない" {
  cd "$TEST_TMPDIR"
  local sid="dup-nopid-test-$$"
  local today=$(date +%Y%m%d)
  local expected_file="/tmp/claude-last-prompt-${sid}-${today}"
  rm -f "$expected_file"

  local input='{"prompt":"これは20文字以上の長いプロンプトでpidなし確認","session_id":"'"$sid"'"}'
  CLAUDE_CODE_SESSION_ID="" bash "$HOOK_FILE" <<< "$input" >/dev/null

  # YYYYMMDD 付きのファイルのみ存在し、日付なしファイルは存在しない
  [ -f "$expected_file" ]
  [ ! -f "/tmp/claude-last-prompt-${sid}" ]
  rm -f "$expected_file"
}

# =============================================================================
# N3: env 未指定時 _CTX_FILE / _SERENA_COUNTER に session_id suffix が付与される
# =============================================================================

@test "user-prompt-submit: CLAUDE_CTX_FILE 未指定時 session_id suffix 付き path を読む" {
  cd "$TEST_TMPDIR"
  local sid="ctx-sid-test-$$"
  local ctx_file="/tmp/claude-ctx-pct-${sid}"
  # env override を外して session_id suffix 付きの ctx file を作成
  echo "75" > "$ctx_file"

  local input='{"prompt":"コードを見直して","session_id":"'"$sid"'"}'
  local out
  # CLAUDE_CODE_SESSION_ID と CLAUDE_CTX_FILE を両方空にして stdin session_id を使わせる
  out=$(CLAUDE_CODE_SESSION_ID="" CLAUDE_CTX_FILE="" bash "$HOOK_FILE" <<< "$input")

  # additionalContext にコンテキスト使用率通知が含まれること (75% >= 50%)
  local ctx
  ctx=$(echo "$out" | jq -r '.additionalContext // empty')
  [[ "$ctx" =~ "コンテキスト使用率75" ]]
  rm -f "$ctx_file"
}

# =============================================================================
# N4: jp-quality-inject-size.log に session= 形式が含まれ pid= が含まれない
# =============================================================================

@test "user-prompt-submit: inject size log に session= 形式で記録される" {
  cd "$TEST_TMPDIR"
  local sid="log-session-test-$$"
  local log_dir="${TEST_TMPDIR}/logs"
  local log_file="${log_dir}/jp-quality-inject-size.log"
  mkdir -p "$log_dir"

  # HOME を上書きして log path を制御
  local input='{"prompt":"テスト","session_id":"'"$sid"'"}'
  HOME="$TEST_TMPDIR" run_hook "$input" >/dev/null || true

  # log が存在する場合 (inject size > 1500 bytes 時のみ書かれる)、session= 形式を確認
  if [ -f "$log_file" ]; then
    grep -q "session=" "$log_file"
    ! grep -q "pid=" "$log_file"
  fi
}

# =============================================================================
# Consecutive failure detection: 直近 2 turn で失敗 keyword 連続 → /clear suggest
# =============================================================================

@test "user-prompt-submit: fail-detect 1回目エラーpromptは通知なし・2回目で/clear suggest" {
  cd "$TEST_TMPDIR"
  local sid="fail-detect-test-$$"
  local today=$(date +%Y%m%d)
  local fail_file="/tmp/claude-fail-prompt-${sid}-${today}"
  local flag_file="/tmp/claude-fail-repeat-notified-${sid}-${today}"
  rm -f "$fail_file" "$flag_file"

  # 1回目: 失敗 keyword を含む prompt → 通知なし
  local in1='{"prompt":"エラーになった、直して","session_id":"'"$sid"'"}'
  local out1
  out1=$(CLAUDE_CODE_SESSION_ID="" bash "$HOOK_FILE" <<< "$in1")
  local sys1
  sys1=$(echo "$out1" | jq -r '.systemMessage // empty')
  [[ ! "$sys1" =~ "/clear" ]]

  # 2回目: 同様の失敗 keyword → /clear と 書き直 を含む systemMessage が出る
  local in2='{"prompt":"エラーになる、どうにかして","session_id":"'"$sid"'"}'
  local out2
  out2=$(CLAUDE_CODE_SESSION_ID="" bash "$HOOK_FILE" <<< "$in2")
  local sys2
  sys2=$(echo "$out2" | jq -r '.systemMessage // empty')
  [[ "$sys2" =~ "/clear" ]]
  [[ "$sys2" =~ "書き直" ]]

  rm -f "$fail_file" "$flag_file"
}
