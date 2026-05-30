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
_CTX_FILE="${CLAUDE_CTX_FILE:-/tmp/claude-ctx-pct}"
_COMPACT_NOTICE_MSG=""
if [[ -f "${_CTX_FILE}" ]]; then
  # bash builtin read で fork 不要にする（毎プロンプトで cat fork していた箇所）
  read -r _CTX_PCT < "${_CTX_FILE}" 2>/dev/null || _CTX_PCT="0"
  if [[ "${_CTX_PCT}" =~ ^[0-9]+$ ]] && [[ "${_CTX_PCT}" -ge 50 ]]; then
    _COMPACT_NOTICE_MSG="⚠️ コンテキスト使用率${_CTX_PCT}%。次レスポンス冒頭で /compact 実行をユーザーに提案すること（自動実行禁止、承認後に実行）。"
  fi
fi

# === Serena MCP health notice: 失敗が累積したら /serena-refresh 提案 ===
_SERENA_COUNTER="${CLAUDE_SERENA_FAIL_COUNT:-/tmp/claude-serena-fail-count}"
_SERENA_NOTICE_MSG=""
if [[ -f "${_SERENA_COUNTER}" ]]; then
  read -r _SERENA_FAILS < "${_SERENA_COUNTER}" 2>/dev/null || _SERENA_FAILS="0"
  if [[ "${_SERENA_FAILS}" =~ ^[0-9]+$ ]] && [[ "${_SERENA_FAILS}" -ge 2 ]]; then
    _SERENA_NOTICE_MSG="⚠️ Serena MCP が${_SERENA_FAILS}回失敗。ユーザーに \`/serena-refresh\` 実行を提案してください（再接続で復旧）。"
    rm -f "${_SERENA_COUNTER}"  # 1度通知したらクリア
  fi
fi

# promptフィールド取得（<<< で fork 削減）
prompt=$(jq -r '.prompt // empty' <<< "$input")

