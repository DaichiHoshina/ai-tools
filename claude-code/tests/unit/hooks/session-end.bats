#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/session-end.sh
# state file purge ロジック (STATE_FILE_PATTERNS array + mtime+2 境界) のユニットテスト
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOK_FILE="${PROJECT_ROOT}/hooks/session-end.sh"
  export TEST_TMPDIR="$(mktemp -d)"
  # session-end.sh は HOME/.claude/logs/ 配下を操作するため HOME を差し替え
  export HOME="${TEST_TMPDIR}"
  export LOGS_DIR="${TEST_TMPDIR}/.claude/logs"
  mkdir -p "${LOGS_DIR}"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# 指定した相対 mtime (日数) のスタブ file を作成する
# 引数: filename mtime_days_ago
# macOS: touch -t YYYYMMDDHHmm / GNU: touch -d "N days ago"
_create_stub_file() {
  local fname="$1"
  local days_ago="$2"
  local target="${LOGS_DIR}/${fname}"
  touch "${target}"
  # macOS と Linux の両方に対応: touch -d が使える場合はそちらを優先
  if touch -d "${days_ago} days ago" "${target}" 2>/dev/null; then
    : # GNU touch 成功
  else
    # macOS: stat + touch -t で days_ago 日前の timestamp を設定
    local ts
    ts=$(date -v -"${days_ago}"d '+%Y%m%d%H%M' 2>/dev/null || date --date="${days_ago} days ago" '+%Y%m%d%H%M' 2>/dev/null)
    if [[ -n "$ts" ]]; then
      touch -t "${ts}" "${target}"
    fi
  fi
}

# =============================================================================
# STATE_FILE_PATTERNS array 展開テスト
# =============================================================================

@test "session-end: STATE_FILE_PATTERNS 6 pattern が全て定義されている" {
  # session-end.sh から STATE_FILE_PATTERNS を抽出して 6 件であることを確認
  local count
  count=$(grep -c '"\.[a-z].*-\*"' "${HOOK_FILE}" || true)
  [[ "${count}" -ge 6 ]]
}

# =============================================================================
# mtime+2 境界テスト: 24h 経過 file → 残存
# =============================================================================

@test "session-end: 24h 経過 state file は削除されない (mtime+2)" {
  local fname=".agent-fire-count-test-session-24h"
  _create_stub_file "${fname}" 1
  # hook 実行 (analytics は環境依存なので 2>/dev/null で吸収)
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  # file が残存していること
  [[ -f "${LOGS_DIR}/${fname}" ]]
}

@test "session-end: 24h 経過 .session-split-warned-* は削除されない" {
  local fname=".session-split-warned-abc123-24h"
  _create_stub_file "${fname}" 1
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ -f "${LOGS_DIR}/${fname}" ]]
}

@test "session-end: 24h 経過 .sequential-fire-warned-* は削除されない" {
  local fname=".sequential-fire-warned-def456-24h"
  _create_stub_file "${fname}" 1
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ -f "${LOGS_DIR}/${fname}" ]]
}

# =============================================================================
# mtime+2 境界テスト: 48h+ 経過 file → 削除
# =============================================================================

@test "session-end: 3日 経過 state file は削除される (mtime+2)" {
  local fname=".agent-fire-count-test-session-3d"
  _create_stub_file "${fname}" 3
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ ! -f "${LOGS_DIR}/${fname}" ]]
}

@test "session-end: 3日 経過 .delegation-warned-* は削除される" {
  local fname=".delegation-warned-ghi789-3d"
  _create_stub_file "${fname}" 3
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ ! -f "${LOGS_DIR}/${fname}" ]]
}

@test "session-end: 3日 経過 .large-repo-edit-count-* は削除される" {
  local fname=".large-repo-edit-count-jkl012-3d"
  _create_stub_file "${fname}" 3
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ ! -f "${LOGS_DIR}/${fname}" ]]
}

@test "session-end: 3日 経過 .agent-fire-lastts-* は削除される" {
  local fname=".agent-fire-lastts-mno345-3d"
  _create_stub_file "${fname}" 3
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  [[ ! -f "${LOGS_DIR}/${fname}" ]]
}

# =============================================================================
# ログファイル (.log) は STATE_FILE_PATTERNS 対象外
# =============================================================================

@test "session-end: .log ファイルは purge 対象外 (STATE_FILE_PATTERNS に含まれない)" {
  local fname="hook-errors.log"
  touch "${LOGS_DIR}/${fname}"
  # 3 日前に設定
  _create_stub_file "${fname}" 3
  bash "${HOOK_FILE}" <<< '{}' >/dev/null 2>/dev/null || true
  # .log は STATE_FILE_PATTERNS にないので削除されない
  [[ -f "${LOGS_DIR}/${fname}" ]]
}

# =============================================================================
# hook 出力テスト
# =============================================================================

@test "session-end: 正常終了して JSON systemMessage を出力する" {
  local output
  output=$(bash "${HOOK_FILE}" <<< '{}' 2>/dev/null || true)
  echo "${output}" | grep -q "systemMessage"
}
