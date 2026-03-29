#!/usr/bin/env bash
set -euo pipefail

# テスト: simplifier.mdに「変更がない場合はスキップ」ルールが含まれること
# TDD REDフェーズ: このテストはルール追加前なので失敗する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_FILE="${SCRIPT_DIR}/../agents/simplifier.md"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "FAIL: simplifier.md が見つかりません: $TARGET_FILE"
  exit 1
fi

# 「変更がない場合はスキップ」に相当する記述があるか検証
# 想定パターン: 「変更がない」「スキップ」の両方を含む行、またはそれに準ずる記述
if grep -qE '変更.*(ない|なし|0件).*スキップ|スキップ.*変更.*(ない|なし|0件)|no.changes.*skip|skip.*no.changes|差分.*(ない|なし|0件).*スキップ|変更なし.*スキップ' "$TARGET_FILE"; then
  echo "PASS: simplifier.mdに「変更がない場合はスキップ」ルールが記述されています"
  exit 0
else
  echo "FAIL: simplifier.mdに「変更がない場合はスキップ」ルールが見つかりません"
  echo "  期待: 変更がない場合にスキップすることを示す記述"
  echo "  対象ファイル: $TARGET_FILE"
  exit 1
fi
