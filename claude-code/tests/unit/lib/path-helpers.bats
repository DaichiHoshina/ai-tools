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

@test "_is_memory_path: ~/ghq/<org>/<repo>/memory/ 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ghq/github.com/example-org/example-repo/memory/foo.md'"
  [ "$status" -eq 0 ]
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

# =============================================================================
# _worktree_main_repo / _resolve_worktree_owner_claude_md
# =============================================================================

@test "_worktree_main_repo: worktree → main repo path を返す" {
  local tmp; tmp="$(mktemp -d)"
  local main_repo="${tmp}/org/repo"
  local wt_root="${tmp}/wt1"
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init -q
  git -C "${main_repo}" worktree add "${wt_root}" -q 2>/dev/null

  run bash -c "source '$LIB_FILE' && _worktree_main_repo '${wt_root}'"
  [ "$status" -eq 0 ]
  # realpath 正規化後の main repo と一致 (macOS /tmp → /private/tmp symlink 対策)
  local want; want="$(python3 -c "import os;print(os.path.realpath('${main_repo}'))")"
  [ "$output" = "$want" ]
  rm -rf "$tmp"
}

@test "_worktree_main_repo: 通常 clone (worktree でない) → rc=1" {
  local tmp; tmp="$(mktemp -d)"
  git -C "${tmp}" init -q
  run bash -c "source '$LIB_FILE' && _worktree_main_repo '${tmp}'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm -rf "$tmp"
}

@test "_worktree_main_repo: git 外 → rc=1" {
  local tmp; tmp="$(mktemp -d)"
  run bash -c "source '$LIB_FILE' && _worktree_main_repo '${tmp}'"
  [ "$status" -eq 1 ]
  rm -rf "$tmp"
}

@test "_resolve_worktree_owner_claude_md: org 階層 CLAUDE.md 実在 → path を返す" {
  local tmp; tmp="$(mktemp -d)"
  local org="${tmp}/org"
  local main_repo="${org}/repo"
  local wt_root="${tmp}/wt1"
  mkdir -p "${main_repo}"
  # org 階層 (main repo の親) に owner CLAUDE.md を置く
  printf '# org rule\n' > "${org}/CLAUDE.md"
  git -C "${main_repo}" init -q
  git -C "${main_repo}" worktree add "${wt_root}" -q 2>/dev/null

  run bash -c "source '$LIB_FILE' && _resolve_worktree_owner_claude_md '${wt_root}'"
  [ "$status" -eq 0 ]
  local want; want="$(python3 -c "import os;print(os.path.realpath('${org}'))")/CLAUDE.md"
  [ "$output" = "$want" ]
  rm -rf "$tmp"
}

@test "_resolve_worktree_owner_claude_md: owner CLAUDE.md 不在 → rc=1" {
  local tmp; tmp="$(mktemp -d)"
  local main_repo="${tmp}/org/repo"
  local wt_root="${tmp}/wt1"
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init -q
  git -C "${main_repo}" worktree add "${wt_root}" -q 2>/dev/null

  run bash -c "source '$LIB_FILE' && _resolve_worktree_owner_claude_md '${wt_root}'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  rm -rf "$tmp"
}

@test "_resolve_worktree_owner_claude_md: 通常 clone → rc=1 (worktree でないため skip)" {
  local tmp; tmp="$(mktemp -d)"
  # 親 dir に CLAUDE.md があっても worktree でなければ解決しない
  printf '# x\n' > "${tmp}/CLAUDE.md"
  local repo="${tmp}/repo"
  mkdir -p "${repo}"
  git -C "${repo}" init -q
  run bash -c "source '$LIB_FILE' && _resolve_worktree_owner_claude_md '${repo}'"
  [ "$status" -eq 1 ]
  rm -rf "$tmp"
}
