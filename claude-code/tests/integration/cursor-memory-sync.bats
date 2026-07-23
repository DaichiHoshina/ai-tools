#!/usr/bin/env bats
# =============================================================================
# Integration Tests for cursor/install.sh
#   - install_shared_memory : ~/.cursor/memory symlink
#   - install_commands      : ~/.cursor/commands/*.md per-file symlink
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export INSTALL_SH="${PROJECT_ROOT}/cursor/install.sh"

  TEST_HOME="$(mktemp -d "${BATS_TMPDIR}/cursor-mem-XXXXXX")"
  export TEST_HOME

  export HELPER="${TEST_HOME}/helper.sh"
  {
    echo 'warn() { echo "W: $*"; }'
    echo 'ok() { echo "OK: $*"; }'
    awk '/^install_shared_memory\(\)/,/^}/' "$INSTALL_SH"
    awk '/^link_file\(\)/,/^}/' "$INSTALL_SH"
    awk '/^install_commands\(\)/,/^}/' "$INSTALL_SH"
  } > "$HELPER"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "install_shared_memory: 共有 memory を symlink する" {
  local src="${TEST_HOME}/ai-tools/memory"
  mkdir -p "$src"
  local realsrc="$(cd "$src" && pwd -P)"

  run bash -c "
    source '$HELPER'
    SHARED_MEMORY_SRC='$realsrc'
    CURSOR_MEMORY_LINK='${TEST_HOME}/.cursor/memory'
    mkdir -p '${TEST_HOME}/.cursor'
    install_shared_memory
    readlink '${TEST_HOME}/.cursor/memory'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"$realsrc" ]]
}

@test "install_shared_memory: 2 回目は既にリンク済みで冪等" {
  local src="${TEST_HOME}/ai-tools/memory"
  mkdir -p "$src"
  local realsrc="$(cd "$src" && pwd -P)"

  run bash -c "
    source '$HELPER'
    SHARED_MEMORY_SRC='$realsrc'
    CURSOR_MEMORY_LINK='${TEST_HOME}/.cursor/memory'
    mkdir -p '${TEST_HOME}/.cursor'
    install_shared_memory >/dev/null
    install_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"既にリンク済み"* ]]
}

@test "install_shared_memory: memory 元が無ければ warning で抜ける" {
  run bash -c "
    source '$HELPER'
    SHARED_MEMORY_SRC='${TEST_HOME}/does-not-exist'
    CURSOR_MEMORY_LINK='${TEST_HOME}/.cursor/memory'
    mkdir -p '${TEST_HOME}/.cursor'
    install_shared_memory
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"共有 memory がありません"* ]]
  [ ! -e "${TEST_HOME}/.cursor/memory" ]
}

# --- install_commands -----------------------------------------------------

_make_commands_source() {
  local src="${TEST_HOME}/cursor-src/commands"
  mkdir -p "$src"
  echo "command body" > "${src}/memory-save.md"
  echo "${TEST_HOME}/cursor-src"
}

@test "install_commands: commands/*.md を per-file symlink する" {
  local script_dir
  script_dir=$(_make_commands_source)

  run bash -c "
    source '$HELPER'
    SRC_COMMANDS='${script_dir}/commands'
    CURSOR_COMMANDS_DIR='${TEST_HOME}/.cursor/commands'
    install_commands
    readlink '${TEST_HOME}/.cursor/commands/memory-save.md'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"/commands/memory-save.md" ]]
}

@test "install_commands: 2 回目は既にリンク済みで冪等" {
  local script_dir
  script_dir=$(_make_commands_source)

  run bash -c "
    source '$HELPER'
    SRC_COMMANDS='${script_dir}/commands'
    CURSOR_COMMANDS_DIR='${TEST_HOME}/.cursor/commands'
    install_commands >/dev/null
    install_commands
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"既にリンク済み"* ]]
}

@test "install_commands: commands 元が無ければ warning で抜ける" {
  run bash -c "
    source '$HELPER'
    SRC_COMMANDS='${TEST_HOME}/no-src/commands'
    CURSOR_COMMANDS_DIR='${TEST_HOME}/.cursor/commands'
    install_commands
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"commands/ がありません"* ]]
  [ ! -e "${TEST_HOME}/.cursor/commands" ]
}
