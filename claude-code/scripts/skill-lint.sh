#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Skill Linter
# claude-code/skills/*/skill.md (or SKILL.md) の frontmatter を検証
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$PROJECT_ROOT/claude-code/skills"

LIB_DIR="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/print-functions.sh
source "$LIB_DIR/print-functions.sh"

DESC_MIN=30
DESC_MAX=200
TRIGGER_PATTERN='時|使用|対応|向け|Use this|When|時に'

STRICT=0
TARGET_SKILL=""

print_usage() {
    cat <<'EOF'
Usage: skill-lint.sh [--skill NAME] [--strict] [--help]

Validates SKILL.md frontmatter under claude-code/skills/.

Options:
  --skill NAME   Lint only the named skill
  --strict       Treat warnings as failures (exit 1)
  --help, -h     Show this help

Checks:
  - name field present and matches directory name
  - description present, 30-200 chars, contains a trigger phrase
  - requires-guidelines is a list (when present)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) STRICT=1; shift ;;
        --skill)
            [[ $# -ge 2 ]] || { print_error "--skill requires an argument"; exit 2; }
            TARGET_SKILL="$2"
            shift 2
            ;;
        -h|--help) print_usage; exit 0 ;;
        *) print_error "Unknown option: $1"; print_usage >&2; exit 2 ;;
    esac
done

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 required for frontmatter parsing"
    exit 2
fi

