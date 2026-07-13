#!/usr/bin/env bats
# =============================================================================
# session-start.sh: linked worktree の owner CLAUDE.md auto-load
# =============================================================================
# 背景: linked worktree は親 org dir の外にあり owner CLAUDE.md が auto-load
# されない。session-start hook が worktree を検知し owner CLAUDE.md の中身を
# additionalContext に注入することを固定する。真の git worktree fixture を使い、
# path 文字列 match でなく実 git rev-parse 経路を通す。
# =============================================================================

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  HOOK="${PROJECT_ROOT}/hooks/session-start.sh"
  # 各 test の HOME 隔離 (cache dir を汚さない)
  TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.claude/cache" "${TEST_HOME}/.claude/logs"
}

teardown() {
  [ -n "${TEST_HOME:-}" ] && chmod -R u+w "${TEST_HOME}" 2>/dev/null; rm -rf "${TEST_HOME}"
  [ -n "${FIX_TMP:-}" ] && chmod -R u+w "${FIX_TMP}" 2>/dev/null; rm -rf "${FIX_TMP}"
}

# org dir + main repo + worktree fixture を作る。owner CLAUDE.md の有無は $1 で制御。
_make_worktree_fixture() {
  local with_owner="$1"
  FIX_TMP="$(mktemp -d)"
  local org="${FIX_TMP}/org"
  local main_repo="${org}/repo"
  WT_ROOT="${FIX_TMP}/wt1"
  mkdir -p "${main_repo}"
  [ "$with_owner" = "yes" ] && printf '# ORG-RULE-MARKER\nmemory は ai-tools へ\n' > "${org}/CLAUDE.md"
  git -C "${main_repo}" init -q
  # worktree の HEAD を有効にするため add 前に commit を 1 つ作る
  git -C "${main_repo}" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
  git -C "${main_repo}" worktree add "${WT_ROOT}" -q 2>/dev/null
}

_run_hook() {
  local cwd="$1"
  echo "{\"session_id\":\"test-sess\",\"cwd\":\"${cwd}\"}" \
    | env HOME="${TEST_HOME}" bash "${HOOK}" 2>/dev/null
}

@test "session-start: worktree で owner CLAUDE.md の中身が additionalContext に注入される" {
  _make_worktree_fixture yes
  run _run_hook "${WT_ROOT}"
  [ "$status" -eq 0 ]
  local ac; ac="$(printf '%s' "$output" | jq -r '.additionalContext')"
  # owner CLAUDE.md 内の marker が注入されている
  echo "$ac" | grep -q "ORG-RULE-MARKER"
  echo "$ac" | grep -q "linked worktree で作業中"
}

@test "session-start: 通常 clone (worktree でない) では注入されない" {
  FIX_TMP="$(mktemp -d)"
  local org="${FIX_TMP}/org"
  local repo="${org}/repo"
  mkdir -p "${repo}"
  printf '# ORG-RULE-MARKER\n' > "${org}/CLAUDE.md"
  git -C "${repo}" init -q
  git -C "${repo}" -c user.email=t@t -c user.name=t commit --allow-empty -m init -q
  run _run_hook "${repo}"
  [ "$status" -eq 0 ]
  local ac; ac="$(printf '%s' "$output" | jq -r '.additionalContext')"
  ! echo "$ac" | grep -q "linked worktree で作業中"
}

@test "session-start: owner CLAUDE.md 不在 org の worktree では skip される" {
  _make_worktree_fixture no
  run _run_hook "${WT_ROOT}"
  [ "$status" -eq 0 ]
  local ac; ac="$(printf '%s' "$output" | jq -r '.additionalContext')"
  ! echo "$ac" | grep -q "linked worktree で作業中"
}

@test "session-start: 2 回目は cache から返る (owner CLAUDE.md 更新なし)" {
  _make_worktree_fixture yes
  _run_hook "${WT_ROOT}" >/dev/null
  # cache file が生成されている
  local cache_glob="${TEST_HOME}/.claude/cache/wt-owner-claude-"*
  run bash -c "ls ${cache_glob} 2>/dev/null | head -1"
  [ -n "$output" ]
  # 2 回目も marker が出る
  run _run_hook "${WT_ROOT}"
  local ac; ac="$(printf '%s' "$output" | jq -r '.additionalContext')"
  echo "$ac" | grep -q "ORG-RULE-MARKER"
}
