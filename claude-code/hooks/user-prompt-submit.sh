#!/usr/bin/env bash
# =============================================================================
# UserPromptSubmit Hook - スキル推奨（オーケストレーター版）
# 検出ロジックは lib/detect-from-*.sh に委譲
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"

# === ライブラリ読み込み ===
source "${LIB_DIR}/common.sh" || {
  echo '{"error":"Failed to load common.sh"}' >&2
  exit 1
}

# detect ライブラリを読み込み
load_lib "detect-from-files.sh" || exit 1
load_lib "detect-from-keywords.sh" || exit 1
load_lib "detect-from-errors.sh" || exit 1
load_lib "detect-from-git.sh" || exit 1
load_lib "detect-technique.sh" || exit 1

# === 前提条件チェック ===
require_jq

# === 入力処理 ===
input=$(cat)

# 入力サイズ制限（1MB）
if [ ${#input} -ge 1048576 ]; then
  echo '{"error":"Input too large (max 1MB)"}' >&2
  exit 1
fi

# JSON検証
if ! validate_json "$input"; then
  echo '{"error":"Invalid JSON input"}' >&2
  exit 1
fi

# promptフィールド取得
prompt=$(echo "$input" | jq -r '.prompt // empty')
if [ -z "$prompt" ]; then
  # promptが空の場合は何もしない
  echo '{}'
  exit 0
fi

prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# === Analytics: スラッシュコマンド追跡 ===
if [[ "$prompt" == /* ]]; then
    _CMD_NAME=$(echo "$prompt" | sed 's|^/\([a-zA-Z_-]*\).*|\1|')
    if [[ -n "${_CMD_NAME}" ]]; then
        if [[ -f "${LIB_DIR}/analytics-writer.sh" ]]; then
            source "${LIB_DIR}/analytics-writer.sh"
            _CMD_SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
            _CMD_PROJECT=$(basename "$(echo "$input" | jq -r '.cwd // "."')")
            analytics_insert_tool_event "${_CMD_SESSION_ID}" "${_CMD_PROJECT}" "SlashCommand" "${_CMD_NAME}" 2>/dev/null || true
        fi
    fi
fi

# === 検出結果格納 ===
declare -A detected_langs
declare -A detected_skills
additional_context=""

# === 階層的検出実行 (lib関数呼び出し) ===
# 優先度順: ファイルパス > キーワード > エラーログ > Git状態

# 1. ファイルパス検出（最優先）
detect_from_files detected_langs detected_skills

# 2. プロンプトキーワード検出
detect_from_keywords "$prompt_lower" detected_langs detected_skills additional_context

# 3. エラーログ検出
detect_from_errors "$prompt" detected_skills additional_context

# 4. Git状態検出
detect_from_git_state detected_skills

# === テクニック自動選択 ===
technique_recommendation=""
detect_technique_recommendation "$prompt_lower" technique_recommendation

# === 結果集約・JSON出力 ===

# 検出結果カウント（set -u + set -e対応）
# 注: (( x = 0 )) はステータスコード1を返すため set -e でエラーになる
set +u
lang_count=${#detected_langs[@]}
skill_count=${#detected_skills[@]}
set -u

# 検出されたスキル・言語・テクニックがない場合は空オブジェクトを返す
if [ "$lang_count" -eq 0 ] && [ "$skill_count" -eq 0 ] && [ -z "$technique_recommendation" ]; then
  echo '{}'
  exit 0
fi

# systemMessage 生成
system_message=""
if [ "$lang_count" -gt 0 ] || [ "$skill_count" -gt 0 ]; then
  # 言語リスト
  langs_list=""
  for lang in "${!detected_langs[@]}"; do
    if [ -n "$langs_list" ]; then
      langs_list="${langs_list}, ${lang}"
    else
      langs_list="${lang}"
    fi
  done

  # スキルリスト
  skills_list=""
  for skill in "${!detected_skills[@]}"; do
    if [ -n "$skills_list" ]; then
      skills_list="${skills_list}, ${skill}"
    else
      skills_list="${skill}"
    fi
  done

  # メッセージ構築
  if [ -n "$langs_list" ] && [ -n "$skills_list" ]; then
    system_message="🔍 ${langs_list} | ${skills_list}"
  elif [ -n "$langs_list" ]; then
    system_message="🔍 ${langs_list}"
  elif [ -n "$skills_list" ]; then
    system_message="🔍 ${skills_list}"
  fi
fi

# テクニック推奨を追加
if [ -n "$technique_recommendation" ]; then
  if [ -n "$system_message" ]; then
    system_message="${system_message}
🧪 ${technique_recommendation}"
  else
    system_message="🧪 ${technique_recommendation}"
  fi
fi

# JSON出力
output_json="{}"
if [ -n "$system_message" ]; then
  output_json=$(echo "$output_json" | jq --arg msg "$system_message" '.systemMessage = $msg')
fi

if [ -n "$additional_context" ]; then
  # エスケープして追加
  output_json=$(echo "$output_json" | jq --arg ctx "$additional_context" '.additionalContext = $ctx')
fi

echo "$output_json"
