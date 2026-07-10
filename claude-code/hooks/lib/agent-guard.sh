#!/usr/bin/env bash
# agent-guard checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_AGENT_GUARD_LOADED:-}" == "1" ]]; then
    return 0
fi
_AGENT_GUARD_LOADED=1

# shellcheck source=thresholds.sh
source "${BASH_SOURCE[0]%/*}/thresholds.sh"

# ====================================
# parent 事前準備 missing 検出 (warn-only)
# Task tool 発火 prompt が ≥500 word かつ file:line pattern / label 付き keyword
# (verify cmd: / DoD: / target file:) のいずれも未出現の場合に warn を返す (block はしない)
# 引数: prompt (string)
# 戻り値: 0 = missing 検出 / 1 = 事前準備済 or 短 prompt
# ====================================
_check_parent_prep_missing() {
  local prompt="$1"
  # 短 prompt は対象外 (≤500 word の subagent context budget と一致)
  local word_count
  word_count=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
  [ "$word_count" -lt 500 ] && return 1

  # file:line pattern (例: src/foo.ts:42) のみ「事前準備済」とみなす
  # 自然言語中の target / verify 単語では trigger しない (too-broad false-negative 防止)
  # (^|[[:space:]]) 境界を要求: URL 内の host:port (例: example.com:8080) は ://直後で空白前置なし → 除外
  if printf '%s' "$prompt" | grep -qE "(^|[[:space:]])[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+"; then
    return 1
  fi
  # label 付き keyword のみ trigger: "verify cmd:" / "DoD:" / "target file:" 等
  if printf '%s' "$prompt" | grep -qiE "(verify cmd|DoD|target file)[ \t]*[:=]"; then
    return 1
  fi
  return 0  # 事前準備 missing 検出
}

# ====================================
# 口語起動 marker 検出 (warn-only)
# Task tool 発火 prompt に口語起動 marker (お任せ / 全部 等) が含まれ、
# かつ file:line 明示がない場合に warn を返す (block はしない)
# 引数: prompt (string)
# 戻り値: 0 = marker 検出 (warn 対象) / 1 = marker なし or file:line 明示済
# ====================================
_check_colloquial_trigger_missing_delegation() {
  local prompt="$1"

  # marker list: 口語起動を示す JP/EN フレーズ (case-insensitive POSIX ERE)
  # お任せ / おまかせ / 全部 / 全消化 / できるもの全部 / 修正して欲しい / 改善して / 全自動で / auto で
  if ! printf '%s' "$prompt" | grep -qiE \
    'お任せ|おまかせ|全部|全消化|できるもの全部|修正して欲しい|改善して|全自動で|auto[[:space:]]*で'; then
    return 1  # marker なし → warn 不要
  fi

  # file:line が明示されていれば事前準備済とみなし warn しない
  # _check_parent_prep_missing と同一判定 (空白境界 + URL host:port 除外)
  if printf '%s' "$prompt" | grep -qE "(^|[[:space:]])[a-zA-Z0-9_./-]+\.[a-zA-Z]+:[0-9]+"; then
    return 1  # file:line あり → 委譲準備済
  fi
  if printf '%s' "$prompt" | grep -qiE "(verify cmd|DoD|target file)[ \t]*[:=]"; then
    return 1  # label 付き keyword あり → 委譲準備済
  fi

  return 0  # marker 検出 + file:line なし → warn 対象
}

