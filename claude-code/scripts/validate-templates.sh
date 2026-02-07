#!/bin/bash

set -euo pipefail

# =============================================================================
# Templates Validator
# templates/ 配下のテンプレートファイルの構文・必須キーを検証
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES_DIR="$PROJECT_ROOT/claude-code/templates"

# Load print functions
LIB_DIR="$SCRIPT_DIR/../lib"
# shellcheck source=../lib/print-functions.sh
source "$LIB_DIR/print-functions.sh" 2>/dev/null || {
    echo "⚠️  print-functions.sh not found, using basic echo"
    print_info() { echo "[INFO] $*"; }
    print_success() { echo "[✓] $*"; }
    print_error() { echo "[✗] $*" >&2; }
    print_warning() { echo "[!] $*"; }
}

# =============================================================================
# Validation Functions
# =============================================================================

# JSON構文チェック
validate_json() {
    local file="$1"

    if jq empty "$file" 2>/dev/null; then
        print_success "JSON valid: $(basename "$file")"
        return 0
    else
        print_error "JSON invalid: $(basename "$file")"
        return 1
    fi
}

# settings.json.template検証
validate_settings_json() {
    local file="$1"
    local required_keys=(
        ".hooks"
        ".statusline"
        ".mcpServers"
    )

    print_info "Validating settings.json.template..."

    # JSON構文チェック
    if ! validate_json "$file"; then
        return 1
    fi

    # 必須キー存在確認
    local missing=0
    for key in "${required_keys[@]}"; do
        if ! jq -e "$key" "$file" > /dev/null 2>&1; then
            print_error "Missing required key: $key"
            ((missing++))
        fi
    done

    if [ $missing -eq 0 ]; then
        print_success "All required keys present"
        return 0
    else
        print_error "Missing $missing required key(s)"
        return 1
    fi
}

# keybindings.json.template検証
validate_keybindings_json() {
    local file="$1"

    print_info "Validating keybindings.json.template..."

    # JSON構文チェック
    if ! validate_json "$file"; then
        return 1
    fi

    # keybindings配列存在確認
    if ! jq -e '.keybindings | type == "array"' "$file" > /dev/null 2>&1; then
        print_error "Missing or invalid 'keybindings' array"
        return 1
    fi

    # 各keybinding要素の検証
    local count
    count=$(jq '.keybindings | length' "$file")
    print_info "Found $count keybinding(s)"

    for ((i=0; i<count; i++)); do
        local key
        local command
        key=$(jq -r ".keybindings[$i].key" "$file" 2>/dev/null || echo "")
        command=$(jq -r ".keybindings[$i].command" "$file" 2>/dev/null || echo "")

        if [ -z "$key" ] || [ -z "$command" ]; then
            print_error "Keybinding $i: missing 'key' or 'command'"
            return 1
        fi

        print_success "Keybinding $i: $key → $command"
    done

    return 0
}

# シェルスクリプト構文チェック
validate_shell_script() {
    local file="$1"

    print_info "Validating shell script: $(basename "$file")"

    # bash -n で構文チェック
    if bash -n "$file" 2>/dev/null; then
        print_success "Shell script syntax valid"
        return 0
    else
        print_error "Shell script syntax error"
        bash -n "$file" 2>&1 | head -10
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_info "=== Templates Validator ==="
    print_info "Templates Dir: ${TEMPLATES_DIR}"

    local exit_code=0

    # settings.json.template
    if [ -f "$TEMPLATES_DIR/settings.json.template" ]; then
        validate_settings_json "$TEMPLATES_DIR/settings.json.template" || exit_code=1
    else
        print_warning "Not found: settings.json.template"
    fi

    # keybindings.json.template
    if [ -f "$TEMPLATES_DIR/keybindings.json.template" ]; then
        validate_keybindings_json "$TEMPLATES_DIR/keybindings.json.template" || exit_code=1
    else
        print_warning "Not found: keybindings.json.template"
    fi

    # settings-ghq.json.template
    if [ -f "$TEMPLATES_DIR/settings-ghq.json.template" ]; then
        validate_json "$TEMPLATES_DIR/settings-ghq.json.template" || exit_code=1
    else
        print_warning "Not found: settings-ghq.json.template"
    fi

    # gitlab-mcp.sh.template
    if [ -f "$TEMPLATES_DIR/gitlab-mcp.sh.template" ]; then
        validate_shell_script "$TEMPLATES_DIR/gitlab-mcp.sh.template" || exit_code=1
    else
        print_warning "Not found: gitlab-mcp.sh.template"
    fi

    # workflow-config.yaml.template (YAML検証にはyamlまたはpython必要)
    if [ -f "$TEMPLATES_DIR/workflow-config.yaml.template" ]; then
        if command -v python3 > /dev/null 2>&1; then
            if python3 -c "import yaml; yaml.safe_load(open('$TEMPLATES_DIR/workflow-config.yaml.template'))" 2>/dev/null; then
                print_success "YAML valid: workflow-config.yaml.template"
            else
                print_error "YAML invalid: workflow-config.yaml.template"
                exit_code=1
            fi
        else
            print_warning "Python3 not found, skipping YAML validation"
        fi
    else
        print_warning "Not found: workflow-config.yaml.template"
    fi

    echo ""
    if [ $exit_code -eq 0 ]; then
        print_success "=== All Validations Passed ==="
    else
        print_error "=== Validation Failed ==="
    fi

    return $exit_code
}

# =============================================================================
# Execution
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
