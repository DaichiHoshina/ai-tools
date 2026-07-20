#!/usr/bin/env bash
# Phase 1: global commands / skills の利用状況集計
# 対象: ~/.claude/projects/*/*.jsonl (過去 N 日)
# 出力: TSV (count, name)、0 利用は別途リスト
#
# Usage:
#   ./scripts/usage-stats.sh             # 過去 30 日、stdout
#   ./scripts/usage-stats.sh --days 60   # 期間指定
#   ./scripts/usage-stats.sh --zero      # 0 利用のみ
set -euo pipefail

DAYS=30
ZERO_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --zero) ZERO_ONLY=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_DIR="$REPO_ROOT/commands"
SKILL_DIR="$REPO_ROOT/skills"
LOG_ROOT="$HOME/.claude/projects"

[[ -d "$CMD_DIR" && -d "$SKILL_DIR" && -d "$LOG_ROOT" ]] || {
  echo "ERROR: required dirs missing" >&2; exit 1
}

LOGS=$(find "$LOG_ROOT" -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null)
LOG_COUNT=$(echo "$LOGS" | grep -c . || true)

tmp_cmd_used=$(mktemp); tmp_skill_used=$(mktemp)
trap 'rm -f "$tmp_cmd_used" "$tmp_skill_used"' EXIT

# skills: Skill tool_use の .input.skill
skill_names="$({ echo "$LOGS" | xargs jq -r '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="tool_use" and .name=="Skill")
    | .input.skill // empty' 2>/dev/null || true; })"
{ printf '%s\n' "$skill_names" | grep -v '^$' || true; } | sort | uniq -c | sort -rn > "$tmp_skill_used"

# commands: tag 抽出だけだと AI の Skill tool 発火分が 0 利用に誤判定されるので両方を合算する
{ { echo "$LOGS" | xargs grep -hoE '<command-name>/[a-zA-Z][a-zA-Z0-9_:-]*' 2>/dev/null || true; } \
    | sed 's|<command-name>/||'
  printf '%s\n' "$skill_names" | grep -v '^$' || true
} | sort | uniq -c | sort -rn > "$tmp_cmd_used"

# 定義済 commands/skills 一覧 (basename without .md, top-level only)
defined_cmds=$(find "$CMD_DIR" -maxdepth 1 -name "*.md" -exec basename {} .md \; | sort)
defined_skills=$(find "$SKILL_DIR" -maxdepth 2 \( -iname "SKILL.md" -o -iname "skill.md" \) | awk -F/ '{print $(NF-1)}' | sort -u)
# fallback: skills/ 直下に .md 単体配置の場合
[[ -z "$defined_skills" ]] && defined_skills=$(find "$SKILL_DIR" -maxdepth 1 -name "*.md" -exec basename {} .md \; | sort)

print_section() {
  local title="$1" defined="$2" used_file="$3"
  echo "=== $title ==="
  echo "定義済: $(echo "$defined" | wc -l | tr -d ' ')件"
  echo ""
  if [[ "$ZERO_ONLY" -eq 1 ]]; then
    echo "[0 利用 (過去 ${DAYS} 日)]"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if ! awk -v n="$name" '$2==n {found=1} END {exit !found}' "$used_file"; then
        echo "  $name"
      fi
    done <<< "$defined"
  else
    echo "[利用回数 desc]"
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      cnt=$(awk -v n="$name" '$2==n {print $1; exit}' "$used_file")
      printf "  %4s  %s\n" "${cnt:-0}" "$name"
    done <<< "$defined" | sort -k1 -rn
  fi
  echo ""
}

echo "# Claude Code usage stats (過去 ${DAYS} 日, jsonl=${LOG_COUNT})"
echo ""
print_section "Commands" "$defined_cmds" "$tmp_cmd_used"
print_section "Skills" "$defined_skills" "$tmp_skill_used"
