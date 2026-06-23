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

# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"

# === 前提条件チェック ===
require_jq

# === 入力処理 ===
input=$(cat)

# 入力サイズ制限（1MB）
if [ ${#input} -ge ${_TH_LOG_MAX_BYTES} ]; then
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

# jsonl を 1 pass で走査し msg_count / token 合計 / 末尾 user timestamp の epoch を集計する
# 引数: jsonl_path
# 出力: TSV 1 行 "msg_count\ttoken_total\tlast_user_epoch" (集計失敗時は "0\t0\t0")
# python3 採用理由: jsonl 大ファイルで jq より高速 (23ms vs 100ms+)。
# grep -c / python token 集計 / tail+grep+sed timestamp 抽出 の 3 走査を 1 走査に集約。
# timestamp は python 内で epoch 変換 (BSD 専用 date -j fork を排除しクロスプラットフォーム化)。
_scan_jsonl_session() {
  local jsonl_path="$1"
  local _out=""
  if command -v python3 &>/dev/null; then
    _out=$(python3 -c "
import json, sys
from datetime import datetime, timezone
count = 0
total = 0
last_user_epoch = 0
try:
    for line in open(sys.argv[1], 'r', errors='replace'):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        t = obj.get('type')
        if t in ('user', 'assistant'):
            count += 1
        if t == 'assistant':
            usage = obj.get('message', {}).get('usage', {})
            total += usage.get('input_tokens', 0) or 0
            total += usage.get('cache_creation_input_tokens', 0) or 0
            total += usage.get('cache_read_input_tokens', 0) or 0
            total += usage.get('output_tokens', 0) or 0
        elif t == 'user':
            ts = obj.get('timestamp')
            if ts:
                try:
                    s = ts.split('.')[0].rstrip('Z')
                    dt = datetime.strptime(s, '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
                    last_user_epoch = int(dt.timestamp())
                except Exception:
                    pass
except Exception:
    pass
print(f'{count}\t{total}\t{last_user_epoch}')
" "${jsonl_path}" 2>/dev/null) || _out=""
  fi
  # 形式検証 (3 列 TSV / 全列整数) に失敗したら 0 で fallback
  if [[ ! "${_out}" =~ ^[0-9]+$'\t'[0-9]+$'\t'[0-9]+$ ]]; then
    _out=$'0\t0\t0'
  fi
  # 末尾改行付与: read (set -e 下) が EOF で rc=1 を返してスクリプトを落とさないため
  printf '%s\n' "${_out}"
}

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

  # throttle: warn 用 (15min) と urgent 用 (5min) を別 flag で管理
  # urgent 判定後は warn flag を共有して二重通知防止
  local _BLOAT_FLAG="/tmp/claude_session_bloat_${session_id}_${date_today}"
  local _BLOAT_URGENT_FLAG="/tmp/claude_session_bloat_urgent_${session_id}_${date_today}"
  # EPOCHSECONDS は subshell/env 引き継ぎ依存で空になるケースがある
  # printf -v は bash 4.2+ builtin (fork ゼロ)
  local _NOW
  printf -v _NOW '%(%s)T' -1

  # jsonl path 構築 (msg count / token 集計で引き続き使用)
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  if [[ ! -f "${_JSONL}" ]]; then
    return 0
  fi

  # session start epoch (共通関数で解決)
  local _START_EPOCH
  _START_EPOCH=$(_resolve_session_jsonl_epoch "$session_id" "$cwd") || return 0
  local _ELAPSED=$(( _NOW - _START_EPOCH ))

  # jsonl 走査: msg_count / token 合計 / 末尾 user epoch を 1 pass で取得 (TSV)
  # mtime+size 署名でキャッシュ (jsonl は append-only。署名一致なら python 再走査 skip)
  local _MSG_COUNT _TOKEN_TOTAL _LAST_EPOCH
  local _SIG _SCAN_CACHE
  # GNU (stat -c) を先に試す: GNU の stat -f は filesystem mode となり garbage を返すため順序重要
  _SIG=$(stat -c '%Y-%s' "${_JSONL}" 2>/dev/null || stat -f '%m-%z' "${_JSONL}" 2>/dev/null || echo "0-0")
  _SCAN_CACHE="/tmp/claude-session-scan-${session_id}-${_SIG}"
  if [[ -f "${_SCAN_CACHE}" ]]; then
    IFS=$'\t' read -r _MSG_COUNT _TOKEN_TOTAL _LAST_EPOCH < "${_SCAN_CACHE}" 2>/dev/null \
      || { _MSG_COUNT=0; _TOKEN_TOTAL=0; _LAST_EPOCH=0; }
  else
    IFS=$'\t' read -r _MSG_COUNT _TOKEN_TOTAL _LAST_EPOCH < <(_scan_jsonl_session "${_JSONL}")
    printf '%s\t%s\t%s\n' "${_MSG_COUNT}" "${_TOKEN_TOTAL}" "${_LAST_EPOCH}" > "${_SCAN_CACHE}" 2>/dev/null || true
    # 同 session の stale cache (旧署名) を掃除
    local _f
    for _f in /tmp/claude-session-scan-${session_id}-*; do
      [[ "${_f}" == "${_SCAN_CACHE}" ]] || rm -f "${_f}" 2>/dev/null || true
    done
  fi
  : "${_MSG_COUNT:=0}" "${_TOKEN_TOTAL:=0}" "${_LAST_EPOCH:=0}"

  # idle 検知: 末尾 user message epoch と現在時刻の差分 (epoch は python 内で変換済み)
  local _IDLE_S=0
  if (( _LAST_EPOCH > 0 )); then
    _IDLE_S=$(( _NOW - _LAST_EPOCH ))
  fi

  # urgent / warn 判定 (urgent が優先)
  local _LEVEL=""
  local _WARN_REASON=""
  if (( _ELAPSED > _TH_SESSION_AGE_URGENT_S )) || (( _TOKEN_TOTAL >= _TH_TOKEN_URGENT )) || (( _MSG_COUNT > _TH_SESSION_MSG_URGENT )); then
    _LEVEL="urgent"
  elif (( _ELAPSED > _TH_SESSION_AGE_S )) \
    || (( _MSG_COUNT > _TH_SESSION_MSG )) \
    || (( _TOKEN_TOTAL >= _TH_TOKEN )) \
    || (( _IDLE_S >= _TH_IDLE_S )); then
    _LEVEL="warn"
  fi

  if [[ -z "${_LEVEL}" ]]; then
    return 0
  fi

  # throttle: level ごとに flag 別管理
  local _FLAG_FILE _THROTTLE_S
  if [[ "${_LEVEL}" == "urgent" ]]; then
    _FLAG_FILE="${_BLOAT_URGENT_FLAG}"
    _THROTTLE_S="${_TH_BLOAT_THROTTLE_URGENT_S}"
  else
    _FLAG_FILE="${_BLOAT_FLAG}"
    _THROTTLE_S="${_TH_BLOAT_THROTTLE_S}"
  fi
  if [[ -f "${_FLAG_FILE}" ]]; then
    local _LAST_NOTIFIED
    read -r _LAST_NOTIFIED < "${_FLAG_FILE}" 2>/dev/null || _LAST_NOTIFIED="0"
    local _SINCE=$(( _NOW - ${_LAST_NOTIFIED:-0} ))
    if (( _SINCE >= 0 && _SINCE < _THROTTLE_S )); then
      return 0
    fi
  fi

  # reason 文字列構築
  if (( _ELAPSED > _TH_SESSION_AGE_S )); then
    local _HOURS=$(( _ELAPSED / 3600 ))
    _WARN_REASON="elapsed=${_HOURS}h"
  fi
  if (( _MSG_COUNT > _TH_SESSION_MSG )); then
    _WARN_REASON="${_WARN_REASON:+${_WARN_REASON} }msg=${_MSG_COUNT}"
  fi
  if (( _TOKEN_TOTAL >= _TH_TOKEN )); then
    # 5M 以上は M 単位で表示
    if (( _TOKEN_TOTAL >= 1000000 )); then
      local _TOKEN_M=$(( _TOKEN_TOTAL / 1000000 ))
      _WARN_REASON="${_WARN_REASON:+${_WARN_REASON} }token=${_TOKEN_M}M"
    else
      local _TOKEN_K=$(( _TOKEN_TOTAL / 1000 ))
      _WARN_REASON="${_WARN_REASON:+${_WARN_REASON} }token=${_TOKEN_K}K"
    fi
  fi
  if (( _IDLE_S >= _TH_IDLE_S )); then
    local _IDLE_MIN=$(( _IDLE_S / 60 ))
    _WARN_REASON="${_WARN_REASON:+${_WARN_REASON} }idle=${_IDLE_MIN}min"
  fi

  # throttle flag 更新 (末尾 \n 必須: read が EOF exit 1 で || fallback しないよう)
  printf '%s\n' "${_NOW}" > "${_FLAG_FILE}" 2>/dev/null || true

  local _MSG
  if [[ "${_LEVEL}" == "urgent" ]]; then
    _MSG="🚨 [session-bloat:URGENT] ${_WARN_REASON}、現タスク完了次第 /clear 必須 (cache_read 累積中)。"
  else
    _MSG="⚠️ [session-bloat] ${_WARN_REASON}、task 境界で /clear 推奨。"
  fi
  printf '%s' "${_MSG}" > /dev/stderr 2>/dev/null || true
  eval "${result_var}=\${_MSG}"
}

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
_fail_detect() {
  local session_id="$1"
  local date_today="$2"
  local prompt_lc="$3"
  local result_var="$4"

  [[ -n "${session_id}" && "${session_id}" != "unknown" ]] || return 0

  # 失敗 keyword を含むか判定 (bash regex, prompt_lower 前提)
  # 現在進行形の失敗のみマッチ (技術相談の "error handling" / "エラーハンドリング" 等を誤検出しない)
  local _fail_kw_re='(エラーになった|エラーが出た|エラーになる|errorになる|errorになった|失敗した|動かない|通らない|うまくいかない)'
  [[ "${prompt_lc}" =~ ${_fail_kw_re} ]] || return 0

  local _FAIL_FILE="/tmp/claude-fail-prompt-${session_id}-${date_today}"
  local _FAIL_FLAG="/tmp/claude-fail-repeat-notified-${session_id}-${date_today}"

  # throttle: 当日 1 回通知済みならスキップ
  if [[ -f "${_FAIL_FLAG}" ]]; then
    # 前回記録は残しておく (次回 turn も継続検出できるように上書き)
    printf '%s\n' "${prompt_lc:0:200}" > "${_FAIL_FILE}" 2>/dev/null || true
    return 0
  fi

  if [[ -f "${_FAIL_FILE}" ]]; then
    # 前回も失敗 keyword あり → 2 回連続失敗 → 通知
    eval "${result_var}='[連続失敗検出] 同一問題で 2 回連続して失敗しています。/clear で context を捨て、prompt を書き直してください。'"
    # throttle flag 立て
    printf '1\n' > "${_FAIL_FLAG}" 2>/dev/null || true
    # 観測 log: 1 週間の発火頻度と誤検出パターンを記録
    printf '[%s] fail-repeat fired | sid=%s | prompt=%.100s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${session_id}" "${prompt_lc}" >> "$HOME/.claude/logs/fail-repeat-detect.log" 2>/dev/null || true
  fi

  # 今回の失敗 prompt を記録 (200 字以内で保存)
  printf '%s\n' "${prompt_lc:0:200}" > "${_FAIL_FILE}" 2>/dev/null || true
}

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

# === delegation trigger → developer-agent §0 checklist + scope allowlist inject ===
# 委譲意図 keyword 検出時に parent 向け checklist を additionalContext として注入する。
# 目的: scope creep / 直列 chain / verify 省略 / Gate 素通り の構造的予防。
# throttle: session 内 5min に 1 回 (flag: /tmp/claude-deleg-checklist-<sid>-<date>)。
_inject_delegation_checklist_if_trigger() {
  local prompt="$1"
  local session_id="$2"
  local date_today="$3"
  local prompt_lower="${prompt,,}"

  # 委譲意図 keyword (実装 / 修正 / 編集 / refactor / dev 委譲 / Task(developer 等)
  # 質問形 (どう / 教えて / なぜ) は skip、調査 / explore は別 agent 経路
  local question_re='(どう思う|どう考え|教えて|なぜ|どうやって|どうすれ|意見|相談)'
  [[ "${prompt_lower}" =~ ${question_re} ]] && return 1

  local trigger_re='(実装|修正|編集|リファクタ|refactor|impl|fix bug|developer-agent|task\(developer|/dev |/flow|並列で|並列に|分担で|分担して)'
  [[ "${prompt_lower}" =~ ${trigger_re} ]] || return 1

  # throttle: 5min 以内に 1 回 inject 済ならスキップ
  [[ -n "${session_id}" && "${session_id}" != "unknown" ]] || return 1
  local _FLAG="/tmp/claude-deleg-checklist-${session_id}-${date_today}"
  if [[ -f "${_FLAG}" ]]; then
    local _LAST_TS _NOW _SINCE
    read -r _LAST_TS < "${_FLAG}" 2>/dev/null || _LAST_TS=0
    printf -v _NOW '%(%s)T' -1
    _SINCE=$(( _NOW - ${_LAST_TS:-0} ))
    if (( _SINCE >= 0 && _SINCE < 300 )); then
      return 1
    fi
  fi

  # flag 更新
  printf -v _NOW '%(%s)T' -1
  printf '%s\n' "${_NOW}" > "${_FLAG}" 2>/dev/null || true

  printf '%s\n' "[delegation-checklist] developer-agent 委譲意図検出。発火前に §0 checklist 6 項目を満たすこと: (1) target file:line 特定済 (2) verify cmd bash literal 確定 (3) DoD 1 行化 (4) 単 domain (5) touchable_files: YAML block を delegation prompt §1 に literal 記載 (6) blocker-on-stop 方針記載。touchable_files 欠落で発火 = subagent 側 partial 停止。Return 時は §0.5 B fact-check (数値 formula 確認 / 測定値 1 sample 再現 / file 変更 git diff --stat) を最低 1 つ実行。source: references/developer-agent-delegation-prompt.md §0, §0.5, §1"
  return 0
}

# === commit/push trigger → NG top-6 term inject ===
# commit message 生成前に block top-6 term を注入して retry loop を事前回避する
# 派生値禁止 rule 準拠: top-6 は log から動的抽出 (literal 埋め込み禁止)
_inject_commit_ng_top6_if_trigger() {
  local prompt="$1"
  local prompt_lower="${prompt,,}"
  local triggers=("push" "pushして" "commit" "/git-push" "/commit" "pr 作" "pr を作" "プルリク")
  local hit=0
  local t
  for t in "${triggers[@]}"; do
    if [[ "${prompt_lower}" == *"${t,,}"* ]]; then hit=1; break; fi
  done
  (( hit )) || return 1

  local _LOG="${HOME}/.claude/logs/jp-quality-block.log"
  [[ -f "${_LOG}" ]] || return 1

  # ISO8601 timestamp は辞書順 = 時系列順。bash 側で cutoff 文字列を 1 回生成し、
  # awk 内で文字列比較するだけにして date fork を完全に排除する。
  local _NOW _CUTOFF_STR
  printf -v _NOW '%(%s)T' -1
  printf -v _CUTOFF_STR '%(%Y-%m-%dT%H:%M:%S)T' "$(( _NOW - 604800 ))"

  local _TOP
  _TOP=$(awk -F'|' -v cutoff="${_CUTOFF_STR}" '
    $4 ~ /block/ {
      if (substr($1,1,19) >= cutoff) {
        term = $3
        gsub(/^ +| +$/, "", term)
        if (term != "") count[term]++
      }
    }
    END {
      for (k in count) print count[k], k
    }' "${_LOG}" 2>/dev/null | sort -rn | head -6 | awk '{$1=""; sub(/^ /,""); print}' | paste -sd "," -)

  [[ -n "${_TOP}" ]] || return 1
  printf '%s\n' "[commit-ng-pre-sweep] commit/push trigger 検出。直近7日 block top-6: ${_TOP}。commit message 生成前に必ず回避。代替: 鑑みる→踏まえる / 踏襲→引き継ぐ / 喫緊→直近 / leverage→使う / utilize→活かす / mitigate→緩和する。source: ~/.claude/logs/jp-quality-block.log"
  return 0
}

# === 外向き文書 trigger 判定 (外向き文書品質 + 断定語注意 の発火条件) ===
# 永続化文書を書く意図を広めに検出。hit 時のみ [外向き文書品質] / [断定語注意] を注入し、
# 毎-turn 固定費を削る。trigger 漏れ時も pre-tool-use.sh の hook block が最終防壁。
_is_outward_writing_trigger() {
  local prompt="$1"
  local prompt_lower="${prompt,,}"
  # 文書種別 + 動作動詞。大小文字非依存 (lower 比較)。
  # 裸の "pr" は improve/express/approach/compress/spring 等の英単語に部分一致で誤爆するため
  # 配列に入れず、語境界判定 (後述) で別扱いする。
  local triggers=("プルリク" "commit" "コミット" "push" "issue" "slack" "notion" \
    "design doc" "デザインドック" "設計書" "prd" "rca" "障害報告" "ポストモーテム" "postmortem" \
    "/git-push" "/commit" "/post-comment" "/design-doc" "/prd" "/docs" \
    "共有用" "報告用" "共有して" "報告して" "共有文" "報告文" "報告書" \
    "ドラフト" "下書き")
  local t
  for t in "${triggers[@]}"; do
    if [[ "${prompt_lower}" == *"${t,,}"* ]]; then return 0; fi
  done
  # "pr" は語境界 (前後が非英数字 or 行頭行末) のときのみ hit
  if [[ "${prompt_lower}" =~ (^|[^a-z0-9])pr([^a-z0-9]|$) ]]; then return 0; fi
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
    # PRINCIPLES.md から 5 key を 1-pass bash read で抽出 (旧: grep ×5 fork = -22ms)
    _AI_TERMS_LINE=""
    _KATAKANA_LINE=""
    _JARGON_LINE=""
    _ABBREV_LINE=""
    _SOFTBLOCK_LINE=""
    while IFS= read -r _pl; do
      case "$_pl" in
        '**AI定型語**:'*)               [[ -z "$_AI_TERMS_LINE" ]] && _AI_TERMS_LINE="$_pl" ;;
        '**カタカナ造語禁止**:'*)       [[ -z "$_KATAKANA_LINE" ]] && _KATAKANA_LINE="$_pl" ;;
        '**内部jargon初出和訳必須**:'*) [[ -z "$_JARGON_LINE" ]] && _JARGON_LINE="$_pl" ;;
        '**略語初出展開必須**:'*)       [[ -z "$_ABBREV_LINE" ]] && _ABBREV_LINE="$_pl" ;;
        '**断定語 (warn-only)**:'*)     [[ -z "$_SOFTBLOCK_LINE" ]] && _SOFTBLOCK_LINE="$_pl" ;;
      esac
    done < "${_PRINCIPLES_PATH}"

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

    # 外向き文書品質 + 断定語注意: 永続化文書を書く trigger 時のみ注入 (毎-turn 固定費削減)。
    # chat genshijin (上記) は trigger 無関係に毎-turn 維持。
    if _is_outward_writing_trigger "$prompt"; then
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
    # _SOFTBLOCK_LINE は冒頭 1-pass read で取得済 (旧: grep ×5 を 1-pass 化)
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

    # token 増分 monitor: 1500 byte 超のみ log ファイルに記録 (stderr は Claude に届かないため log に切替)
    _INJECT_SIZE=${#_AI_TERMS_CTX}
    if [[ "${_INJECT_SIZE}" -gt 1500 ]]; then
      _LOG_DIR="${HOME}/.claude/logs"
      _SIZE_LOG="${_LOG_DIR}/jp-quality-inject-size.log"
      mkdir -p "${_LOG_DIR}" 2>/dev/null || true
      if [[ -f "${_SIZE_LOG}" ]]; then
        _fsize=$(stat -c%s "${_SIZE_LOG}" 2>/dev/null || stat -f%z "${_SIZE_LOG}" 2>/dev/null || echo 0)
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
