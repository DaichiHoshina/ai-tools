#!/usr/bin/env bash
# prompt 検査系 (session bloat / 連続失敗検出) - user-prompt-submit.sh から抽出
# 多重 source 防止
if [[ "${_PROMPT_SESSION_CHECKS_LOADED:-}" == "1" ]]; then
    return 0
fi
_PROMPT_SESSION_CHECKS_LOADED=1

# shellcheck source=thresholds.sh
source "${BASH_SOURCE[0]%/*}/thresholds.sh"
# shellcheck source=portable-stat.sh
source "${BASH_SOURCE[0]%/*}/portable-stat.sh"
# shellcheck source=log-rotation.sh
source "${BASH_SOURCE[0]%/*}/log-rotation.sh"

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
  _SIG=$(portable_stat_mtime_size "${_JSONL}")
  _SCAN_CACHE="/tmp/claude-session-scan-${session_id}-${_SIG}"
  if [[ -f "${_SCAN_CACHE}" ]]; then
    IFS=$'\t' read -r _MSG_COUNT _TOKEN_TOTAL _LAST_EPOCH < "${_SCAN_CACHE}" 2>/dev/null \
      || { _MSG_COUNT=0; _TOKEN_TOTAL=0; _LAST_EPOCH=0; }
  else
    IFS=$'\t' read -r _MSG_COUNT _TOKEN_TOTAL _LAST_EPOCH < <(_scan_jsonl_session "${_JSONL}")
    printf '%s\t%s\t%s\n' "${_MSG_COUNT}" "${_TOKEN_TOTAL}" "${_LAST_EPOCH}" > "${_SCAN_CACHE}" 2>/dev/null || true
    # 同 session の stale cache (旧署名) を掃除
    local _f
    for _f in "/tmp/claude-session-scan-${session_id}"-*; do
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

# === Consecutive failure notice: 直近 2 turn で失敗 keyword が連続したら /clear suggest ===
# 失敗 keyword: エラー / error / 失敗 / 動かない / 通らない (prompt_lower で照合)
# throttle: 同 session 同日 1 回のみ (flag file で管理)
# 検出時: systemMessage に /clear + 書き直 を含む通知を付与
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
    _rotate_log_if_needed "$HOME/.claude/logs/fail-repeat-detect.log"
    printf '[%s] fail-repeat fired | sid=%s | prompt=%.100s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${session_id}" "${prompt_lc}" >> "$HOME/.claude/logs/fail-repeat-detect.log" 2>/dev/null || true
  fi

  # 今回の失敗 prompt を記録 (200 字以内で保存)
  printf '%s\n' "${prompt_lc:0:200}" > "${_FAIL_FILE}" 2>/dev/null || true
}
