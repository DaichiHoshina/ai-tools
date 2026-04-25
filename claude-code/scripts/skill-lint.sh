#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# Skill Linter
# claude-code/skills/*/SKILL.md の frontmatter を検証
#
# Usage:
#   ./skill-lint.sh                # 全スキルを検証
#   ./skill-lint.sh --skill NAME   # 特定スキルのみ
#   ./skill-lint.sh --strict       # warning も exit 1 扱い
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_DIR="$PROJECT_ROOT/claude-code/skills"

LIB_DIR="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/print-functions.sh
source "$LIB_DIR/print-functions.sh"

# description 長さ基準
DESC_MIN=30
DESC_MAX=200

# トリガー語パターン（description に含まれていると発火精度が上がる）
TRIGGER_PATTERN='時|使用|対応|向け|Use this|When|時に'

STRICT=0
TARGET_SKILL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict) STRICT=1; shift ;;
        --skill) TARGET_SKILL="$2"; shift 2 ;;
        -h|--help)
            sed -n '6,12p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        *) print_error "Unknown option: $1"; exit 2 ;;
    esac
done

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 required for YAML parsing"
    exit 2
fi

# =============================================================================
# Frontmatter 抽出 + 簡易パース（PyYAML 非依存）
#
# 対応スコープ:
#   - 最上位の `key: value` （value はスカラ）
#   - `key:` 直後のインデント `- item` 形式リスト
#   - `key:` 直後のインデント `subkey: ...` 形式マッピング（型のみ判定）
# 用途上、これで SKILL.md frontmatter は十分カバー。
# stdin: SKILL.md content / stdout: JSON
# =============================================================================
parse_frontmatter() {
    local file="$1"
    python3 - "$file" <<'PY'
import sys, json, re

with open(sys.argv[1], encoding="utf-8") as f:
    content = f.read()
if not content.startswith("---"):
    print(json.dumps({"_error": "no frontmatter"}))
    sys.exit(0)

parts = content.split("---", 2)
if len(parts) < 3:
    print(json.dumps({"_error": "unterminated frontmatter"}))
    sys.exit(0)

body = parts[1]
lines = body.splitlines()

def strip_quotes(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ("'", '"'):
        return s[1:-1]
    return s

def strip_comment(s):
    # value 後の `# ...` コメント除去（クォート内は無視）
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

data = {}
i = 0
key_re = re.compile(r'^([A-Za-z0-9_-]+)\s*:\s*(.*)$')

while i < len(lines):
    raw = lines[i]
    if not raw.strip() or raw.lstrip().startswith("#"):
        i += 1
        continue
    if raw[0] in (" ", "\t"):
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
    # 続く子要素を見る
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
            item = strip_comment(stripped[2:])
            items.append(strip_quotes(item))
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

print(json.dumps(data, ensure_ascii=False))
PY
}

# =============================================================================
# 単一スキル検証
# arg1: skill ディレクトリ / 戻り値: 0=ok, 1=warn, 2=error
# =============================================================================
lint_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name="$(basename "$skill_dir")"
    local skill_md="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
        print_error "[$skill_name] SKILL.md not found"
        return 2
    fi

    local fm_json
    fm_json="$(parse_frontmatter "$skill_md")"

    local fm_error
    fm_error="$(echo "$fm_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("_error",""))')"
    if [[ -n "$fm_error" ]]; then
        print_error "[$skill_name] frontmatter: $fm_error"
        return 2
    fi

    local errors=0
    local warnings=0

    # name フィールド
    local name
    name="$(echo "$fm_json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("name",""))')"
    if [[ -z "$name" ]]; then
        print_error "[$skill_name] missing 'name' field"
        errors=$((errors + 1))
    elif [[ "$name" != "$skill_name" ]]; then
        print_error "[$skill_name] name '$name' does not match dir name"
        errors=$((errors + 1))
    fi

    # description フィールド
    local desc
    desc="$(echo "$fm_json" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("description",""))')"
    if [[ -z "$desc" ]]; then
        print_error "[$skill_name] missing 'description' field"
        errors=$((errors + 1))
    else
        local desc_len
        desc_len="$(printf '%s' "$desc" | python3 -c 'import sys; print(len(sys.stdin.read()))')"
        if (( desc_len < DESC_MIN )); then
            print_warning "[$skill_name] description too short ($desc_len chars, min=$DESC_MIN)"
            warnings=$((warnings + 1))
        elif (( desc_len > DESC_MAX )); then
            print_warning "[$skill_name] description too long ($desc_len chars, max=$DESC_MAX)"
            warnings=$((warnings + 1))
        fi
        if ! echo "$desc" | grep -qE "$TRIGGER_PATTERN"; then
            print_warning "[$skill_name] description lacks trigger phrase (e.g. '〜時に使用', '〜対応')"
            warnings=$((warnings + 1))
        fi
    fi

    # requires-guidelines が配列形式か
    local rg_type
    rg_type="$(echo "$fm_json" | python3 -c '
import sys,json
d = json.load(sys.stdin)
if "requires-guidelines" not in d:
    print("absent")
elif isinstance(d["requires-guidelines"], list):
    print("list")
else:
    print(type(d["requires-guidelines"]).__name__)
')"
    if [[ "$rg_type" != "absent" && "$rg_type" != "list" ]]; then
        print_error "[$skill_name] requires-guidelines must be a list (got $rg_type)"
        errors=$((errors + 1))
    fi

    if (( errors > 0 )); then
        return 2
    elif (( warnings > 0 )); then
        return 1
    fi
    print_success "[$skill_name] ok"
    return 0
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
        set +e
        lint_skill "$d"
        local rc=$?
        set -e
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
