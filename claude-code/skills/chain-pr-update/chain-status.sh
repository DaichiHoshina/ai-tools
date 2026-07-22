#!/usr/bin/env bash
# stacked PR chain の behind/ahead を一覧表示する。
#
# こう使う:
#   ./chain-status.sh                       # gh pr list から自 open PR chain を自動検出する
#   ./chain-status.sh <root-branch>         # 指定 root から下流を辿る
#   ./chain-status.sh --pairs "a b" "b c"   # 明示的な child parent ペアを列挙する
#
# 各 branch 行に vs parent / behind / ahead を出す。behind>0 の branch が更新候補である。

set -euo pipefail

fetch_all() {
  git fetch origin --quiet 2>/dev/null || true
}

check_pair() {
  local child=$1 parent=$2
  local child_ref="origin/$child" parent_ref="origin/$parent"
  if ! git rev-parse --verify --quiet "$child_ref" >/dev/null; then
    printf "%-50s SKIP (no remote)\n" "$child"
    return
  fi
  if ! git rev-parse --verify --quiet "$parent_ref" >/dev/null; then
    printf "%-50s vs %-30s SKIP (no parent remote)\n" "$child" "$parent"
    return
  fi
  local behind ahead mark=""
  behind=$(git rev-list --count "$child_ref..$parent_ref")
  ahead=$(git rev-list --count "$parent_ref..$child_ref")
  [ "$behind" -gt 0 ] && mark="  <-- behind"
  printf "%-50s vs %-30s behind=%s ahead=%s%s\n" "$child" "$parent" "$behind" "$ahead" "$mark"
}

auto_pairs() {
  gh pr list --author @me --state open --limit 50 \
    --json headRefName,baseRefName \
    --jq '.[] | "\(.headRefName)\t\(.baseRefName)"'
}

fetch_all

if [ "${1:-}" = "--pairs" ]; then
  shift
  for pair in "$@"; do
    read -r child parent <<<"$pair"
    check_pair "$child" "$parent"
  done
elif [ $# -ge 1 ]; then
  root=$1
  echo "root: $root"
  mapfile -t pairs < <(auto_pairs)
  queue=("$root")
  seen=" "
  while [ ${#queue[@]} -gt 0 ]; do
    cur=${queue[0]}
    queue=("${queue[@]:1}")
    case "$seen" in *" $cur "*) continue ;; esac
    seen="$seen$cur "
    for p in "${pairs[@]}"; do
      child=${p%%$'\t'*}
      parent=${p##*$'\t'}
      if [ "$parent" = "$cur" ]; then
        check_pair "$child" "$parent"
        queue+=("$child")
      fi
    done
  done
else
  mapfile -t pairs < <(auto_pairs)
  if [ ${#pairs[@]} -eq 0 ]; then
    echo "no open PRs (or gh not authenticated)"
    exit 0
  fi
  for p in "${pairs[@]}"; do
    child=${p%%$'\t'*}
    parent=${p##*$'\t'}
    check_pair "$child" "$parent"
  done
fi