# ====================================
# session split warn (warn-only, pre-tool-use)
# session age >= 3h or jsonl msg 数 >= 1000 で /clear 推奨を additionalContext に注入
# 1 session につき 1 回のみ発火 (state file: ~/.claude/logs/.session-split-warned-<id>)
# ====================================
_check_session_split() {
  local session_id="$1"
  local cwd="$2"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0

  local _WARN_FILE="${HOME}/.claude/logs/.session-split-warned-${session_id}"
  local _FORCE_FILE="${HOME}/.claude/logs/.session-split-forced-${session_id}"
  [[ -f "$_WARN_FILE" && -f "$_FORCE_FILE" ]] && return 0  # warn / force 両方通知済 → skip

  # jsonl path 構築 (msg count で引き続き使用)
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  [[ ! -f "$_JSONL" ]] && return 0

  # session start epoch (共通関数で解決)
  local _NOW
  printf -v _NOW '%(%s)T' -1
  local _START_EPOCH
  _START_EPOCH=$(_resolve_session_jsonl_epoch "$session_id" "$cwd") || return 0
  local _ELAPSED=$(( _NOW - _START_EPOCH ))

  # msg count
  local _MSG_COUNT
  _MSG_COUNT=$(grep -c '"type":"user"\|"type":"assistant"' "$_JSONL" 2>/dev/null) || _MSG_COUNT=0

  local _AGE_H=$(( _ELAPSED / 3600 ))

  # --- force level (400 msg): warn とは独立に 1 session 1 回、強指示を注入 ---
  if [[ ! -f "$_FORCE_FILE" ]] && (( _MSG_COUNT >= _TH_SESSION_MSG_FORCE )); then
    mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
    touch "$_FORCE_FILE" 2>/dev/null || true
    local _TS_FORCE
    printf -v _TS_FORCE '%(%Y-%m-%dT%H:%M:%S%z)T' -1
    printf '%s | %s | level=force | msg=%s\n' "$_TS_FORCE" "$session_id" "$_MSG_COUNT" \
      >> "${HOME}/.claude/logs/session-split-warn.log" 2>/dev/null || true
    local _FORCE_MSG="[session-split-force] messages=${_MSG_COUNT} >= ${_TH_SESSION_MSG_FORCE}。context 常駐が肥大している。現在の step を完了させたら新しい subtask に着手せず、/memory-save で work-context を保存して user に /clear を提案すること"
    if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_FORCE_MSG}"
    else
      ADDITIONAL_CONTEXT="${_FORCE_MSG}"
    fi
    return 0
  fi

  [[ -f "$_WARN_FILE" ]] && return 0  # warn 通知済 → skip

  local _REASON=""
  (( _ELAPSED >= _TH_SESSION_AGE_S )) && _REASON="age=${_AGE_H}h"
  if (( _MSG_COUNT >= _TH_SESSION_MSG )); then
    [[ -n "$_REASON" ]] && _REASON="${_REASON} / "
    _REASON="${_REASON}messages=${_MSG_COUNT}"
  fi
  [[ -z "$_REASON" ]] && return 0

  # 発火: state file 書き込み + log 追記 + additionalContext 追加
  mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
  touch "$_WARN_FILE" 2>/dev/null || true
  local _TS_LABEL
  printf -v _TS_LABEL '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | %s | %s | msg=%s\n' "$_TS_LABEL" "$session_id" "age=${_AGE_H}h" "$_MSG_COUNT" \
    >> "${HOME}/.claude/logs/session-split-warn.log" 2>/dev/null || true

  local _WARN_MSG="[session-split-warn] ${_REASON} exceeds threshold (3h / ${_TH_SESSION_MSG} msg). Suggest /clear or /compact to refresh cache TTL"
  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_WARN_MSG}"
  else
    ADDITIONAL_CONTEXT="${_WARN_MSG}"
  fi
}

