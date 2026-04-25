#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Skill Eval (発火率計測)
# ~/.claude/projects/*/*.jsonl から Skill ツールの発火回数を集計し、
# claude-code/skills/ に対する死蔵スキル候補を可視化する。
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$PROJECT_ROOT/claude-code/skills"
TRANSCRIPTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

LIB_DIR="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/print-functions.sh
source "$LIB_DIR/print-functions.sh"

DAYS=30
ALL_TIME=0
ONLY_UNUSED=0
TOP_N=20
TARGET_SKILL=""

print_usage() {
    cat <<'EOF'
Usage: skill-eval.sh [--days N] [--all] [--skill NAME] [--unused] [--top N] [--help]

Aggregates Skill tool invocations from ~/.claude/projects/*/*.jsonl.

Options:
  --days N      直近 N 日のみ集計（デフォルト: 30）
  --all         全期間集計（--days を無視）
  --skill NAME  特定スキルの発火回数のみ表示
  --unused      この期間で発火 0 のスキルだけ表示
  --top N       上位 N 件のみ表示（デフォルト: 20）
  --help, -h    このヘルプを表示

Sources:
  CLAUDE_PROJECTS_DIR (env, default: ~/.claude/projects)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            [[ $# -ge 2 ]] || { print_error "--days requires an argument"; exit 2; }
            DAYS="$2"; shift 2 ;;
        --all) ALL_TIME=1; shift ;;
        --unused) ONLY_UNUSED=1; shift ;;
        --top)
            [[ $# -ge 2 ]] || { print_error "--top requires an argument"; exit 2; }
            TOP_N="$2"; shift 2 ;;
        --skill)
            [[ $# -ge 2 ]] || { print_error "--skill requires an argument"; exit 2; }
            TARGET_SKILL="$2"; shift 2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) print_error "Unknown option: $1"; print_usage >&2; exit 2 ;;
    esac
done

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 required"
    exit 2
fi

if [[ ! -d "$TRANSCRIPTS_DIR" ]]; then
    print_error "Transcripts dir not found: $TRANSCRIPTS_DIR"
    exit 2
fi

print_header "Skill Eval"
print_info "Transcripts: $TRANSCRIPTS_DIR"
print_info "Skills dir:  $SKILLS_DIR"
if (( ALL_TIME == 1 )); then
    print_info "Window:      all time"
else
    print_info "Window:      last $DAYS days"
fi

# ローカルスキル名一覧（小文字）
mapfile -t LOCAL_SKILLS < <(
    find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 \
        | xargs -0 -n1 basename \
        | sort
)
print_info "Local skills: ${#LOCAL_SKILLS[@]}"

# python3 に集計を委譲（ファイル列挙は bash、解析は python）
LOCAL_SKILLS_CSV="$(IFS=,; echo "${LOCAL_SKILLS[*]}")"
TARGET_SKILL="$TARGET_SKILL" \
ONLY_UNUSED="$ONLY_UNUSED" \
TOP_N="$TOP_N" \
DAYS="$DAYS" \
ALL_TIME="$ALL_TIME" \
LOCAL_SKILLS="$LOCAL_SKILLS_CSV" \
TRANSCRIPTS_DIR="$TRANSCRIPTS_DIR" \
python3 - <<'PY'
import os, sys, json, glob, time
from collections import Counter
from datetime import datetime, timezone, timedelta

transcripts_dir = os.environ["TRANSCRIPTS_DIR"]
target_skill = os.environ.get("TARGET_SKILL", "")
only_unused = os.environ.get("ONLY_UNUSED") == "1"
top_n = int(os.environ.get("TOP_N", "20"))
days = int(os.environ.get("DAYS", "30"))
all_time = os.environ.get("ALL_TIME") == "1"
local_skills = [s for s in os.environ.get("LOCAL_SKILLS", "").split(",") if s]

cutoff = None
if not all_time:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

counter = Counter()
nonlocal_counter = Counter()
files_scanned = 0
lines_scanned = 0
hits = 0

# プロジェクト跨いで全 jsonl を見る
patterns = [
    os.path.join(transcripts_dir, "*", "*.jsonl"),
    os.path.join(transcripts_dir, "*.jsonl"),
]
files = []
for p in patterns:
    files.extend(glob.glob(p))

for path in files:
    if cutoff is not None:
        try:
            mtime = datetime.fromtimestamp(os.path.getmtime(path), tz=timezone.utc)
            if mtime < cutoff:
                continue
        except OSError:
            continue
    files_scanned += 1
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                lines_scanned += 1
                if '"Skill"' not in line:
                    continue
                try:
                    rec = json.loads(line)
                except (ValueError, json.JSONDecodeError):
                    continue
                msg = rec.get("message")
                if not isinstance(msg, dict):
                    continue
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    if item.get("type") != "tool_use" or item.get("name") != "Skill":
                        continue
                    skill = (item.get("input") or {}).get("skill", "")
                    if not skill:
                        continue
                    hits += 1
                    if local_skills and skill in local_skills:
                        counter[skill] += 1
                    else:
                        nonlocal_counter[skill] += 1
    except OSError:
        continue

# 出力
print()
print(f"Scanned: {files_scanned} files / {lines_scanned} lines / {hits} Skill invocations")
print()

if target_skill:
    n = counter.get(target_skill, 0) + nonlocal_counter.get(target_skill, 0)
    print(f"[{target_skill}] {n} invocations")
    sys.exit(0)

# 死蔵候補（ローカルスキルのうち発火 0）
unused = [s for s in local_skills if counter.get(s, 0) == 0]
unused.sort()
print(f"Unused local skills ({len(unused)}/{len(local_skills)}):")
for s in unused:
    print(f"  - {s}")
print()

if only_unused:
    sys.exit(0)

print(f"Top {top_n} local skills:")
for skill, n in counter.most_common(top_n):
    print(f"  {n:>5}  {skill}")
print()

if nonlocal_counter:
    print(f"Top {top_n} non-local (community/builtin) skills:")
    for skill, n in nonlocal_counter.most_common(top_n):
        print(f"  {n:>5}  {skill}")
PY
