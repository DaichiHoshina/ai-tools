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

# === session_id / cwd / 日付早期取得: _CTX_FILE / _SERENA_COUNTER / _DUP_FILE の default path に suffix 付与 ===
# env CLAUDE_CODE_SESSION_ID 優先、無ければ stdin JSON から抽出、それも無ければ unknown
# session_id + cwd を jq 1 回で取得 (fork 削減、eval 禁止のため @tsv + read で代替)
IFS=$'\t' read -r _SESSION_ID _INIT_CWD < <(jq -r '[.session_id // "unknown", .cwd // ""] | @tsv' <<< "$input")
_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${_SESSION_ID}}"
# 日付を事前取得してキャッシュ（date fork を hook 起動 1 回に抑える）
_DATE_TODAY=$(date +%Y%m%d)

# === Session bloat check: 3h超 or msg 1000超で /clear 推奨通知 ===
# throttle: 同 session 内 15min に1回のみ通知 (/tmp/claude_session_bloat_<id>_<date>)
_check_session_bloat() {
  local session_id="$1"
  local cwd="$2"
  local date_today="$3"
  local result_var="$4"

  # session_id 不明の場合はスキップ
  if [[ -z "${session_id}" || "${session_id}" == "unknown" ]]; then
    return 0
  fi

  # throttle check: 15分 (900秒) 以内なら skip
  local _BLOAT_FLAG="/tmp/claude_session_bloat_${session_id}_${date_today}"
  # EPOCHSECONDS は subshell/env 引き継ぎ依存で空になるケースがある
  # printf -v は bash 4.2+ builtin (fork ゼロ)
  local _NOW
  printf -v _NOW '%(%s)T' -1
  if [[ -f "${_BLOAT_FLAG}" ]]; then
    local _LAST_NOTIFIED
    read -r _LAST_NOTIFIED < "${_BLOAT_FLAG}" 2>/dev/null || _LAST_NOTIFIED="0"
    local _SINCE=$(( _NOW - ${_LAST_NOTIFIED:-0} ))
    if (( _SINCE >= 0 && _SINCE < 900 )); then
      return 0
    fi
  fi

  # session jsonl path 構築
  # cwd: /Users/daichi/... → slug: -Users-daichi-...  (/ → -、. → -)
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  if [[ ! -f "${_JSONL}" ]]; then
    return 0
  fi

  # session start timestamp (先頭20行から最初のtimestampフィールドを抽出)
  local _TS_RAW
  _TS_RAW=$(head -20 "${_JSONL}" 2>/dev/null | grep -m1 '"timestamp":"' | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4) || true
  if [[ -z "${_TS_RAW}" ]]; then
    return 0
  fi
  # ISO8601 → epoch (macOS date -j -f)
  # 形式: 2026-05-23T03:59:12.225Z → strip milliseconds + Z
  local _TS_TRIM="${_TS_RAW%%.*}"  # .225Z を除去
  _TS_TRIM="${_TS_TRIM%Z}"         # 末尾Z除去 (fractional がない場合)
  local _START_EPOCH
  _START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${_TS_TRIM}" "+%s" 2>/dev/null) || return 0
  local _ELAPSED=$(( _NOW - _START_EPOCH ))

  # msg count: user + assistant type 行数
  local _MSG_COUNT
  _MSG_COUNT=$(grep -c '"type":"user"\|"type":"assistant"' "${_JSONL}" 2>/dev/null) || _MSG_COUNT=0

  # 閾値判定
  local _WARN_REASON=""
  if (( _ELAPSED > 10800 )); then
    local _HOURS=$(( _ELAPSED / 3600 ))
    _WARN_REASON="elapsed=${_HOURS}h"
  fi
  if (( _MSG_COUNT > 1000 )); then
    if [[ -n "${_WARN_REASON}" ]]; then
      _WARN_REASON="${_WARN_REASON} msg=${_MSG_COUNT}"
    else
      _WARN_REASON="msg=${_MSG_COUNT}"
    fi
  fi

  if [[ -n "${_WARN_REASON}" ]]; then
    # throttle flag 更新 (末尾 \n 必須: read が EOF exit 1 で || fallback しないよう)
    printf '%s\n' "${_NOW}" > "${_BLOAT_FLAG}" 2>/dev/null || true
    printf '%s' "[session-bloat] ${_WARN_REASON}、/clear で session split 推奨" > /dev/stderr 2>/dev/null || true
    # result_var に warn メッセージをセット (nameref 相当: eval で代入)
    eval "${result_var}='⚠️ [session-bloat] ${_WARN_REASON}、/clear で session split 推奨 (token 節約のため task 境界でリセット)。'"
  fi
}