# ====================================
# large-repo 連続 Edit 強制委譲 signal (warn-only, pre-tool-use)
# ====================================
# parent が 1 message 1 Task で逐次 Agent fire する pattern を検出し、
# 並列化を促す additionalContext を注入する (warn-only)
#
# 発火条件: tool_name == "Task" の pre-tool-use 時のみ
# counter: ~/.claude/logs/.agent-fire-count-<session_id>  (整数 1 行)
# 最終 fire timestamp: ~/.claude/logs/.agent-fire-lastts-<session_id>  (nanosec 整数)
# fence: ~/.claude/logs/.sequential-fire-warned-<session_id>  (1 threshold 1 inject)
# log: ~/.claude/logs/sequential-fire-warn.log
#
# parallel 判定: 直前 Task fire から 500ms (500000000 ns) 以内 = 同一 message 内並列発火
#   → counter をリセット (並列は問題ない)
# sequential 判定: 500ms 超 = 別 message からの逐次発火
#   → counter++ し threshold (>=3) で warn 1 回 inject
# ====================================
_check_sequential_agent_fire() {
  local session_id="$1"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0

  local _LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true

  local _COUNT_FILE="${_LOG_DIR}/.agent-fire-count-${session_id}"
  local _LASTTS_FILE="${_LOG_DIR}/.agent-fire-lastts-${session_id}"
  local _FENCE_FILE="${_LOG_DIR}/.sequential-fire-warned-${session_id}"

  # 現在 timestamp (nanosec)
  local _NOW_NS
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    # bash 5.0+ builtin: fork 0、形式 "1234567890.123456" → ns 9桁 padding
    _NOW_NS="${EPOCHREALTIME/./}000"
  else
    _NOW_NS=$(date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)")
  fi

  # 直前 fire timestamp 取得
  local _LAST_NS=0
  [[ -f "$_LASTTS_FILE" ]] && read -r _LAST_NS < "$_LASTTS_FILE" 2>/dev/null || _LAST_NS=0
  # 数値チェック (破損対策)
  [[ "$_LAST_NS" =~ ^[0-9]+$ ]] || _LAST_NS=0

  # timestamp を更新
  printf '%s\n' "$_NOW_NS" > "$_LASTTS_FILE" 2>/dev/null || true

  # 経過時間 (ns)
  local _ELAPSED=$(( _NOW_NS - _LAST_NS ))

  # 500ms 以内 → 同一 message 内並列発火と推定 → counter リセット
  local _PARALLEL_THRESHOLD_NS=$_TH_PARALLEL_WINDOW_NS
  if (( _LAST_NS > 0 && _ELAPSED <= _PARALLEL_THRESHOLD_NS )); then
    # 並列発火検出: counter リセット (fence は維持)
    printf '0\n' > "$_COUNT_FILE" 2>/dev/null || true
    return 0
  fi

  # fence 通過済み → 新 sequence でも再 warn しない
  [[ -f "$_FENCE_FILE" ]] && return 0

  # counter インクリメント
  local _CUR=0
  [[ -f "$_COUNT_FILE" ]] && read -r _CUR < "$_COUNT_FILE" 2>/dev/null || _CUR=0
  [[ "$_CUR" =~ ^[0-9]+$ ]] || _CUR=0
  _CUR=$(( _CUR + 1 ))
  printf '%s\n' "$_CUR" > "$_COUNT_FILE" 2>/dev/null || true

  # threshold 判定 (>= _TH_PARALLEL_SEQ、speed-bias)
  if (( _CUR >= _TH_PARALLEL_SEQ )); then
    touch "$_FENCE_FILE" 2>/dev/null || true

    # ログ追記
    local _TS_LABEL
    printf -v _TS_LABEL '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s | %s | counter=%s | elapsed_ms=%s\n' \
      "$_TS_LABEL" "$session_id" "$_CUR" "$(( _ELAPSED / 1000000 ))" \
      >> "${_LOG_DIR}/sequential-fire-warn.log" 2>/dev/null || true

    local _SUGGEST="[parallel-fire-suggest] last ${_CUR} Agent fires sequential (peak=1). 次の発火は 1 message 内 N tool_use 並列必須。independent task ≥2 なら 100% 並列、迷ったら並列側 (CLAUDE.md Auto-Delegation default=並列)"
    if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_SUGGEST}"
    else
      ADDITIONAL_CONTEXT="${_SUGGEST}"
    fi
  fi
}

