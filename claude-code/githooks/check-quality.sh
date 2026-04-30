#!/bin/bash
# 共通品質チェック: skill / agent / command / メタファイルの劣化を検出
# pre-commit と pre-push から呼ばれる。単独実行も可。
#
# セットアップ: git config core.hooksPath claude-code/githooks
# 一時迂回: git commit --no-verify  /  git push --no-verify （恒常使用は避ける）

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failed=0

check_size() {
  local file="$1"
  local limit="$2"
  [ -f "$file" ] || return 0
  local lines
  lines=$(wc -l < "$file" | tr -d ' ')
  if [ "$lines" -gt "$limit" ]; then
    echo "✗ $file: $lines lines (limit $limit)"
    return 1
  fi
  return 0
}

# 1. skill-lint --strict (description 形式・トリガー語句・ディレクトリ名一致)
if [ -x "./claude-code/scripts/skill-lint.sh" ]; then
  if ! ./claude-code/scripts/skill-lint.sh --strict 2>&1; then
    echo "✗ skill-lint failed"
    failed=1
  fi
fi

# 2. メタファイル肥大検出 (リファクタ後の現状値+α を上限)
check_size "claude-code/CLAUDE.md" 200         || failed=1
check_size "claude-code/SKILLS-MAP.md" 150     || failed=1
check_size "claude-code/SKILLS-USAGE.md" 130   || failed=1
check_size "claude-code/COMMANDS-GUIDE.md" 150 || failed=1

# 3. skill body 行数 (CLAUDE.md目安: 100-130、150を超えたら fail)
for f in claude-code/skills/*/SKILL.md; do
  check_size "$f" 150 || failed=1
done

# 4. agent 行数 (CLAUDE.md目安: 300以下)
for f in claude-code/agents/*.md; do
  check_size "$f" 300 || failed=1
done

# 5. command 行数 (CLAUDE.md目安: 150以下)
for f in claude-code/commands/*.md; do
  check_size "$f" 150 || failed=1
done

# 6. review-history.jsonl 同位置5回以上 (Compounding Engineering: hook化推奨閾値)
# warn のみ (failed には影響しない)。既存問題への気付き材料、新規commit強制ブロックしない
HIST=".claude/review-history.jsonl"
if [ -f "$HIST" ] && command -v jq >/dev/null 2>&1; then
  recurring=$(jq -c '.' "$HIST" 2>/dev/null \
    | jq -s 'group_by(.file + ":" + (.line // 0 | tostring) + ":" + .focus)
            | map(select(length >= 5)) | length' 2>/dev/null \
    || echo "0")
  if [ "${recurring:-0}" != "0" ] && [ "${recurring:-0}" != "" ]; then
    echo "⚠ review-history.jsonl: 同位置5回以上の指摘 ${recurring} 件 → hook化推奨"
    jq -c '.' "$HIST" 2>/dev/null \
      | jq -s -r 'group_by(.file + ":" + (.line // 0 | tostring) + ":" + .focus)
                | map(select(length >= 5)) | sort_by(-length)
                | .[] | "  " + .[0].file + ":" + (.[0].line // 0 | tostring) + " [" + .[0].focus + "] (" + (length | tostring) + "回)"' 2>/dev/null
  fi
fi

if [ "$failed" -ne 0 ]; then
  echo ""
  echo "Quality check failed."
  echo "  - 行数を削減するか --no-verify で意図的に迂回"
  exit 1
fi

echo "✓ Quality checks passed"
