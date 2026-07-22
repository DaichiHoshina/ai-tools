#!/usr/bin/env bats
# =============================================================================
# references/command-tree.md に全 command / skill が code span で登場するか検証する
# 照合 key は commands/*.md の basename と skills/ 直下の dir 名に固定する
# (frontmatter name は見ない。dir 名との mismatch で guard 自体が誤検知するため)
# 素の grep だと review / flow 等が一般語に誤マッチするので `name` 形のみ数える
# =============================================================================

setup() {
  load "../helpers/common"
  export PROJECT_ROOT
  TREE="${PROJECT_ROOT}/references/command-tree.md"
}

# code span 登場判定: `name` / `/name` / `/name --flag` / `name (説明` を許容する
_in_tree() {
  grep -Eq "\`/?$1(\`| )" "$TREE"
}

@test "command-tree.md exists" {
  [ -f "$TREE" ]
}

@test "every command appears in command-tree.md as code span" {
  local missing=()
  for f in "${PROJECT_ROOT}"/commands/*.md; do
    local name
    name="$(basename "$f" .md)"
    _in_tree "$name" || missing+=("$name")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "command-tree.md 未登場 command: ${missing[*]}"
    return 1
  fi
}

@test "every skill dir appears in command-tree.md as code span" {
  local missing=()
  for d in "${PROJECT_ROOT}"/skills/*/; do
    local name
    name="$(basename "$d")"
    _in_tree "$name" || missing+=("$name")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "command-tree.md 未登場 skill: ${missing[*]}"
    return 1
  fi
}