# === Duplicate prompt notice: 5秒以内に同一prompt再送を検出 ===
# 短文 ("yes" / "続き" / "TODO" 等の rate-limit 復旧 prompt) は除外して長文のみ対象
_DUP_NOTICE_MSG=""
if (( ${#prompt} >= 20 )); then
  _DUP_SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$input")
  _DUP_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${_DUP_SESSION_ID}}"
  if [[ -n "${_DUP_SESSION_ID}" && "${_DUP_SESSION_ID}" != "unknown" ]]; then
    _DUP_FILE="/tmp/claude-last-prompt-${_DUP_SESSION_ID}"
    _DUP_NOW="${EPOCHSECONDS}"
    _DUP_HASH=$(printf '%s' "$prompt" | shasum -a 1 2>/dev/null | cut -d' ' -f1)
    if [[ -n "${_DUP_HASH}" && -f "${_DUP_FILE}" ]]; then
      IFS=$'\t' read -r _DUP_LAST_TS _DUP_LAST_HASH < "${_DUP_FILE}" 2>/dev/null || true
      if [[ "${_DUP_LAST_HASH:-}" == "${_DUP_HASH}" ]]; then
        _DUP_ELAPSED=$(( _DUP_NOW - ${_DUP_LAST_TS:-0} ))
        if (( _DUP_ELAPSED >= 0 && _DUP_ELAPSED <= 5 )); then
          _DUP_NOTICE_MSG="⚠️ 直前 prompt と同一入力検出 (${_DUP_ELAPSED}秒前)。応答待ちまたは rate-limit 中の重複送信の可能性、再送前に状態確認を推奨。"
        fi
      fi
    fi
    if [[ -n "${_DUP_HASH}" ]]; then
      printf '%s\t%s' "${_DUP_NOW}" "${_DUP_HASH}" > "${_DUP_FILE}" 2>/dev/null || true
    fi
  fi
fi

# 通知を合成 (compact / serena / duplicate を順序固定で結合)
_COMBINED_NOTICE=""
for _msg in "${_COMPACT_NOTICE_MSG}" "${_SERENA_NOTICE_MSG}" "${_DUP_NOTICE_MSG}"; do
  if [[ -n "${_msg}" ]]; then
    if [[ -n "${_COMBINED_NOTICE}" ]]; then
      _COMBINED_NOTICE="${_COMBINED_NOTICE}
${_msg}"
    else
      _COMBINED_NOTICE="${_msg}"
    fi
  fi
done
_COMPACT_NOTICE_MSG="${_COMBINED_NOTICE}"
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
        _CMD_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${_CMD_SESSION_ID}}"
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

# === JP品質 inject (AI定型語 + カタカナ造語 + jargon + 略語) ===
# PRINCIPLES.md の canonical list を動的抽出して chat 応答 / 外向き文書に注入する
# 派生値禁止 rule 準拠: hook 内に語 list literal を持たない
# JP_QUALITY_INJECT_OFF=1 で全 inject skip (debug 用)
_AI_TERMS_CTX=""
if [[ "${JP_QUALITY_INJECT_OFF:-0}" != "1" ]]; then
  _PRINCIPLES_PATH="${HOME}/.claude/guidelines/writing/PRINCIPLES.md"
  if [[ -f "${_PRINCIPLES_PATH}" ]]; then
    # AI定型語 (chat応答禁止)
    _AI_TERMS_LINE=$(grep -m1 '^\*\*AI定型語\*\*:' "${_PRINCIPLES_PATH}" 2>/dev/null || true)
    # カタカナ造語 (chat応答禁止)
    _KATAKANA_LINE=$(grep -m1 '^\*\*カタカナ造語禁止\*\*:' "${_PRINCIPLES_PATH}" 2>/dev/null || true)
    # 内部jargon (外向き初出和訳必須)
    _JARGON_LINE=$(grep -m1 '^\*\*内部jargon初出和訳必須\*\*:' "${_PRINCIPLES_PATH}" 2>/dev/null || true)
    # 略語 (外向き初出展開必須)
    _ABBREV_LINE=$(grep -m1 '^\*\*略語初出展開必須\*\*:' "${_PRINCIPLES_PATH}" 2>/dev/null || true)

    # chat応答向け: AI定型語のみ全列挙 + カタカナ造語は参照形式 (token 節約)
    _CHAT_PARTS=""
    if [[ -n "${_AI_TERMS_LINE}" ]]; then
      _AI_TERMS=$(printf '%s' "${_AI_TERMS_LINE}" | sed 's/^\*\*AI定型語\*\*: //')
      _CHAT_PARTS="AI定型語: ${_AI_TERMS}"
    fi
    _KATAKANA_HINT=""
    if [[ -n "${_KATAKANA_LINE}" ]]; then
      _KATAKANA_HINT=" / カタカナ造語禁止 (source: PRINCIPLES.md **カタカナ造語禁止**: 行参照)"
    fi
    if [[ -n "${_CHAT_PARTS}" ]]; then
      _AI_TERMS_CTX="[chat応答genshijin強化] 以下をchat応答で使用禁止: ${_CHAT_PARTS}${_KATAKANA_HINT}。代替は説明的記述で対応 (例: シームレス → 中断なく)。"
    elif [[ -n "${_KATAKANA_HINT}" ]]; then
      _AI_TERMS_CTX="[chat応答genshijin強化] カタカナ造語禁止${_KATAKANA_HINT}。代替は説明的記述で対応。"
    fi

    # 外向き文書向け: jargon + 略語
    _DOC_PARTS=""
    if [[ -n "${_JARGON_LINE}" ]]; then
      _JARGON=$(printf '%s' "${_JARGON_LINE}" | sed 's/^\*\*内部jargon初出和訳必須\*\*: //')
      _DOC_PARTS="jargon: ${_JARGON}"
    fi
    if [[ -n "${_ABBREV_LINE}" ]]; then
      _ABBREV=$(printf '%s' "${_ABBREV_LINE}" | sed 's/^\*\*略語初出展開必須\*\*: //')
      if [[ -n "${_DOC_PARTS}" ]]; then
        _DOC_PARTS="${_DOC_PARTS} / 略語: ${_ABBREV}"
      else
        _DOC_PARTS="略語: ${_ABBREV}"
      fi
    fi
    if [[ -n "${_DOC_PARTS}" ]]; then
      _DOC_CTX="[外向き文書品質] 永続化文書 (PR/commit/Issue/Slack/Notion/DD/PRD/RCA) では初出時に和訳/展開必須: ${_DOC_PARTS}"
      if [[ -n "${_AI_TERMS_CTX}" ]]; then
        _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_DOC_CTX}"
      else
        _AI_TERMS_CTX="${_DOC_CTX}"
      fi
    fi

    # 断定語 (warn-only) hint: commit message では正当用法、chat 応答での AI 確定表現に注意喚起のみ
    _SOFTBLOCK_LINE=$(grep -m1 '^\*\*断定語 (warn-only)\*\*:' "${_PRINCIPLES_PATH}" 2>/dev/null || true)
    if [[ -n "${_SOFTBLOCK_LINE}" ]]; then
      _SOFTBLOCK_TERMS=$(printf '%s' "${_SOFTBLOCK_LINE}" | sed 's/^\*\*断定語 (warn-only)\*\*: //')
      _SOFTBLOCK_CTX="[断定語注意 (warn-only)] 以下は外向き prose では慎重に使用 (commit subject では許可): ${_SOFTBLOCK_TERMS}"
      if [[ -n "${_AI_TERMS_CTX}" ]]; then
        _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_SOFTBLOCK_CTX}"
      else
        _AI_TERMS_CTX="${_SOFTBLOCK_CTX}"
      fi
    fi

    # token 増分 monitor: 1500 byte 超のみ log ファイルに記録 (stderr は Claude に届かないため log に切替)
    _INJECT_SIZE=${#_AI_TERMS_CTX}
    if [[ "${_INJECT_SIZE}" -gt 1500 ]]; then
      _LOG_DIR="${HOME}/.claude/logs"
      _SIZE_LOG="${_LOG_DIR}/jp-quality-inject-size.log"
      mkdir -p "${_LOG_DIR}" 2>/dev/null || true
      if [[ -f "${_SIZE_LOG}" ]]; then
        _fsize=$(stat -f%z "${_SIZE_LOG}" 2>/dev/null || stat -c%s "${_SIZE_LOG}" 2>/dev/null || echo 0)
        if [[ "${_fsize}" -gt 1048576 ]]; then
          mv "${_SIZE_LOG}" "${_SIZE_LOG}.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
        fi
      fi
      _ts=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || printf 'unknown')
      printf '%s | %d bytes | pid=%d\n' "${_ts}" "${_INJECT_SIZE}" "$$" >> "${_SIZE_LOG}" 2>/dev/null || true
    fi
  fi
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

# 検出されたスキル・言語・テクニック・additional_context すべて無い場合
if [ "$lang_count" -eq 0 ] && [ "$skill_count" -eq 0 ] && [ -z "$technique_recommendation" ] && [ -z "$additional_context" ]; then
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

# JSON出力: compact通知・AI定型語禁止・既存additional_contextを結合してjq 1回にまとめる
final_ctx="$additional_context"
for _prepend_msg in "${_COMPACT_NOTICE_MSG}" "${_AI_TERMS_CTX}"; do
  if [[ -n "${_prepend_msg}" ]]; then
    if [[ -n "$final_ctx" ]]; then
      final_ctx="${_prepend_msg}
${final_ctx}"
    else
      final_ctx="${_prepend_msg}"
    fi
  fi
done

if [ -n "$system_message" ] && [ -n "$final_ctx" ]; then
  jq -n --arg msg "$system_message" --arg ctx "$final_ctx" '{systemMessage: $msg, additionalContext: $ctx}'
elif [ -n "$system_message" ]; then
  jq -n --arg msg "$system_message" '{systemMessage: $msg}'
elif [ -n "$final_ctx" ]; then
  jq -n --arg ctx "$final_ctx" '{additionalContext: $ctx}'
else
  echo "{}"
fi
