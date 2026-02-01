#!/bin/bash

set -euo pipefail

# Test install.sh script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Testing install.sh..."

# Syntax check
if ! bash -n "${PROJECT_ROOT}/claude-code/install.sh"; then
    echo "Error: install.sh has syntax errors" >&2
    exit 1
fi

echo "install.sh syntax check passed"

# Check required files exist
REQUIRED_FILES=(
    "claude-code/CLAUDE.md"
    "claude-code/install.sh"
    "claude-code/sync.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${PROJECT_ROOT}/${file}" ]; then
        echo "Error: Required file not found: ${file}" >&2
        exit 1
    fi
done

echo "All required files exist"
echo "install.sh test passed"