# ====================================
# developer-agent 限定 bundle 違反検出 (warn-only)
# /flow step 7 / `flow.md` L110: Task(developer-agent)×N は 1 message bundle 必須
# 連続発火 (>_TH_PARALLEL_WINDOW_NS 間隔) ≥2 回 = bundle 違反 = parentUuid serial chain
# (work-context-20260618-flow-self-review-3gate.md next-action #1)
#
# $2 = task prompt。prompt に `serial_reason:` 宣言がある逐次発火は
# 依存 chain (前 agent の結果待ち) として counter 対象外にする。
# 宣言なしの正当な依存 chain も 3 発で hard block されるため、delegate が
# inline より高コストになり inline 回帰を誘発していた (2026-07-04/05 block log ×3)。
#
# counter: ~/.claude/logs/.dev-agent-fire-count-<session_id>
# 最終 fire timestamp: ~/.claude/logs/.dev-agent-fire-lastts-<session_id>
# fence: ~/.claude/logs/.bundle-violation-warned-<session_id>  (1 threshold 1 inject)
# log: ~/.claude/logs/bundle-violation-warn.log
# ====================================
_check_developer_agent_bundle_violation() {
  local session_id="$1"
  local task_prompt="${2:-}"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0

  local _LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true

  local _COUNT_FILE="${_LOG_DIR}/.dev-agent-fire-count-${session_id}"
  local _LASTTS_FILE="${_LOG_DIR}/.dev-agent-fire-lastts-${session_id}"
  local _SIZE_FILE="${_LOG_DIR}/.dev-agent-fire-bundlesize-${session_id}"
  local _FENCE_FILE="${_LOG_DIR}/.bundle-violation-warned-${session_id}"
  local _BLOCK_FENCE_FILE="${_LOG_DIR}/.bundle-violation-blocked-${session_id}"

  local _NOW_NS
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    _NOW_NS="${EPOCHREALTIME/./}000"
  else
    _NOW_NS=$(date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)")
  fi

  local _LAST_NS=0
  [[ -f "$_LASTTS_FILE" ]] && read -r _LAST_NS < "$_LASTTS_FILE" 2>/dev/null || _LAST_NS=0
  [[ "$_LAST_NS" =~ ^[0-9]+$ ]] || _LAST_NS=0

  printf '%s\n' "$_NOW_NS" > "$_LASTTS_FILE" 2>/dev/null || true

  local _ELAPSED=$(( _NOW_NS - _LAST_NS ))

  # _TH_PARALLEL_WINDOW_NS (30s) 以内 = 1 message bundle 並列 (正常)、counter 維持 (リセットしない)
  # 旧実装は counter=0 リセットだったため「並列を 1 回挟むと sequential 検出が永久に再起動」
  # する bug があり、混合パターン (並列 → 直列 → 直列) を見逃していた。
  # 累積 sequential 発火数を維持して直列 chain を必ず検出する。
  # bundle size を記録し、次の bundle 開始時に「直前 bundle が solo だったか」を後判定する。
  if (( _LAST_NS > 0 && _ELAPSED <= _TH_PARALLEL_WINDOW_NS )); then
    local _BSZ=1
    [[ -f "$_SIZE_FILE" ]] && read -r _BSZ < "$_SIZE_FILE" 2>/dev/null || _BSZ=1
    [[ "$_BSZ" =~ ^[0-9]+$ ]] || _BSZ=1
    printf '%s\n' "$(( _BSZ + 1 ))" > "$_SIZE_FILE" 2>/dev/null || true
    return 0
  fi

  # serial_reason 宣言 = 前 agent の結果に依存する正当な逐次発火 → counter 対象外。
  # 独立 task への serial_reason 濫用は禁止 (references/auto-delegation-detailed.md canonical)。
  # audit 用に warn log へ marker 付きで記録する。
  if [[ -n "$task_prompt" && "$task_prompt" == *"serial_reason:"* ]]; then
    local _TS_SERIAL
    printf -v _TS_SERIAL '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s | %s | serial_reason_declared | elapsed_ms=%s\n' \
      "$_TS_SERIAL" "$session_id" "$(( _ELAPSED / 1000000 ))" \
      >> "${_LOG_DIR}/bundle-violation-warn.log" 2>/dev/null || true
    # size=0 (exempt marker): 次の bundle 開始時に solo として count させない
    printf '0\n' > "$_SIZE_FILE" 2>/dev/null || true
    return 0
  fi

  # 新 bundle 開始: 直前 bundle の size で solo / 並列を後判定する。
  # 並列 bundle (size>=2) の先頭発火も無条件 +1 する旧実装では、正当な多段 batch
  # (並列 bundle → merge → 並列 bundle) が batch 数回で hard block に到達する
  # false positive があった (2026-07-05 incident)。solo bundle (size==1) が確定した
  # 時のみ counter++ し、判定値 _CUR = 確定 solo 数 + 今回 (暫定 solo) で
  # 純粋な直列 chain の warn (2 発目) / block (3 発目) タイミングは従来と同一に保つ。
  # NOTE: fence check はカウンタ更新・block 判定の後に置く。
  # 旧実装は fence check を先に置いていたため「warn 発火後の 3 回目以降が early return」
  # し、hard block threshold (_TH_BUNDLE_HARD_BLOCK_SEQ=3) に永遠に到達しない bug があった。
  local _PREV_SIZE=0
  [[ -f "$_SIZE_FILE" ]] && read -r _PREV_SIZE < "$_SIZE_FILE" 2>/dev/null || _PREV_SIZE=0
  [[ "$_PREV_SIZE" =~ ^[0-9]+$ ]] || _PREV_SIZE=0
  printf '1\n' > "$_SIZE_FILE" 2>/dev/null || true

  local _CONFIRMED=0
  [[ -f "$_COUNT_FILE" ]] && read -r _CONFIRMED < "$_COUNT_FILE" 2>/dev/null || _CONFIRMED=0
  [[ "$_CONFIRMED" =~ ^[0-9]+$ ]] || _CONFIRMED=0
  if (( _PREV_SIZE == 1 )); then
    _CONFIRMED=$(( _CONFIRMED + 1 ))
    printf '%s\n' "$_CONFIRMED" > "$_COUNT_FILE" 2>/dev/null || true
  fi
  local _CUR=$(( _CONFIRMED + 1 ))

  # 初回 fire (直前 bundle なし + 確定 solo なし) で bundle 判断を先出し inject する。
  # warn (2 発目) 時点では 1 体目の直列実行時間 (実測 2-4 分) を既に浪費している。
  # 30d 実測 (flow-baseline n=22) で peak_concurrency=1 が 10 回 = 45% あり、
  # 発火前の task 全列挙を促すのが最大の並列化 lever。
  if (( _PREV_SIZE == 0 && _CONFIRMED == 0 )); then
    local _PRE_CHECK="[bundle-pre-check] developer-agent 初回発火。残 task を今全列挙し、独立 task が残るなら次は 1 message に N tool_use で bundle 発火する (逐次発火は 2 発目 warn / ${_TH_BUNDLE_HARD_BLOCK_SEQ} 発目 hard block)。前 agent の結果に依存する逐次発火は prompt に serial_reason: <依存内容 1 行> を書く (counter 対象外)"
    if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_PRE_CHECK}"
    else
      ADDITIONAL_CONTEXT="${_PRE_CHECK}"
    fi
    return 0
  fi

  # threshold ≥3 で hard block (PO Gate v2 enforcement、warn 後の更なる sequential fire は明確な違反)
  # CLAUDE_BUNDLE_HARD_BLOCK=0 で opt-out (debug / 一時的 escape hatch)
  if (( _CUR >= _TH_BUNDLE_HARD_BLOCK_SEQ )) && [[ "${CLAUDE_BUNDLE_HARD_BLOCK:-1}" != "0" ]]; then
    if [[ ! -f "$_BLOCK_FENCE_FILE" ]]; then
      touch "$_BLOCK_FENCE_FILE" 2>/dev/null || true
      local _TS_BLOCK
      printf -v _TS_BLOCK '%(%Y-%m-%dT%H:%M:%S)T' -1
      printf '%s | %s | dev_count=%s | elapsed_ms=%s\n' \
        "$_TS_BLOCK" "$session_id" "$_CUR" "$(( _ELAPSED / 1000000 ))" \
        >> "${_LOG_DIR}/bundle-violation-block.log" 2>/dev/null || true
    fi
    echo "[bundle-violation-block] Task(developer-agent) ${_CUR} 回逐次発火 = PO Gate v2 違反。独立 task なら 1 message bundle で並列 fan-out する。前 agent の結果に依存する逐次発火なら prompt に serial_reason: <依存内容 1 行> を明記して再発火する (counter 対象外)。opt-out: env CLAUDE_BUNDLE_HARD_BLOCK=0" >&2
    exit 2
  fi

  # fence 通過済 → warn は 1 回のみ (重複抑制)
  [[ -f "$_FENCE_FILE" ]] && return 0

  # threshold ≥2 で warn (1 発目は正常な単発 dev、2 発目連続発火が bundle 違反 signal)
  if (( _CUR >= _TH_PARALLEL_SEQ )); then
    touch "$_FENCE_FILE" 2>/dev/null || true

    local _TS_LABEL
    printf -v _TS_LABEL '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s | %s | dev_count=%s | elapsed_ms=%s\n' \
      "$_TS_LABEL" "$session_id" "$_CUR" "$(( _ELAPSED / 1000000 ))" \
      >> "${_LOG_DIR}/bundle-violation-warn.log" 2>/dev/null || true

    local _SUGGEST="[bundle-violation-warn] Task(developer-agent) を ${_CUR} 回逐次発火 (elapsed >30s = parentUuid serial chain)。/flow step 7 は 1 message bundle 必須 (commands/flow.md L110 / N declaration : tool_use firing message = 1:1 strict)。依存 chain の逐次発火なら prompt に serial_reason: を明記する (counter 対象外)。${_TH_BUNDLE_HARD_BLOCK_SEQ} 回目で hard block する"
    if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_SUGGEST}"
    else
      ADDITIONAL_CONTEXT="${_SUGGEST}"
    fi
  fi
}

