#!/usr/bin/env bash
# config 資産の月次棚卸しを集計する。判断は人間に残す (基準: references/on-demand-rules/toolchain-lifecycle.md)。
# usage: toolchain-health-report.sh [--days N (default 56)] [--out <path>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${CC_ROOT}/.." && pwd)"
DAYS=56
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="${2:?}"; shift 2 ;;
    --out) OUT="${2:?}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

YM="$(date +%Y%m)"
[[ -n "${OUT}" ]] || OUT="${HOME}/.claude/logs/toolchain-health-${YM}.md"

_keep_tagged() {
  { grep -rl '^keep: on-demand$' "${CC_ROOT}/skills" "${CC_ROOT}/commands" 2>/dev/null || true; } \
    | sed -e "s|${CC_ROOT}/skills/||" -e "s|${CC_ROOT}/commands/||" -e 's|/SKILL.md$||' -e 's|\.md$||' \
    | sort -u
}

_count() { find "${CC_ROOT}/$1" -type f \( -name '*.md' -o -name '*.sh' \) 2>/dev/null | wc -l | tr -d ' '; }

total=0
counts=""
for cat in skills commands agents rules hooks guidelines references scripts; do
  n="$(_count "${cat}")"
  counts="${counts}| ${cat} | ${n} |"$'\n'
  total=$((total + n))
done

keep_list="$(_keep_tagged)"

unused_skills="$("${SCRIPT_DIR}/skill-eval.sh" --days "${DAYS}" --unused 2>/dev/null | sed -n 's/^  - //p' || true)"
zero_commands="$({ "${SCRIPT_DIR}/usage-stats.sh" --days "${DAYS}" --zero 2>/dev/null || true; } \
  | awk '/^=== Commands ===/{f=1; next} /^=== /{f=0} f && /^  [a-z0-9-]+$/{sub(/^  /,""); print}')"

# 新設から DAYS 日未満の資産は「利用ゼロ」計測が成立しないため候補から外す
_added_within_days() {
  local path="$1" added now
  added="$(git -C "${REPO_ROOT}" log --diff-filter=A --follow --format=%at -- "${path}" 2>/dev/null | tail -1)"
  [[ -n "${added}" ]] || return 0
  now="$(date +%s)"
  (( now - added < DAYS * 86400 ))
}

_filter_keep() {
  local kind="$1" name path
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    grep -qx "${name}" <<< "${keep_list}" && continue
    if [[ "${kind}" == "skills" ]]; then
      path="claude-code/skills/${name}/SKILL.md"
    else
      path="claude-code/commands/${name}.md"
    fi
    _added_within_days "${path}" && continue
    printf -- '- %s\n' "${name}"
  done
}
hit_skills="$(_filter_keep skills <<< "${unused_skills}")"
hit_commands="$(_filter_keep commands <<< "${zero_commands}")"

TRIAGE_LOG="${REPO_ROOT}/memory/sleep-triage-log.md"
adopt=0; triaged=0
if [[ -s "${TRIAGE_LOG}" ]]; then
  triaged=$(grep -cE '\| *(adopt|hold|reject) *\|' "${TRIAGE_LOG}" || true)
  adopt=$(grep -cE '\| *adopt *\|' "${TRIAGE_LOG}" || true)
fi

first_ctx_median="$({ "${SCRIPT_DIR}/first-ctx-check.sh" --days 7 2>/dev/null || true; } \
  | awk '/^[0-9]+\t/ {v[n++]=$1} END {if (n>0) print v[int(n/2)]; else print "n/a"}')"

{
  printf '# Toolchain health report %s\n\n' "${YM}"
  printf 'この report 自体の生存条件: 3 か月連続で閲覧されなければ生成を止める (toolchain-lifecycle.md checklist 10)。\n\n'
  printf '## 資産数 (cap 判定用)\n\n| category | files |\n|---|---|\n%s| **total** | **%s** |\n\n' "${counts}" "${total}"
  printf '## 生存条件に抵触する資産 (過去 %s 日利用ゼロ、keep: on-demand 除外後)\n\n' "${DAYS}"
  printf '### skills\n\n%s\n\n### commands\n\n%s\n\n' "${hit_skills:-- なし}" "${hit_commands:-- なし}"
  if [[ -n "${keep_list}" ]]; then
    printf '## keep: on-demand 除外一覧 (濫用監視)\n\n%s\n\n' "$(sed 's/^/- /' <<< "${keep_list}")"
  else
    printf '## keep: on-demand 除外一覧 (濫用監視)\n\n- なし\n\n'
  fi
  printf '## sleep pipeline\n\n- triage 済 %s 件 / adopt %s 件\n\n' "${triaged}" "${adopt}"
  printf '## first-ctx 床値 (直近 7 日 median)\n\n- %s tokens\n\n' "${first_ctx_median}"
  printf 'archive の実行判断は人間が行う。手順: references/on-demand-rules/toolchain-lifecycle.md\n'
} > "${OUT}"

echo "report: ${OUT}"
