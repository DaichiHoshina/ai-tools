#!/usr/bin/env bats
# =============================================================================
# Integration Tests for codex/install.sh
#   - link_shared_memory   : ~/.codex/memories/shared symlink
#   - sync_managed_block   : AGENTS.md managed marker block sync
#   - doctor_check_shared_memory
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export INSTALL_SH="${PROJECT_ROOT}/codex/install.sh"

  TEST_HOME="$(mktemp -d "${BATS_TMPDIR}/codex-mem-XXXXXX")"
  export TEST_HOME

  # install.sh の関数だけを取り込む（末尾の main 実行を避けるため source ではなく抽出）。
  # print_* は最小 stub を定義する。
  export HELPER="${TEST_HOME}/helper.sh"
  {
    echo 'print_header() { echo "H: $*"; }'
    echo 'print_success() { echo "S: $*"; }'
    echo 'print_warning() { echo "W: $*"; }'
    echo 'print_error() { echo "E: $*"; }'
    echo 'print_info() { echo "I: $*"; }'
    echo 'doctor_success() { echo "DS: $*"; }'
    echo 'doctor_warning() { echo "DW: $*"; DOCTOR_WARNINGS=$((DOCTOR_WARNINGS+1)); }'
    echo 'doctor_error() { echo "DE: $*"; DOCTOR_ERRORS=$((DOCTOR_ERRORS+1)); }'
    # 対象関数を install.sh から抽出する。
    awk '/^link_shared_memory\(\)/,/^}/' "$INSTALL_SH"
    awk '/^sync_managed_block\(\)/,/^}/' "$INSTALL_SH"
    awk '/^doctor_check_shared_memory\(\)/,/^}/' "$INSTALL_SH"
  } > "$HELPER"
}

teardown() {
  rm -rf "$TEST_HOME"
}

# --- link_shared_memory --------------------------------------------------

@test "link_shared_memory: 共有 memory を symlink する" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "${ai}/memory"
  echo "index" > "${ai}/memory/MEMORY.md"

  run bash -c "
    source '$HELPER'
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    link_shared_memory
    readlink '${TEST_HOME}/.codex/memories/shared'
  "
  [ "$status" -eq 0 ]
  # 実 path 正規化されたリンク先を返す
  [[ "$output" == *"/ai-tools/memory" ]]
}

@test "link_shared_memory: 2 回目は既にリンク済みで冪等" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "${ai}/memory"

  run bash -c "
    source '$HELPER'
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    link_shared_memory >/dev/null
    link_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"既にリンク済み"* ]]
}

@test "link_shared_memory: memory 元が無ければ warning で抜ける" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "$ai"  # memory ディレクトリは作らない

  run bash -c "
    source '$HELPER'
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    link_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"共有 memory がありません"* ]]
  [ ! -e "${TEST_HOME}/.codex/memories/shared" ]
}

# --- sync_managed_block --------------------------------------------------

_make_template() {
  cat > "$1" <<'EOF'
# Header

<!-- BEGIN managed:codex-memory -->
### 共有 memory の使い方
new line
<!-- END managed:codex-memory -->

footer
EOF
}

@test "sync_managed_block: マーカー無し実体には末尾追記する" {
  local tpl="${TEST_HOME}/tpl.md"
  local tgt="${TEST_HOME}/tgt.md"
  _make_template "$tpl"
  printf '# 手編集ヘッダ\n本文\n' > "$tgt"

  run bash -c "
    source '$HELPER'
    sync_managed_block '$tpl' '$tgt' 'codex-memory' 'AGENTS.md'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"更新"* ]]
  grep -q "BEGIN managed:codex-memory" "$tgt"
  grep -q "END managed:codex-memory" "$tgt"
  # 手編集は残る
  grep -q "手編集ヘッダ" "$tgt"
}

@test "sync_managed_block: 2 回目は最新で冪等" {
  local tpl="${TEST_HOME}/tpl.md"
  local tgt="${TEST_HOME}/tgt.md"
  _make_template "$tpl"
  printf '# head\n' > "$tgt"

  run bash -c "
    source '$HELPER'
    sync_managed_block '$tpl' '$tgt' 'codex-memory' 'AGENTS.md' >/dev/null
    sync_managed_block '$tpl' '$tgt' 'codex-memory' 'AGENTS.md'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"最新"* ]]
}

@test "sync_managed_block: マーカー外の手編集を保護する" {
  local tpl="${TEST_HOME}/tpl.md"
  local tgt="${TEST_HOME}/tgt.md"
  _make_template "$tpl"
  # 実体に旧ブロック + マーカー外の手編集
  cat > "$tgt" <<'EOF'
# head
手編集メモ
<!-- BEGIN managed:codex-memory -->
### 旧内容
<!-- END managed:codex-memory -->
末尾の手編集
EOF

  run bash -c "
    source '$HELPER'
    sync_managed_block '$tpl' '$tgt' 'codex-memory' 'AGENTS.md'
  "
  [ "$status" -eq 0 ]
  # マーカー内は template で置換される
  grep -q "共有 memory の使い方" "$tgt"
  ! grep -q "旧内容" "$tgt"
  # マーカー外の手編集は保護される
  grep -q "手編集メモ" "$tgt"
  grep -q "末尾の手編集" "$tgt"
}

# --- doctor_check_shared_memory ------------------------------------------

@test "doctor_check_shared_memory: 正しい symlink なら success" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "${ai}/memory"
  echo "x" > "${ai}/memory/MEMORY.md"
  mkdir -p "${TEST_HOME}/.codex/memories"
  ln -s "$(cd "${ai}/memory" && pwd -P)" "${TEST_HOME}/.codex/memories/shared"

  run bash -c "
    source '$HELPER'
    DOCTOR_ERRORS=0; DOCTOR_WARNINGS=0
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    doctor_check_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"リンクされています"* ]]
  [[ "$output" == *"MEMORY.md が読めます"* ]]
  [[ "$output" != *"DE:"* ]]
}

@test "doctor_check_shared_memory: symlink 欠落は warning" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "${ai}/memory"

  run bash -c "
    source '$HELPER'
    DOCTOR_ERRORS=0; DOCTOR_WARNINGS=0
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    doctor_check_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"symlink が見つかりません"* ]]
}

@test "doctor_check_shared_memory: symlink でない実体は error" {
  local ai="${TEST_HOME}/ai-tools"
  mkdir -p "${ai}/memory"
  mkdir -p "${TEST_HOME}/.codex/memories/shared"  # ディレクトリ実体（symlink でない）

  run bash -c "
    source '$HELPER'
    DOCTOR_ERRORS=0; DOCTOR_WARNINGS=0
    AI_TOOLS_DIR='$ai'
    CODEX_DIR='${TEST_HOME}/.codex'
    doctor_check_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"symlink ではありません"* ]]
}
