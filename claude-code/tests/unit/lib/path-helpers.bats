#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/hook-utils/path-helpers.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils/path-helpers.sh"
}

# =============================================================================
# _is_aitools_path / _aitools_dir
# =============================================================================

@test "path-helpers: sourcing does not produce output" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_aitools_dir: ghq path が存在すれば ghq path を返す" {
  local tmp_home; tmp_home="$(mktemp -d)"
  mkdir -p "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools"
  run env HOME="${tmp_home}" bash -c "source '$LIB_FILE' && _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools" ]
  rm -rf "${tmp_home}"
}

@test "_is_aitools_path: 配下 path を配下と判定する" {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/claude-code"
  echo "$tmp/repo" > "$tmp/root-file"
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='$tmp/root-file' _is_aitools_path '$tmp/repo/claude-code/foo.md'"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "_is_aitools_path: 配下でない path は配下でないと判定する" {
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='/nonexistent' _is_aitools_path '/tmp/unrelated/foo.md'"
  [ "$status" -eq 1 ]
}

# =============================================================================
# _is_memory_path / _is_auto_memory_path / _is_plans_path
# =============================================================================

@test "_is_memory_path: ai-tools/memory 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ai-tools/memory/foo.md'"
  [ "$status" -eq 0 ]
}

@test "_is_memory_path: 通常 path は memory として判定しない" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ai-tools/claude-code/CLAUDE.global.md'"
  [ "$status" -eq 1 ]
}

@test "_is_auto_memory_path: projects/*/memory/ 配下を auto-memory と判定する" {
  run bash -c "source '$LIB_FILE' && _is_auto_memory_path '$HOME/.claude/projects/-foo/memory/bar.md'"
  [ "$status" -eq 0 ]
}

@test "_is_plans_path: ~/.claude/plans/ 配下を plans と判定する" {
  run bash -c "source '$LIB_FILE' && _is_plans_path '$HOME/.claude/plans/x.md'"
  [ "$status" -eq 0 ]
}

@test "_is_plans_path: 配下でない path は plans と判定しない" {
  run bash -c "source '$LIB_FILE' && _is_plans_path '$HOME/other/x.md'"
  [ "$status" -eq 1 ]
}

# =============================================================================
# ensure_worktree_memory_link
# =============================================================================

@test "ensure_worktree_memory_link: target_dir 空 → 何もせず exit 0" {
  run bash -c "source '$LIB_FILE' && ensure_worktree_memory_link ''"
  [ "$status" -eq 0 ]
}

@test "ensure_worktree_memory_link: git repo でない path → 何もせず exit 0" {
  local tmp; tmp="$(mktemp -d)"
  run bash -c "source '$LIB_FILE' && ensure_worktree_memory_link '$tmp'"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "ensure_worktree_memory_link: worktree → memory dir を symlink する" {
  local tmp; tmp="$(mktemp -d)"
  local home="${tmp}/home"
  mkdir -p "${home}/.claude/projects"
  local main_repo="${tmp}/main"
  local wt_root="${tmp}/wt1"
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init -q
  git -C "${main_repo}" config user.email "t@t" -q 2>/dev/null || git -C "${main_repo}" config user.email "t@t"
  git -C "${main_repo}" config user.name "t" 2>/dev/null
  git -C "${main_repo}" worktree add "${wt_root}" -q 2>/dev/null

  run env HOME="${home}" bash -c "source '$LIB_FILE' && ensure_worktree_memory_link '${wt_root}'"
  [ "$status" -eq 0 ]

  local wt_id="${wt_root//\//-}"
  [ -L "${home}/.claude/projects/${wt_id}/memory" ]
  rm -rf "$tmp"
}

# =============================================================================
# 異常系
# =============================================================================

@test "ensure_worktree_memory_link: 無効パス → crash せず exit 0" {
  run bash -c "source '$LIB_FILE' && ensure_worktree_memory_link '/nonexistent/path/xyz'"
  [ "$status" -eq 0 ]
}