# ====================================
# 同 session 内で直近 5 回連続 Write/Edit/MultiEdit が large-repo src に hit した場合に
# developer-agent 委譲を促す additionalContext を注入する
# counter: ~/.claude/logs/.large-repo-edit-count-<session_id>
# 重複抑制: ~/.claude/logs/.delegation-warned-<session_id> (1 threshold につき 1 回)
# ====================================
_check_large_repo_consecutive_edit() {
  local session_id="$1"
  local file_path="$2"
  [[ -z "$session_id" || "$session_id" == "null" ]] && return 0
  [[ -z "$file_path" ]] && return 0

  local _LOG_DIR="${HOME}/.claude/logs"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true
  local _COUNT_FILE="${_LOG_DIR}/.large-repo-edit-count-${session_id}"
  local _WARN_FILE="${_LOG_DIR}/.delegation-warned-${session_id}"

  # large-repo src pattern 判定
  # 対象: 明示 prefix に絞る (~/ghq/github.com/ 全体は OSS clone を巻き込むため削除)
  # ai-tools 自身も対象 (speed-bias: parent inline edit が Opus 比率悪化の主因)
  # hook source は allowlist 対象のため social-hit term literal 記載可 (rules/public-repo-private-data-block.md)
  local _IS_LARGE_REPO=0
  case "$file_path" in
    "${HOME}"/ghq/github.com/snkrdunk/* | \
    "${HOME}"/ghq/github.com/snkrdunk-loadtest/* | \
    "${HOME}"/ghq/github.com/snkrdunk-terraform/* | \
    "${HOME}"/ghq/github.com/DaichiHoshina/ai-tools/* | \
    "${HOME}"/ai-tools/*)
      _IS_LARGE_REPO=1 ;;
    *)
      _IS_LARGE_REPO=0 ;;
  esac

  # src 拡張子チェック (ai-tools の hook/skill/command/agent/rule は .sh/.md)
  local _IS_SRC=0
  case "$file_path" in
    *.go|*.ts|*.tsx|*.py|*.dart|*.tf|*.sh|*.md) _IS_SRC=1 ;;
  esac

  if [[ "$_IS_LARGE_REPO" -eq 1 && "$_IS_SRC" -eq 1 ]]; then
    # hit: counter をインクリメント
    local _CUR=0
    [[ -f "$_COUNT_FILE" ]] && read -r _CUR < "$_COUNT_FILE" 2>/dev/null || _CUR=0
    _CUR=$(( _CUR + 1 ))
    printf '%s\n' "$_CUR" > "$_COUNT_FILE" 2>/dev/null || true

    # threshold 判定 (>= _TH_DELEGATE_SEQ、speed-bias)
    if (( _CUR >= _TH_DELEGATE_SEQ )) && [[ ! -f "$_WARN_FILE" ]]; then
      touch "$_WARN_FILE" 2>/dev/null || true
      local _SUGGEST="[delegation-suggest] last ${_CUR} inline edits 検出。次の edit-class op は developer-agent 委譲 default (CLAUDE.md \"2 consecutive inline exceptions → mandatory delegation\" 違反リスク)"
      if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_SUGGEST}"
      else
        ADDITIONAL_CONTEXT="${_SUGGEST}"
      fi
    fi
  else
    # non-large-repo hit: counter をリセット
    printf '0\n' > "$_COUNT_FILE" 2>/dev/null || true
  fi
}