_BLOAT_NOTICE_MSG=""
_check_session_bloat "${_SESSION_ID}" "${_INIT_CWD}" "${_DATE_TODAY}" "_BLOAT_NOTICE_MSG"

# === Context usage notice: コンテキスト50%超で /compact 提案を通知 ===
_CTX_FILE="${CLAUDE_CTX_FILE:-/tmp/claude-ctx-pct-${_SESSION_ID}}"
_COMPACT_NOTICE_MSG=""
if [[ -f "${_CTX_FILE}" ]]; then
  # bash builtin read で fork 不要にする（毎プロンプトで cat fork していた箇所）
  read -r _CTX_PCT < "${_CTX_FILE}" 2>/dev/null || _CTX_PCT="0"
  if [[ "${_CTX_PCT}" =~ ^[0-9]+$ ]] && [[ "${_CTX_PCT}" -ge 50 ]]; then
    _COMPACT_NOTICE_MSG="⚠️ コンテキスト使用率${_CTX_PCT}%。次レスポンス冒頭で /compact 実行をユーザーに提案すること（自動実行禁止、承認後に実行）。"
  fi
fi

# === Serena MCP health notice: 失敗が累積したら /serena-refresh 提案 ===
_SERENA_COUNTER="${CLAUDE_SERENA_FAIL_COUNT:-/tmp/claude-serena-fail-count-${_SESSION_ID}}"
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
  _DUP_SESSION_ID="${_SESSION_ID}"
  if [[ -n "${_DUP_SESSION_ID}" && "${_DUP_SESSION_ID}" != "unknown" ]]; then
    _DUP_FILE="/tmp/claude-last-prompt-${_DUP_SESSION_ID}-${_DATE_TODAY}"
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

# 通知を合成 (bloat / compact / serena / duplicate を順序固定で結合)
_COMBINED_NOTICE=""
for _msg in "${_BLOAT_NOTICE_MSG}" "${_COMPACT_NOTICE_MSG}" "${_SERENA_NOTICE_MSG}" "${_DUP_NOTICE_MSG}"; do
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

# === 共有/報告系 trigger → outward-mode inject ===
# user 入力に共有/報告系 phrase が含まれる場合、chat 応答にも外向き規範を適用するよう inject
_inject_outward_mode_if_trigger() {
  local prompt="$1"
  local triggers=("共有用" "報告用" "共有して" "報告して" "共有文" "報告文" "共有テキスト" "報告書" "共有する文" "報告する内容")
  local t
  for t in "${triggers[@]}"; do
    if [[ "$prompt" == *"$t"* ]]; then
      printf '%s\n' "[jp-quality-outward-mode] user 入力に共有/報告系 phrase 検出。chat 応答も外向き文書扱いとし、AI 定型語 / カタカナ造語 / 難読漢語 / 非日常英語の 4 block list を自己検査して回避すること。source: guidelines/writing/PRINCIPLES.md"
      return 0
    fi
  done
  return 1
}

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

    # 共有/報告系 trigger 検出 → outward-mode inject
    _OUTWARD_MODE_CTX=""
    if _OUTWARD_MODE_CTX=$(_inject_outward_mode_if_trigger "$prompt" 2>/dev/null); then
      if [[ -n "${_AI_TERMS_CTX}" ]]; then
        _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_OUTWARD_MODE_CTX}"
      else
        _AI_TERMS_CTX="${_OUTWARD_MODE_CTX}"
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
      printf '%s | %d bytes | session=%s\n' "${_ts}" "${_INJECT_SIZE}" "${_SESSION_ID:-unknown}" >> "${_SIZE_LOG}" 2>/dev/null || true
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
  # _AI_TERMS_CTX (outward-mode inject 含む) があれば additionalContext として出力
  _early_ctx=""
  for _prepend_msg in "${_COMPACT_NOTICE_MSG}" "${_AI_TERMS_CTX}"; do
    if [[ -n "${_prepend_msg}" ]]; then
      if [[ -n "${_early_ctx}" ]]; then
        _early_ctx="${_prepend_msg}
${_early_ctx}"
      else
        _early_ctx="${_prepend_msg}"
      fi
    fi
  done
  if [[ -n "${_early_ctx}" ]]; then
    jq -n --arg ctx "${_early_ctx}" '{"additionalContext": $ctx}'
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
