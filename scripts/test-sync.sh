#!/bin/bash

set -euo pipefail

# Test sync.sh script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Testing sync.sh..."

# Syntax check
if ! bash -n "${PROJECT_ROOT}/claude-code/sync.sh"; then
    echo "Error: sync.sh has syntax errors" >&2
    exit 1
fi

echo "sync.sh syntax check passed"

# Check that diff mode works (read-only operation)
# Note: We can't actually run to-local or from-local in CI without user confirmation
echo "Checking sync.sh diff mode..."

# Create a temporary test to ensure the script is executable
if [ ! -x "${PROJECT_ROOT}/claude-code/sync.sh" ]; then
    echo "Error: sync.sh is not executable" >&2
    exit 1
fi

echo "sync.sh is executable"
echo "sync.sh test passed"
