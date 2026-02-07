#!/opt/homebrew/bin/bash
# UserPromptSubmit Hook - スキル推奨精度70%→90%強化版
# プロンプト + ファイルパス + エラーログから技術スタックを階層的に検出
#
# リファクタリング: 298行 → 80行（検出関数を lib/ に分離）
# - lib/detect-from-files.sh: ファイルパス検出
# - lib/detect-from-keywords.sh: キーワード検出
# - lib/detect-from-errors.sh: エラーログ検出
# - lib/detect-from-git.sh: Git状態検出
#
# テクニック自動選択:
#   タスク特性(purpose/complexity/difficulty/volume)に応じた
#   最適テクニック選択については guidelines/common/technique-selection.md を参照
#   - 圏論、形式手法、DDD、プロパティベーステストなど10種類
#   - Progressive Disclosure統合(Level 1/2/3)

set -euo pipefail

# セキュリティ共通ライブラリ読み込み（Critical #6対策）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# source のエラーハンドリング改善
if [ -f "${LIB_DIR}/security-functions.sh" ]; then
    # shellcheck source=../lib/security-functions.sh
    source "${LIB_DIR}/security-functions.sh"
else
    echo '{"error": "security-functions.sh not found"}' >&2
    exit 1
fi

# 検出関数ライブラリを読み込み
for detect_lib in detect-from-files detect-from-keywords detect-from-errors detect-from-git; do
  if [ -f "${LIB_DIR}/${detect_lib}.sh" ]; then
    # shellcheck source=../lib/detect-from-files.sh
    # shellcheck source=../lib/detect-from-keywords.sh
    # shellcheck source=../lib/detect-from-errors.sh
    # shellcheck source=../lib/detect-from-git.sh
    source "${LIB_DIR}/${detect_lib}.sh"
  else
    echo "{\"error\": \"${detect_lib}.sh not found\"}" >&2
    exit 1
  fi
done

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む（DoS攻撃防止: 1MB制限）
input=$(cat)

# サイズチェック（1MB = 1048576バイト）
if [ ${#input} -ge 1048576 ]; then
    echo '{"error": "Input size exceeds limit (1MB)"}' >&2
    exit 1
fi

# JSON形式検証
if ! validate_json "$input"; then
    exit 1
fi

# プロンプトを取得（小文字変換で1回のみ処理）
prompt=$(echo "$input" | jq -r '.prompt // empty')
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# 検出結果格納
declare -A detected_langs
declare -A detected_skills
additional_context=""

# 階層的検出実行（優先度順）
# 1. ファイルパス検出（最優先）
detect_from_files detected_langs detected_skills

# 2. プロンプトキーワード検出
detect_from_keywords "$prompt_lower" detected_langs detected_skills additional_context

# 3. エラーログ検出
detect_from_errors "$prompt" detected_skills additional_context

# 4. Git状態検出
detect_from_git_state detected_skills

# =============================================================================
# 結果の集約と出力
# =============================================================================

system_message=""
context_message=""

# 言語検出結果（重複排除・ソート）
detected_langs_str=""
for lang in "${!detected_langs[@]}"; do
  detected_langs_str="${detected_langs_str}${lang},"
done

if [ -n "$detected_langs_str" ]; then
  detected_langs_str=$(echo "${detected_langs_str%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

  system_message="🔍 Tech stack detected: $detected_langs_str"
  context_message="# Auto-Detected Configuration\n\n"
  context_message="${context_message}**Languages**: $detected_langs_str\n"
  context_message="${context_message}**Recommendation**: Run \`/load-guidelines\` to apply language-specific guidelines\n\n"
fi

# スキル検出結果（重複排除・ソート）
detected_skills_str=""
for skill in "${!detected_skills[@]}"; do
  detected_skills_str="${detected_skills_str}${skill},"
done

if [ -n "$detected_skills_str" ]; then
  detected_skills_str=$(echo "${detected_skills_str%,}" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')

  if [ -n "$system_message" ]; then
    system_message="${system_message} | Skills: $detected_skills_str"
  else
    system_message="💡 Suggested skills: $detected_skills_str"
  fi

  context_message="${context_message}**Suggested Skills**: $detected_skills_str\n"
  context_message="${context_message}Consider using appropriate skills for this task.\n\n"
fi

# 追加コンテキスト
if [ -n "$additional_context" ]; then
  context_message="${context_message}\n${additional_context}"
fi

# JSON出力（検出があった場合のみ）
# jqで安全にJSON生成（特殊文字エスケープ対応）
if [ -n "$system_message" ] && [ -n "$context_message" ]; then
  jq -n \
    --arg sm "$system_message" \
    --arg ac "$context_message" \
    '{systemMessage: $sm, additionalContext: $ac}'
elif [ -n "$system_message" ]; then
  jq -n \
    --arg sm "$system_message" \
    '{systemMessage: $sm}'
elif [ -n "$context_message" ]; then
  jq -n \
    --arg ac "$context_message" \
    '{additionalContext: $ac}'
fi
# 検出なしの場合は何も出力しない（トークン節約）
