#!/bin/bash
# =============================================================================
# BATS Self-Check (pass-by-coincidence detection)
#
# .bats file editing detects pass-by-coincidence patterns and outputs
# violation block line numbers.
#
# Usage:
#   source bats-self-check.sh
#   run_bats_check "/path/to/test.bats"
#
# Output:
#   violations: "L<line>: <@test line>" per line to stdout
#   no violations: empty output (exit 0)
# =============================================================================

run_bats_check() {
  local file_path="${1:-}"

  if [[ -z "${file_path}" ]] || [[ ! -f "${file_path}" ]]; then
    return 0
  fi

  _bats_check_impl "$file_path"
  return 0
}

_bats_check_impl() {
  local file_path="$1"

  local in_test=0
  local test_line=0
  local block=""
  local line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))

    if [[ "$line" =~ ^@test ]]; then
      if [ $in_test -eq 1 ] && [[ -n "$block" ]]; then
        _check_violation "$test_line" "$block"
      fi
      in_test=1
      test_line=$line_num
      block="$line"
    elif [ $in_test -eq 1 ]; then
      block+=$'\n'"$line"
      if [[ "$line" =~ ^\} ]]; then
        _check_violation "$test_line" "$block"
        in_test=0
        block=""
      fi
    fi
  done < "$file_path"

  if [ $in_test -eq 1 ] && [[ -n "$block" ]]; then
    _check_violation "$test_line" "$block"
  fi
}

_check_violation() {
  local test_line="$1"
  local block="$2"

  local has_run=0
  local has_real_assert=0

  # run keyword check or bash -c invocation
  # NOTE: BSD grep (macOS) は `\s` 非対応のため [[:space:]] を使う
  if grep -E '^[[:space:]]*run[[:space:]]+|bash[[:space:]]+-c' <<< "$block" > /dev/null 2>&1; then
    has_run=1
  fi

  # real assert check (出力値 / nameref / bash -c source 経由の実値検証)
  # shellcheck disable=SC2016 # $output / $result はリテラルとして grep する意図
  if grep -E '\[\[.*\$output' <<< "$block" > /dev/null 2>&1 || \
     grep -E 'result=.*\$\(bash' <<< "$block" > /dev/null 2>&1 || \
     grep -E '\[\[.*\$result' <<< "$block" > /dev/null 2>&1; then
    has_real_assert=1
  fi

  # pattern 1: no run + weak assert only
  if [ $has_run -eq 0 ]; then
    if grep -E '^[[:space:]]*\[[[:space:]]*-f[[:space:]]+' <<< "$block" > /dev/null 2>&1 && [ $has_real_assert -eq 0 ]; then
      echo "L${test_line}: $(echo "$block" | head -1)"
      return 0
    fi
    if grep -E 'grep[[:space:]]+-q' <<< "$block" > /dev/null 2>&1 && [ $has_real_assert -eq 0 ]; then
      echo "L${test_line}: $(echo "$block" | head -1)"
      return 0
    fi
    # shellcheck disable=SC2016 # $status はリテラル検索
    if grep -E '^[[:space:]]*\[[[:space:]]*"\$status"[[:space:]]*-eq' <<< "$block" > /dev/null 2>&1 && [ $has_real_assert -eq 0 ]; then
      echo "L${test_line}: $(echo "$block" | head -1)"
      return 0
    fi
  fi

  # pattern 2: binary assert
  # shellcheck disable=SC2016 # $status はリテラル検索
  if grep -E '\[[[:space:]]*"\$status"[[:space:]]*-eq[[:space:]]*[0-9][[:space:]]*\][[:space:]]*\|\|[[:space:]]*\[[[:space:]]*"\$status"[[:space:]]*-eq' <<< "$block" > /dev/null 2>&1; then
    echo "L${test_line}: $(echo "$block" | head -1)"
    return 0
  fi

  # pattern 3: grep suppress (`grep -q ... || true`)
  if grep -E 'grep[[:space:]]+-q.*\|\|[[:space:]]*true' <<< "$block" > /dev/null 2>&1; then
    echo "L${test_line}: $(echo "$block" | head -1)"
    return 0
  fi

  # pattern 4: echo 'ok' tail
  if echo "$block" | tail -2 | head -1 | grep -qE "^[[:space:]]*echo[[:space:]]+['\"]ok['\"]"; then
    echo "L${test_line}: $(echo "$block" | head -1)"
    return 0
  fi

  return 0
}
