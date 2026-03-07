#!/usr/bin/env bash
# InstructionsLoaded Hook - CLAUDE.md等の読み込み完了時に発火
# v2.1.69で追加されたhookイベント

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# jq前提条件チェック
require_jq

# JSON入力を消費
cat > /dev/null

# 読み込まれた指示の確認ログ（非同期hookのため軽量に）
echo '{}'
