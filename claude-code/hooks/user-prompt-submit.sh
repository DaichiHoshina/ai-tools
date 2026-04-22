#!/usr/bin/env bash
# =============================================================================
# UserPromptSubmit Hook - スキル推奨（オーケストレーター版）
# 検出ロジックは lib/detect-from-keywords.sh, detect-technique.sh に委譲
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
load_lib "detect-from-keywords.sh" || exit 1
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

# === Context usage notice: コンテキスト50%超で /compact 提案を通知 ===
_CTX_FILE="/tmp/claude-ctx-pct"
_COMPACT_NOTICE_MSG=""
if [[ -f "${_CTX_FILE}" ]]; then
  _CTX_PCT=$(cat "${_CTX_FILE}" 2>/dev/null || echo "0")
  if [[ "${_CTX_PCT}" =~ ^[0-9]+$ ]] && [[ "${_CTX_PCT}" -ge 50 ]]; then
    _COMPACT_NOTICE_MSG="⚠️ コンテキスト使用率${_CTX_PCT}%。次レスポンス冒頭で /compact 実行をユーザーに提案すること（自動実行禁止、承認後に実行）。"
  fi
fi

# === Serena MCP health notice: 失敗が累積したら /serena-refresh 提案 ===
_SERENA_COUNTER="/tmp/claude-serena-fail-count"
_SERENA_NOTICE_MSG=""
if [[ -f "${_SERENA_COUNTER}" ]]; then
  _SERENA_FAILS=$(cat "${_SERENA_COUNTER}" 2>/dev/null || echo "0")
  if [[ "${_SERENA_FAILS}" =~ ^[0-9]+$ ]] && [[ "${_SERENA_FAILS}" -ge 2 ]]; then
    _SERENA_NOTICE_MSG="⚠️ Serena MCP が${_SERENA_FAILS}回失敗。ユーザーに \`/serena-refresh\` 実行を提案してください（再接続で復旧）。"
    rm -f "${_SERENA_COUNTER}"  # 1度通知したらクリア
  fi
fi

# 通知を合成
_COMBINED_NOTICE=""
if [[ -n "${_COMPACT_NOTICE_MSG}" && -n "${_SERENA_NOTICE_MSG}" ]]; then
  _COMBINED_NOTICE="${_COMPACT_NOTICE_MSG}
${_SERENA_NOTICE_MSG}"
elif [[ -n "${_COMPACT_NOTICE_MSG}" ]]; then
  _COMBINED_NOTICE="${_COMPACT_NOTICE_MSG}"
elif [[ -n "${_SERENA_NOTICE_MSG}" ]]; then
  _COMBINED_NOTICE="${_SERENA_NOTICE_MSG}"
fi
_COMPACT_NOTICE_MSG="${_COMBINED_NOTICE}"

# promptフィールド取得（<<< で fork 削減）
prompt=$(jq -r '.prompt // empty' <<< "$input")
if [ -z "$prompt" ]; then
  # promptが空の場合でも compact 提案メッセージがあれば返す
  if [[ -n "${_COMPACT_NOTICE_MSG}" ]]; then
    jq -n --arg msg "${_COMPACT_NOTICE_MSG}" '{"systemMessage": $msg}'
  else
    echo '{}'
  fi
  exit 0
fi

# 長いプロンプトは検出処理を先頭2000文字に制限（線形スキャンのコスト削減）
# bash 5.0+ の ${var:0:N} は LC_CTYPE が UTF-8 ならマルチバイト文字数基準で切り出す。
# C/POSIX ロケール時はバイト基準になるため、iconv で不正バイト列を除去して下流に渡す。
if (( ${#prompt} > 2000 )); then
  prompt_lower="${prompt:0:2000}"
  # UTF-8 境界で不完全なバイト列が混入した場合に備えてサニタイズ（iconv 不在時はスキップ）
  if command -v iconv &>/dev/null; then
    prompt_lower=$(printf '%s' "$prompt_lower" | iconv -f utf-8 -t utf-8 -c 2>/dev/null || printf '%s' "$prompt_lower")
  fi
  prompt_lower="${prompt_lower,,}"
else
  prompt_lower="${prompt,,}"  # bash組み込みで小文字化（tr fork削減）
fi

# === スラッシュコマンドは検出スキップ（analytics追跡のみ） ===
if [[ "$prompt" == /* ]]; then
    # bash parameter expansion で /コマンド名 を抽出（sed fork削減）
    _CMD_NAME="${prompt#/}"
    _CMD_NAME="${_CMD_NAME%% *}"
    _CMD_NAME="${_CMD_NAME%%[^a-zA-Z_-]*}"
    if [[ -n "${_CMD_NAME}" && -f "${LIB_DIR}/analytics-writer.sh" ]]; then
        source "${LIB_DIR}/analytics-writer.sh"
        # jq 1回で session_id と cwd を取得
        eval "$(jq -r '@sh "_CMD_SESSION_ID=\(.session_id // "unknown") _CMD_CWD=\(.cwd // ".")"' <<< "$input")"
        _CMD_PROJECT=$(basename "$_CMD_CWD")
        analytics_insert_tool_event "${_CMD_SESSION_ID}" "${_CMD_PROJECT}" "SlashCommand" "${_CMD_NAME}" 2>/dev/null || true
    fi
    # スラッシュコマンドはスキル/言語検出不要 → 早期リターン
    if [[ -n "${_COMPACT_NOTICE_MSG}" ]]; then
        jq -n --arg msg "${_COMPACT_NOTICE_MSG}" '{"systemMessage": $msg}'
    else
        echo '{}'
    fi
    exit 0
fi

# === 検出結果格納 ===
declare -A detected_langs
declare -A detected_skills
additional_context=""

# === 検出実行 (lib関数呼び出し) ===

# キーワード検出
detect_from_keywords "$prompt_lower" detected_langs detected_skills additional_context

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

# 検出されたスキル・言語・テクニックがない場合
if [ "$lang_count" -eq 0 ] && [ "$skill_count" -eq 0 ] && [ -z "$technique_recommendation" ]; then
  if [[ -n "${_COMPACT_NOTICE_MSG}" ]]; then
    jq -n --arg msg "${_COMPACT_NOTICE_MSG}" '{"systemMessage": $msg}'
  else
    echo '{}'
  fi
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

# JSON出力: compact通知と既存additional_contextを結合してjq 1回にまとめる
final_ctx="$additional_context"
if [[ -n "${_COMPACT_NOTICE_MSG}" ]]; then
  if [[ -n "$final_ctx" ]]; then
    final_ctx="${_COMPACT_NOTICE_MSG}
${final_ctx}"
  else
    final_ctx="${_COMPACT_NOTICE_MSG}"
  fi
fi

if [ -n "$system_message" ] && [ -n "$final_ctx" ]; then
  jq -n --arg msg "$system_message" --arg ctx "$final_ctx" '{systemMessage: $msg, additionalContext: $ctx}'
elif [ -n "$system_message" ]; then
  jq -n --arg msg "$system_message" '{systemMessage: $msg}'
elif [ -n "$final_ctx" ]; then
  jq -n --arg ctx "$final_ctx" '{additionalContext: $ctx}'
else
  echo "{}"
fi
