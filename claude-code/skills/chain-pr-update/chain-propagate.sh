#!/usr/bin/env bash
# stacked PR chain の 1 pair を worktree で merge + push する。
#
# こう使う:
#   ./chain-propagate.sh <worktree-dir> <branch> <parent-branch> [grandparent-branch]
#
# こう呼ぶ:
#   ./chain-propagate.sh ~/ghq/worktrees/repo-feature-a feature-a main
#   ./chain-propagate.sh ~/ghq/worktrees/repo-child   child   feature-a main
#
# 中で何をするか:
#   1. worktree で origin/<parent> を fetch する
#   2. 危険 pattern を拒否する (下流先取り check、並列実行 flock)
#   3. merge --no-ff で親を取り込む (rebase は履歴を破壊し force push を強いるので使わない)
#   4. origin/<branch> に push する
#
# 何を禁止するか:
#   - 下流先取りを禁止する。parent が更に上流 (grandparent) と behind の状態で
#     child を merge すると、後で親→子伝播する時に二重 merge と conflict になる。
#     grandparent を第 4 引数で渡すと gate が発動する。
#   - 並列実行を禁止する。同一 repo 内で複数の chain-propagate.sh が同時に走ると
#     "fatal: Unable to write index" や history 破壊を起こす。flock で直列化する。
#
# こんな env で振る舞いを変えられる:
#   CHAIN_SKIP_GRANDPARENT_CHECK=1 を渡すと下流先取り gate を skip する
#     (root branch を main 起点で更新する時のみ許容する)。
#   CHAIN_SKIP_LOCK=1 を渡すと flock を skip する (通常使わない、debug 用)。

set -euo pipefail

wt=$1
branch=$2
parent=$3
grandparent=${4:-}

if [ ! -d "$wt/.git" ] && [ ! -f "$wt/.git" ]; then
  echo "not a git worktree: $wt" >&2
  exit 1
fi

echo "=== $branch <- $parent (in $wt) ==="

if ! git -C "$wt" diff --quiet || ! git -C "$wt" diff --cached --quiet; then
  echo "worktree dirty. stash か commit してから再実行する。" >&2
  git -C "$wt" status --short
  exit 1
fi

current=$(git -C "$wt" rev-parse --abbrev-ref HEAD)
if [ "$current" != "$branch" ]; then
  echo "worktree の HEAD ($current) と指定 branch ($branch) が一致しない。" >&2
  exit 1
fi

if [ -z "${CHAIN_SKIP_LOCK:-}" ]; then
  common_dir=$(git -C "$wt" rev-parse --git-common-dir)
  common_dir_abs=$(cd "$common_dir" && pwd)
  lock_dir="$common_dir_abs/chain-propagate.lock.d"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$lock_dir.flock"
    if ! flock -n 9; then
      echo "他 chain-propagate.sh が同 repo で実行中。並列 push は禁止する。順に実行する。" >&2
      exit 1
    fi
  else
    if ! mkdir "$lock_dir" 2>/dev/null; then
      echo "他 chain-propagate.sh が同 repo で実行中 ($lock_dir)。並列 push は禁止する。" >&2
      echo "本当に死んだ lock なら 'rmdir $lock_dir' で解除する。" >&2
      exit 1
    fi
    trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT INT TERM
  fi
fi

git -C "$wt" fetch origin "$parent" --quiet

if [ -n "$grandparent" ] && [ -z "${CHAIN_SKIP_GRANDPARENT_CHECK:-}" ]; then
  git -C "$wt" fetch origin "$grandparent" --quiet
  parent_behind=$(git -C "$wt" rev-list --count "origin/$parent..origin/$grandparent")
  if [ "$parent_behind" -gt 0 ]; then
    echo "禁止: parent ($parent) が grandparent ($grandparent) に $parent_behind commit behind。" >&2
    echo "先に parent を grandparent へ追従してから再実行する。下流先取りは二重 merge の原因になる。" >&2
    exit 1
  fi
fi

behind=$(git -C "$wt" rev-list --count "$branch..origin/$parent")
if [ "$behind" = "0" ]; then
  echo "already up to date. skip."
  exit 0
fi

merged=0
for attempt in 1 2 3; do
  if git -C "$wt" merge --no-ff "origin/$parent" \
      -m "Merge remote-tracking branch 'origin/$parent' into $branch"; then
    merged=1
    break
  fi
  echo "merge failed (attempt $attempt/3). retry..." >&2
  git -C "$wt" merge --abort 2>/dev/null || true
  sleep 2
done

if [ "$merged" != "1" ]; then
  echo "merge failed after 3 attempts. 手で resolve して commit + push する。" >&2
  exit 1
fi

git -C "$wt" push origin "$branch"
