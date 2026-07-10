#!/usr/bin/env bats
# =============================================================================
# Integration Tests: sync.sh overwrite guard (from-local 専用)
# 過去 incident: from-local 誤実行で repo の guideline 4 file が古い content に上書き。
# guard は from-local のみ適用。to-local は ~/.claude 側 wipe が仕様。
# ケース1: 差分なし → guard pass (exit 0)
# ケース2: 差分あり + --allow-overwrite なし → guard block (exit 1)
# ケース3: 差分あり + --allow-overwrite → guard pass (exit 0)
# =============================================================================

# shellcheck shell=bash

setup() {
    # 隔離用ディレクトリを mktemp で作成（本物の ~/.claude を汚さない）
    export TEST_TMPDIR
    TEST_TMPDIR="$(mktemp -d)"

    # テスト用 CLAUDE_DIR と SCRIPT_DIR を隔離環境に作成
    export TEST_CLAUDE_DIR="${TEST_TMPDIR}/dot_claude"
    export TEST_SCRIPT_DIR="${TEST_TMPDIR}/claude_code"
    mkdir -p "${TEST_CLAUDE_DIR}"
    mkdir -p "${TEST_SCRIPT_DIR}"

    # PROJECT_ROOT: tests/integration から ../../.. で ai-tools ルートへ
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"

    # 最小限の同期対象ファイルを repo 側 (TEST_SCRIPT_DIR) に配置
    echo "v1.0.0" > "${TEST_SCRIPT_DIR}/VERSION"
    echo "content_a" > "${TEST_SCRIPT_DIR}/CLAUDE.md"
    mkdir -p "${TEST_SCRIPT_DIR}/commands"
    echo "cmd_content" > "${TEST_SCRIPT_DIR}/commands/test-cmd.md"

    # _check_overwrite_guard をテスト用に呼び出すヘルパースクリプトを生成
    # sync.sh 本体から関数定義部分を sed で抽出し、必要な stub と合わせて実行する
    export GUARD_RUNNER="${TEST_TMPDIR}/run_guard.sh"
    cat > "${GUARD_RUNNER}" << 'RUNNER_EOF'
#!/bin/bash
set -euo pipefail
# 引数: src_dir dst_dir allow_overwrite [sync_items...]
SRC_DIR="$1"; DST_DIR="$2"; ALLOW_OVERWRITE="$3"; shift 3
SYNC_ITEMS=("$@")

# 依存 stub
has_gh_skill_metadata() { return 1; }
print_error()   { echo "[ERR] $*" >&2; }
print_warning() { echo "[WARN] $*" >&2; }
print_info()    { echo "[INFO] $*" >&2; }
YELLOW="" GREEN="" BLUE="" NC=""

# SCRIPT_DIR / CLAUDE_DIR を引数で注入
SCRIPT_DIR="$SRC_DIR"
CLAUDE_DIR="$DST_DIR"

# _check_overwrite_guard と _guard_mode_hint を sync.sh から抽出して実行
RUNNER_EOF

    # sync.sh から _check_overwrite_guard / _guard_mode_hint / resolve_item_path の関数本体を抽出
    python3 - "${PROJECT_ROOT}/claude-code/sync.sh" >> "${GUARD_RUNNER}" << 'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

# 関数定義を抽出: _check_overwrite_guard と _guard_mode_hint
pattern = re.compile(
    r'^(_check_overwrite_guard\(\)|_guard_mode_hint\(\)|resolve_item_path\(\))\s*\{.*?\n\}',
    re.MULTILINE | re.DOTALL
)
for m in pattern.finditer(content):
    print(m.group(0))
    print()
PYEOF

    cat >> "${GUARD_RUNNER}" << 'RUNNER_EOF2'

_check_overwrite_guard "$SRC_DIR" "$DST_DIR" "$ALLOW_OVERWRITE"
RUNNER_EOF2
    chmod +x "${GUARD_RUNNER}"
}

teardown() {
    rm -rf "${TEST_TMPDIR}"
}

# =============================================================================
# ケース 1: 差分なし → guard pass (exit 0)
# =============================================================================

@test "overwrite-guard: 差分なし → exit 0 でパスする" {
    # TEST_CLAUDE_DIR を TEST_SCRIPT_DIR と同一内容に揃える
    cp "${TEST_SCRIPT_DIR}/VERSION" "${TEST_CLAUDE_DIR}/VERSION"
    cp "${TEST_SCRIPT_DIR}/CLAUDE.md" "${TEST_CLAUDE_DIR}/CLAUDE.md"
    mkdir -p "${TEST_CLAUDE_DIR}/commands"
    cp "${TEST_SCRIPT_DIR}/commands/test-cmd.md" "${TEST_CLAUDE_DIR}/commands/test-cmd.md"

    run bash "${GUARD_RUNNER}" \
        "${TEST_SCRIPT_DIR}" "${TEST_CLAUDE_DIR}" "false" \
        "VERSION" "CLAUDE.md" "commands"
    [ "$status" -eq 0 ]
}

# =============================================================================
# ケース 2: 差分あり + --allow-overwrite なし → exit 1 + file path を含む
# =============================================================================

@test "overwrite-guard: 差分あり + allow_overwrite=false → exit 1 かつ差分 file path を出力" {
    # dst (CLAUDE_DIR) 側に直編集が存在する状態を作る
    cp "${TEST_SCRIPT_DIR}/VERSION" "${TEST_CLAUDE_DIR}/VERSION"
    cp "${TEST_SCRIPT_DIR}/CLAUDE.md" "${TEST_CLAUDE_DIR}/CLAUDE.md"
    echo "locally_edited_content" >> "${TEST_CLAUDE_DIR}/CLAUDE.md"
    mkdir -p "${TEST_CLAUDE_DIR}/commands"
    cp "${TEST_SCRIPT_DIR}/commands/test-cmd.md" "${TEST_CLAUDE_DIR}/commands/test-cmd.md"

    run bash "${GUARD_RUNNER}" \
        "${TEST_SCRIPT_DIR}" "${TEST_CLAUDE_DIR}" "false" \
        "VERSION" "CLAUDE.md" "commands"
    [ "$status" -eq 1 ]
    # block メッセージに上書き保護の言及が含まれること
    [[ "$output" =~ "上書き保護" ]]
    # 差分が検出されたファイルのパスが出力に含まれること
    [[ "$output" =~ "CLAUDE.md" ]]
}

# =============================================================================
# ケース 3: 差分あり + --allow-overwrite → exit 0 でパスする
# =============================================================================

@test "overwrite-guard: 差分あり + allow_overwrite=true → exit 0 でパスする" {
    # ケース 2 と同じ差分状態
    cp "${TEST_SCRIPT_DIR}/VERSION" "${TEST_CLAUDE_DIR}/VERSION"
    cp "${TEST_SCRIPT_DIR}/CLAUDE.md" "${TEST_CLAUDE_DIR}/CLAUDE.md"
    echo "locally_edited_content" >> "${TEST_CLAUDE_DIR}/CLAUDE.md"
    mkdir -p "${TEST_CLAUDE_DIR}/commands"
    cp "${TEST_SCRIPT_DIR}/commands/test-cmd.md" "${TEST_CLAUDE_DIR}/commands/test-cmd.md"

    run bash "${GUARD_RUNNER}" \
        "${TEST_SCRIPT_DIR}" "${TEST_CLAUDE_DIR}" "true" \
        "VERSION" "CLAUDE.md" "commands"
    [ "$status" -eq 0 ]
}
