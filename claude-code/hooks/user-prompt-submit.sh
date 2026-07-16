#!/usr/bin/env bash
# =============================================================================
# UserPromptSubmit Hook - スキル推奨（オーケストレーター版）
# 検出ロジックは lib/detect-from-keywords.sh, detect-technique.sh に委譲
# =============================================================================

set -euo pipefail

_ups_src="${BASH_SOURCE[0]}"
[[ "${_ups_src}" == /* ]] || _ups_src="${PWD}/${_ups_src}"
SCRIPT_DIR="${_ups_src%/*}"
LIB_DIR="${SCRIPT_DIR}/../lib"

# === ライブラリ読み込み ===
source "${LIB_DIR}/common.sh" || {
  echo '{"error":"Failed to load common.sh"}' >&2
  exit 1
}

# detect ライブラリを読み込み
load_lib "detect-from-keywords.sh" || exit 1
load_lib "detect-technique.sh" || exit 1

# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"
# shellcheck source=lib/log-rotation.sh
source "${BASH_SOURCE[0]%/*}/lib/log-rotation.sh"
# shellcheck source=lib/portable-stat.sh
source "${BASH_SOURCE[0]%/*}/lib/portable-stat.sh"
# checker/injector modules (責務ごとに hooks/lib/ へ抽出)
# shellcheck source=lib/prompt-session-checks.sh
source "${BASH_SOURCE[0]%/*}/lib/prompt-session-checks.sh"
# shellcheck source=lib/prompt-trigger-detectors.sh
source "${BASH_SOURCE[0]%/*}/lib/prompt-trigger-detectors.sh"

# === 前提条件チェック ===
require_jq

# === 入力処理 ===
input=$(cat)

# 入力サイズ制限（1MB）
if [ ${#input} -ge "${_TH_LOG_MAX_BYTES}" ]; then
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
printf -v _DATE_TODAY '%(%Y%m%d)T' -1

_BLOAT_NOTICE_MSG=""
_check_session_bloat "${_SESSION_ID}" "${_INIT_CWD}" "${_DATE_TODAY}" "_BLOAT_NOTICE_MSG"

# === Context usage notice: コンテキスト40%超で /compact 提案を通知 (CLAUDE.md "Context Management" rule と整合) ===
_CTX_FILE="${CLAUDE_CTX_FILE:-/tmp/claude-ctx-pct-${_SESSION_ID}}"
_COMPACT_NOTICE_MSG=""
if [[ -f "${_CTX_FILE}" ]]; then
  # bash builtin read で fork 不要にする（毎プロンプトで cat fork していた箇所）
  read -r _CTX_PCT < "${_CTX_FILE}" 2>/dev/null || _CTX_PCT="0"
  if [[ "${_CTX_PCT}" =~ ^[0-9]+$ ]] && [[ "${_CTX_PCT}" -ge 40 ]]; then
    _COMPACT_NOTICE_MSG="⚠️ コンテキスト使用率${_CTX_PCT}%。次レスポンス冒頭で /compact 実行をユーザーに提案すること（自動実行禁止、承認後に実行）。"
  fi
fi

# === Serena MCP health notice: 失敗が累積したら再 activate を提案 ===
_SERENA_COUNTER="${CLAUDE_SERENA_FAIL_COUNT:-/tmp/claude-serena-fail-count-${_SESSION_ID}}"
_SERENA_NOTICE_MSG=""
if [[ -f "${_SERENA_COUNTER}" ]]; then
  read -r _SERENA_FAILS < "${_SERENA_COUNTER}" 2>/dev/null || _SERENA_FAILS="0"
  if [[ "${_SERENA_FAILS}" =~ ^[0-9]+$ ]] && [[ "${_SERENA_FAILS}" -ge 2 ]]; then
    _SERENA_NOTICE_MSG="⚠️ Serena MCP が${_SERENA_FAILS}回失敗。mcp__serena__activate_project で project を再 activate して復旧を試みること（改善しなければユーザーに MCP 再接続を依頼）。"
    rm -f "${_SERENA_COUNTER}"  # 1度通知したらクリア
  fi
fi

# promptフィールド取得（<<< で fork 削減）
prompt=$(jq -r '.prompt // empty' <<< "$input")

# === compact 自然語 pre-save inject: AI に save 指示注入 ===
# built-in /compact は user-prompt-submit を bypass して PreCompact 直行のため、
# 自然語 "compact" / "コンパクト" / "save and compact" 等を trigger に AI 介入する。
# Workflow: user が "compact" 打鍵 → AI が save 実行 → user に /compact を促す → user /compact → PreCompact が marker 検知して通常進行。
_COMPACT_PRESAVE_MSG=""
_prompt_lower_compact="${prompt,,}"
if [[ "${_prompt_lower_compact}" =~ (^|[[:space:]])(compact|コンパクト)([[:space:]]|$) ]] \
   || [[ "${_prompt_lower_compact}" == *"save and compact"* ]] \
   || [[ "${_prompt_lower_compact}" == *"save して compact"* ]]; then
  _MEMORY_DIR="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"
  if ! find "${_MEMORY_DIR}" -maxdepth 1 -name 'compact-restore-*.md' -type f -mmin -5 2>/dev/null | grep -q .; then
    printf -v _COMPACT_TS '%(%Y%m%d_%H%M%S)T' -1
    _COMPACT_PATH="${_MEMORY_DIR}/compact-restore-${_COMPACT_TS}.md"
    _COMPACT_PRESAVE_MSG="🔴 compact 自然語検知 + auto-memory save marker 不在。**最優先で即実行**: Write tool で \`${_COMPACT_PATH}\` に現在のタスク・編集中 file・残ステップを 7 field 形式で保存し、保存完了後に user に「memory save 完了。\`/compact\` (slash command) を実行してください」と明示すること。次の /compact で pre-compact.sh が marker を検知して通常進行する。"
  fi
fi

# === Consecutive failure notice: 直近 2 turn で失敗 keyword が連続したら /clear suggest ===
# 失敗 keyword: エラー / error / 失敗 / 動かない / 通らない (prompt_lower で照合)
# throttle: 同 session 同日 1 回のみ (flag file で管理)
# 検出時: systemMessage に /clear + 書き直 を含む通知を付与
_FAIL_REPEAT_MSG=""
_fail_detect "${_SESSION_ID}" "${_DATE_TODAY}" "${prompt,,}" "_FAIL_REPEAT_MSG"

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
# _FAIL_REPEAT_MSG は systemMessage 専用のため ここでは除外
_COMBINED_NOTICE=""
for _msg in "${_COMPACT_PRESAVE_MSG}" "${_BLOAT_NOTICE_MSG}" "${_COMPACT_NOTICE_MSG}" "${_SERENA_NOTICE_MSG}" "${_DUP_NOTICE_MSG}"; do
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
# 入力上限 1MB は L32 で先行 check 済 / Claude Code 正常経路で不正バイト列混入は非現実的のため iconv 経路は撤去 (>2000chars -26ms)
if (( ${#prompt} > 2000 )); then
  prompt_lower="${prompt:0:2000}"
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
  _NG_DICT_PATH="${HOME}/.claude/guidelines/writing/NG-DICTIONARY.md"
  if [[ -f "${_PRINCIPLES_PATH}" ]]; then
    # 5 key を fork なしの bash read で抽出。
    # AI定型語 / カタカナ造語禁止 / 断定語 の key 行は NG-DICTIONARY.md 側にある
    _AI_TERMS_LINE=""
    _KATAKANA_LINE=""
    _JARGON_LINE=""
    _ABBREV_LINE=""
    _SOFTBLOCK_LINE=""
    while IFS= read -r _pl; do
      case "$_pl" in
        '**内部jargon初出和訳必須**:'*) [[ -z "$_JARGON_LINE" ]] && _JARGON_LINE="$_pl" ;;
        '**略語初出展開必須**:'*)       [[ -z "$_ABBREV_LINE" ]] && _ABBREV_LINE="$_pl" ;;
      esac
    done < "${_PRINCIPLES_PATH}"
    if [[ -f "${_NG_DICT_PATH}" ]]; then
      while IFS= read -r _pl; do
        case "$_pl" in
          '**AI定型語**:'*)           [[ -z "$_AI_TERMS_LINE" ]] && _AI_TERMS_LINE="$_pl" ;;
          '**カタカナ造語禁止**:'*)   [[ -z "$_KATAKANA_LINE" ]] && _KATAKANA_LINE="$_pl" ;;
          '**断定語 (warn-only)**:'*) [[ -z "$_SOFTBLOCK_LINE" ]] && _SOFTBLOCK_LINE="$_pl" ;;
        esac
      done < "${_NG_DICT_PATH}"
    fi

    # chat応答向け: AI定型語 + カタカナ造語を参照 1 行に圧縮 (list 展開は NG-DICTIONARY.md canonical へ委譲)
    # 1 session 1 回のみ inject する (毎 prompt 固定費 ~170B × 全 turn 再送を削減、内容は session 内で不変)
    _STYLE_CTX_FLAG="/tmp/claude-style-ctx-${_SESSION_ID:-$$}-${_DATE_TODAY:-0}"
    if [[ ! -f "${_STYLE_CTX_FLAG}" ]] && { [[ -n "${_AI_TERMS_LINE}" ]] || [[ -n "${_KATAKANA_LINE}" ]]; }; then
      _AI_TERMS_CTX="[chat応答文体強化] chat 応答で禁止: AI定型語 / カタカナ造語 / 日本語で言える一般語の英語化 (digest→要約 等) / 体言止め・助詞省略 / 冗長 (結論と根拠だけ書く)。模範: 「実装完了。テスト通過」→「実装した。テストは通過した」/「robust な設計」→「壊れにくい設計」/「まず A を確認し、次に B」→「A を確認してから B を確認する」。canonical: rules/plain-jp.md + guidelines/writing/NG-DICTIONARY.md。"
      touch "${_STYLE_CTX_FLAG}" 2>/dev/null || true
    fi

    # 外向き文書品質: 永続化文書 trigger 時のみ、jargon / 略語 / 断定語を参照 1 行で注入
    if _is_outward_writing_trigger "$prompt"; then
      if [[ -n "${_JARGON_LINE}" ]] || [[ -n "${_ABBREV_LINE}" ]] || [[ -n "${_SOFTBLOCK_LINE}" ]]; then
        _DOC_CTX="[外向き文書品質] 永続化文書 (PR/commit/Issue/Slack/Notion/DD/PRD/RCA): 初出 jargon 和訳 + 略語展開必須、断定語 (warn-only) 慎重使用。canonical: guidelines/writing/PRINCIPLES.md §内部jargon初出和訳必須 / §略語初出展開必須 / §断定語 (warn-only)。"
        if [[ -n "${_AI_TERMS_CTX}" ]]; then
          _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_DOC_CTX}"
        else
          _AI_TERMS_CTX="${_DOC_CTX}"
        fi
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

    # commit/push trigger 検出 → NG top-N term inject
    _COMMIT_NG_CTX=""
    if _COMMIT_NG_CTX=$(_inject_commit_ng_top6_if_trigger "$prompt" 2>/dev/null); then
      if [[ -n "${_AI_TERMS_CTX}" ]]; then
        _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_COMMIT_NG_CTX}"
      else
        _AI_TERMS_CTX="${_COMMIT_NG_CTX}"
      fi
    fi

    # delegation trigger 検出 → developer-agent §0 checklist + scope allowlist inject
    _DELEG_CHECKLIST_CTX=""
    if _DELEG_CHECKLIST_CTX=$(_inject_delegation_checklist_if_trigger "$prompt" "${_SESSION_ID}" "${_DATE_TODAY}" 2>/dev/null); then
      if [[ -n "${_AI_TERMS_CTX}" ]]; then
        _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_DELEG_CHECKLIST_CTX}"
      else
        _AI_TERMS_CTX="${_DELEG_CHECKLIST_CTX}"
      fi
    fi

    # 前 turn の chat 文体 warn 還流: stop.sh が書いた state file を read-and-delete して注入
    # (warn は systemMessage だけだと AI に見えないため、次 turn の additionalContext で矯正する)
    _JPQ_WARN_FILE="/tmp/claude-stop-jpq-warn-${_SESSION_ID:-$$}-${_DATE_TODAY:-0}"
    if [[ -f "${_JPQ_WARN_FILE}" ]]; then
      _JPQ_WARN_PREV=$(cat "${_JPQ_WARN_FILE}" 2>/dev/null || true)
      rm -f "${_JPQ_WARN_FILE}" 2>/dev/null || true
      if [[ -n "${_JPQ_WARN_PREV}" ]]; then
        _JPQ_FEEDBACK_CTX="[前 turn の chat 文体 warn] ${_JPQ_WARN_PREV} — 今回の応答で同じ違反を出さない。"
        if [[ -n "${_AI_TERMS_CTX}" ]]; then
          _AI_TERMS_CTX="${_AI_TERMS_CTX}
${_JPQ_FEEDBACK_CTX}"
        else
          _AI_TERMS_CTX="${_JPQ_FEEDBACK_CTX}"
        fi
      fi
    fi

    # token 増分 monitor: 1500 byte 超のみ log ファイルに記録 (stderr は Claude に届かないため log に切替)
    _INJECT_SIZE=${#_AI_TERMS_CTX}
    if [[ "${_INJECT_SIZE}" -gt 1500 ]]; then
      _LOG_DIR="${HOME}/.claude/logs"
      _SIZE_LOG="${_LOG_DIR}/jp-quality-inject-size.log"
      mkdir -p "${_LOG_DIR}" 2>/dev/null || true
      if [[ -f "${_SIZE_LOG}" ]]; then
        _fsize=$(portable_stat_size "${_SIZE_LOG}")
        if [[ "${_fsize}" -gt ${_TH_LOG_MAX_BYTES} ]]; then
          printf -v _bak_ts '%(%Y%m%d%H%M%S)T' -1
          mv "${_SIZE_LOG}" "${_SIZE_LOG}.${_bak_ts}.bak" 2>/dev/null || true
        fi
      fi
      printf -v _ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
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
  # _FAIL_REPEAT_MSG は systemMessage 専用
  if [[ -n "${_FAIL_REPEAT_MSG}" ]] && [[ -n "${_early_ctx}" ]]; then
    jq -n --arg msg "${_FAIL_REPEAT_MSG}" --arg ctx "${_early_ctx}" '{systemMessage: $msg, additionalContext: $ctx}'
  elif [[ -n "${_FAIL_REPEAT_MSG}" ]]; then
    jq -n --arg msg "${_FAIL_REPEAT_MSG}" '{systemMessage: $msg}'
  elif [[ -n "${_early_ctx}" ]]; then
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

# _FAIL_REPEAT_MSG を system_message に prepend (systemMessage 専用、必ず先頭に置く)
if [[ -n "${_FAIL_REPEAT_MSG}" ]]; then
  if [[ -n "${system_message}" ]]; then
    system_message="${_FAIL_REPEAT_MSG}
${system_message}"
  else
    system_message="${_FAIL_REPEAT_MSG}"
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
