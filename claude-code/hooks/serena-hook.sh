#!/usr/bin/env bash
# Serena reminder hooks wrapper
# Usage: serena-hook.sh <subcmd>
#   subcmd: activate | remind | auto-approve | cleanup
#
# 公式仕様: serena/docs/02-usage/030_clients.md
# SERENA_PATH 未設定時は $HOME/serena を試す（install.sh と同じ慣習）

set -euo pipefail

SUBCMD="${1:-}"
case "$SUBCMD" in
  activate|remind|auto-approve|cleanup) ;;
  *)
    echo "Usage: $(basename "$0") <activate|remind|auto-approve|cleanup>" >&2
    exit 64
    ;;
esac

SERENA_DIR="${SERENA_PATH:-$HOME/serena}"
if [[ ! -d "$SERENA_DIR" ]]; then
  # Serena 未インストールなら静かに pass（hook が落ちて Claude Code 全体を止めない）
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  exit 0
fi

# PYTHONWARNINGS=ignore: Python 3.14 + Pydantic V1 互換警告（毎回 stderr）を抑制
# SERENA_USAGE_REPORTING=false: usage data 送信 OFF（v1.1.2+、PII なしだが network ノイズ削減）
exec env PYTHONWARNINGS=ignore SERENA_USAGE_REPORTING=false uv run --directory "$SERENA_DIR" serena-hooks "$SUBCMD" --client=claude-code
