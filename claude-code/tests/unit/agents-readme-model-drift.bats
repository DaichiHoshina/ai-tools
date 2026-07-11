#!/usr/bin/env bats
# =============================================================================
# agents/README.md の model 列が各 agent frontmatter の model: と一致するか検証する
# drift 再発防止 (2026-07-11: README が sonnet 4.6 のまま frontmatter は sonnet-5 だった)
# =============================================================================

setup() {
  load "../helpers/common"
  export PROJECT_ROOT
  README="${PROJECT_ROOT}/agents/README.md"
}

# model ID → README 表示名
_display_name() {
  case "$1" in
    claude-fable-5) echo "fable 5" ;;
    claude-sonnet-5) echo "sonnet 5" ;;
    claude-opus-4-7) echo "opus 4.7" ;;
    claude-opus-4-8) echo "opus 4.8" ;;
    claude-haiku-4-5) echo "haiku 4.5" ;;
    *) echo "$1" ;;
  esac
}

@test "README model column matches every agent frontmatter" {
  local fail=0
  for f in "${PROJECT_ROOT}"/agents/*.md; do
    local name model expected row
    name="$(basename "$f" .md)"
    [ "$name" = "README" ] && continue
    model="$(grep -m1 '^model:' "$f" | sed 's/^model:[[:space:]]*//')"
    [ -z "$model" ] && continue
    expected="$(_display_name "$model")"
    row="$(grep -F "**${name}**" "$README" || true)"
    if [ -z "$row" ]; then
      echo "MISSING: ${name} not in README table"
      fail=1
    elif ! printf '%s' "$row" | grep -qF "$expected"; then
      echo "DRIFT: ${name} frontmatter=${expected} but README row: ${row}"
      fail=1
    fi
  done
  [ "$fail" -eq 0 ]
}

@test "every agent definition has an inline trailer example (issues_blocking)" {
  local fail=0
  for f in "${PROJECT_ROOT}"/agents/*.md; do
    [ "$(basename "$f")" = "README.md" ] && continue
    if ! grep -q "issues_blocking" "$f"; then
      echo "MISSING trailer example: $(basename "$f")"
      fail=1
    fi
  done
  [ "$fail" -eq 0 ]
}