# =============================================================================
# 単一スキル検証（python3 一発で全検査）
#
# args: skill_dir skill_name
# stdout: status\tmessage\nstatus\tmessage\n... (status=ok|warn|error)
# exit code: 0=ok, 1=warn, 2=error
# =============================================================================
lint_skill() {
    local skill_dir="$1"
    local skill_name="$2"
    local skill_md=""

    if [[ -f "$skill_dir/skill.md" ]]; then
        skill_md="$skill_dir/skill.md"
    elif [[ -f "$skill_dir/SKILL.md" ]]; then
        skill_md="$skill_dir/SKILL.md"
    fi

    if [[ -z "$skill_md" ]]; then
        print_error "[$skill_name] skill.md not found"
        return 2
    fi

    SKILL_FILE="$skill_md" \
    SKILL_NAME="$skill_name" \
    DESC_MIN="$DESC_MIN" \
    DESC_MAX="$DESC_MAX" \
    TRIGGER_PATTERN="$TRIGGER_PATTERN" \
    python3 - <<'PY'
import os, sys, re

skill_file = os.environ["SKILL_FILE"]
skill_name = os.environ["SKILL_NAME"]
desc_min = int(os.environ["DESC_MIN"])
desc_max = int(os.environ["DESC_MAX"])
trigger_pattern = os.environ["TRIGGER_PATTERN"]

with open(skill_file, encoding="utf-8") as f:
    content = f.read()

errors, warnings = [], []

if not content.startswith("---"):
    print(f"error\t[{skill_name}] frontmatter: missing leading ---")
    sys.exit(2)

parts = content.split("---", 2)
if len(parts) < 3:
    print(f"error\t[{skill_name}] frontmatter: unterminated")
    sys.exit(2)

# 簡易 frontmatter パーサ（PyYAML 非依存）
# 対応: top-level `key: value`, `key:` 配下のインデント `- item` リスト/`subkey:` マッピング
def strip_quotes(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        return s[1:-1]
    return s

def strip_comment(s):
    in_q = None
    for i, c in enumerate(s):
        if in_q:
            if c == in_q:
                in_q = None
        elif c in ("'", '"'):
            in_q = c
        elif c == "#":
            return s[:i].rstrip()
    return s.rstrip()

key_re = re.compile(r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$')
data = {}
lines = parts[1].splitlines()
i = 0
while i < len(lines):
    raw = lines[i]
    if not raw.strip() or raw.lstrip().startswith("#") or raw[0] in (" ", "\t"):
        i += 1
        continue
    m = key_re.match(raw)
    if not m:
        i += 1
        continue
    key = m.group(1)
    rest = strip_comment(m.group(2))
    if rest:
        data[key] = strip_quotes(rest)
        i += 1
        continue
    j = i + 1
    items = []
    is_list = None
    while j < len(lines):
        nxt = lines[j]
        if not nxt.strip() or nxt.lstrip().startswith("#"):
            j += 1
            continue
        if not (nxt.startswith(" ") or nxt.startswith("\t")):
            break
        stripped = nxt.lstrip()
        if stripped.startswith("- "):
            if is_list is False:
                break
            is_list = True
            items.append(strip_quotes(strip_comment(stripped[2:])))
        else:
            if is_list is True:
                break
            is_list = False
        j += 1
    if is_list:
        data[key] = items
    elif is_list is False:
        data[key] = {"_type": "mapping"}
    else:
        data[key] = ""
    i = j

# 検査
name = data.get("name", "")
if not name:
    errors.append("missing 'name' field")
elif name != skill_name:
    errors.append(f"name '{name}' does not match dir name")

desc = data.get("description", "")
if not desc or not isinstance(desc, str):
    errors.append("missing 'description' field")
else:
    desc_len = len(desc)
    if desc_len < desc_min:
        warnings.append(f"description too short ({desc_len} chars, min={desc_min})")
    elif desc_len > desc_max:
        warnings.append(f"description too long ({desc_len} chars, max={desc_max})")
    if not re.search(trigger_pattern, desc):
        warnings.append("description lacks trigger phrase (e.g. '〜時に使用', '〜対応')")

if "requires-guidelines" in data:
    rg = data["requires-guidelines"]
    if not isinstance(rg, list):
        kind = "mapping" if isinstance(rg, dict) else type(rg).__name__
        errors.append(f"requires-guidelines must be a list (got {kind})")

# 出力（status\tmessage 形式）
for e in errors:
    print(f"error\t[{skill_name}] {e}")
for w in warnings:
    print(f"warn\t[{skill_name}] {w}")
if not errors and not warnings:
    print(f"ok\t[{skill_name}] ok")

if errors:
    sys.exit(2)
elif warnings:
    sys.exit(1)
sys.exit(0)
PY
}

# =============================================================================
# Main
# =============================================================================
main() {
    print_header "Skill Linter"
    print_info "Skills dir: $SKILLS_DIR"

    local total=0 ok=0 warn=0 err=0
    local targets=()

    if [[ -n "$TARGET_SKILL" ]]; then
        if [[ ! -d "$SKILLS_DIR/$TARGET_SKILL" ]]; then
            print_error "Skill not found: $TARGET_SKILL"
            exit 2
        fi
        targets+=("$SKILLS_DIR/$TARGET_SKILL")
    else
        while IFS= read -r -d '' d; do
            targets+=("$d")
        done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print0 | sort -z)
    fi

    for d in "${targets[@]}"; do
        total=$((total + 1))
        local name
        name="$(basename "$d")"

        set +e
        local out
        out="$(lint_skill "$d" "$name")"
        local rc=$?
        set -e

        # 出力をステータス別に色分け表示
        while IFS=$'\t' read -r status msg; do
            [[ -z "$status" ]] && continue
            case "$status" in
                ok) print_success "$msg" ;;
                warn) print_warning "$msg" ;;
                error) print_error "$msg" ;;
            esac
        done <<< "$out"

        case $rc in
            0) ok=$((ok + 1)) ;;
            1) warn=$((warn + 1)) ;;
            *) err=$((err + 1)) ;;
        esac
    done

    echo ""
    print_info "Total: $total / OK: $ok / Warn: $warn / Error: $err"

    if (( err > 0 )); then
        return 1
    fi
    if (( STRICT == 1 && warn > 0 )); then
        print_warning "Strict mode: treating warnings as failures"
        return 1
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
