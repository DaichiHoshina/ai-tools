#!/usr/bin/env bash
# stdin の private term を [REDACTED] に置換する。term list が空なら素通しする。

redact_private_terms() {
  local term_file="${PRIVATE_TERM_FILE:-${HOME}/.claude/references-private/private-name-list.txt}"
  local sed_args=() term
  if [[ -s "${term_file}" ]]; then
    while IFS= read -r term; do
      [[ -n "${term}" ]] || continue
      sed_args+=(-e "s|${term}|[REDACTED]|g")
    done < "${term_file}"
  fi
  if [[ ${#sed_args[@]} -gt 0 ]]; then sed "${sed_args[@]}"; else cat; fi
}
