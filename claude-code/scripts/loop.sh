#!/usr/bin/env bash
# loop.sh — external headless loop driver (毎 iteration fresh context)
#
# 目的: `claude -p` を fresh context で反復起動し、objective gate (exit code) が
#   green になるまで 1 iteration ずつ進める。同一 session 内 loop (/goal) と違い、
#   context rot / compaction による goal drift が構造的に起きない。
#   iteration 間の知識継承は state file (~/.claude/loops/<name>/state.md) のみ。
#
# 判定の分離:
#   layer-1 checker = 本 script が bash で実行する gate (maker process と完全分離)
#   layer-2 checker = --review 時のみ、別 model の fresh `claude -p` が diff だけを見て
#                     VERDICT: APPROVE|REJECT を返す (maker reasoning は構造的に非開示)
#
# Usage:
#   loop.sh --name <name> --gate "<cmd>" [options]
#
# Options:
#   --name <name>          loop ID。state dir = ~/.claude/loops/<name>/ (必須)
#   --gate "<cmd>"         objective gate。exit code が唯一の判定 (必須)
#   --repo <path>          作業 repo (default: cwd)
#   --prompt <path>        standing objective file (default: <state dir>/PROMPT.md)
#   --max-iter <n>         default 10
#   --max-minutes <m>      default 60
#   --max-cost-usd <x>     累積 cost 上限 (default 5.00)
#   --model <m>            maker model (default: sonnet)
#   --review               layer-2 checker を有効化
#   --checker-model <m>    layer-2 checker model (default: haiku)
#   --checker-cmd "<cmd>"  checker を外部 command に差替 (stdin=prompt, stdout=VERDICT 行)
#   --gate-retries <n>     gate flaky 対策の即時再実行回数 (default 1)
#   --permission-mode <m>  claude -p の permission mode (default: acceptEdits)
#   --yolo                 --dangerously-skip-permissions で実行 (opt-in)
#   --notify               完了 / abort 時に macOS notification
#   --dry-run              組立 prompt と実行計画のみ表示
#
# Exit codes:
#   0=gate green / 1=usage error / 2=max-iter / 3=timeout / 4=no-progress
#   5=cost budget / 6=state corrupt / 130=interrupt
set -euo pipefail

NAME=""
GATE=""
REPO="$PWD"
PROMPT_FILE=""
MAX_ITER=10
MAX_MINUTES=60
MAX_COST_USD="5.00"
MODEL="sonnet"
REVIEW=0
CHECKER_MODEL="haiku"
CHECKER_CMD=""
GATE_RETRIES=1
PERMISSION_MODE="acceptEdits"
YOLO=0
NOTIFY=0
DRY_RUN=0

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --gate) GATE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --max-iter) MAX_ITER="$2"; shift 2 ;;
    --max-minutes) MAX_MINUTES="$2"; shift 2 ;;
    --max-cost-usd) MAX_COST_USD="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --review) REVIEW=1; shift ;;
    --checker-model) CHECKER_MODEL="$2"; shift 2 ;;
    --checker-cmd) CHECKER_CMD="$2"; shift 2 ;;
    --gate-retries) GATE_RETRIES="$2"; shift 2 ;;
    --permission-mode) PERMISSION_MODE="$2"; shift 2 ;;
    --yolo) YOLO=1; shift ;;
    --notify) NOTIFY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[[ -n "$NAME" && -n "$GATE" ]] || { echo "ERROR: --name と --gate は必須" >&2; exit 1; }
[[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: --name は英数と . _ - のみ" >&2; exit 1; }
command -v claude >/dev/null || { echo "ERROR: claude CLI が見つからない" >&2; exit 1; }
command -v jq >/dev/null || { echo "ERROR: jq が見つからない" >&2; exit 1; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: --repo が git repo でない: ${REPO}" >&2; exit 1; }

LOOP_DIR="${HOME}/.claude/loops/${NAME}"
STATE="${LOOP_DIR}/state.md"
STATE_BAK="${LOOP_DIR}/state.md.bak"
GATE_OUT="${LOOP_DIR}/.gate-out"
[[ -n "$PROMPT_FILE" ]] || PROMPT_FILE="${LOOP_DIR}/PROMPT.md"
LOG_DIR="${HOME}/.claude/logs"
LOG="${LOG_DIR}/loop-${NAME}.log"
PRIVATE_TERM_FILE="${HOME}/.claude/references-private/private-name-list.txt"
mkdir -p "$LOOP_DIR" "$LOG_DIR"

[[ -f "$PROMPT_FILE" ]] || {
  echo "ERROR: PROMPT.md がない: ${PROMPT_FILE}" >&2
  echo "  /loop init か templates/loop-prompt.md.template から作成してください" >&2
  exit 1
}

_log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG" >&2; }

# public repo guard 整合: state に書く gate 出力は private term を伏せる
_redact() {
  local sed_args=() term
  if [[ -s "$PRIVATE_TERM_FILE" ]]; then
    while IFS= read -r term; do
      [[ -n "$term" ]] || continue
      sed_args+=(-e "s|${term}|[REDACTED]|g")
    done < "$PRIVATE_TERM_FILE"
  fi
  if [[ ${#sed_args[@]} -gt 0 ]]; then sed "${sed_args[@]}"; else cat; fi
}

# working tree 全体 (HEAD + staged + unstaged + untracked 一覧) の指紋
_tree_hash() {
  {
    git -C "$REPO" rev-parse HEAD 2>/dev/null || echo no-head
    git -C "$REPO" status --porcelain
    git -C "$REPO" diff
    git -C "$REPO" diff --cached
    # untracked file は git diff に出ないため内容も指紋に含める
    git -C "$REPO" ls-files --others --exclude-standard -z \
      | (cd "$REPO" && xargs -0 shasum -a 256 2>/dev/null) || true
  } | shasum -a 256 | cut -d' ' -f1
}

_init_state() {
  [[ -f "$STATE" ]] && return 0
  cat > "$STATE" <<EOF
# ${NAME} loop state

- Gate: \`${GATE}\`
- Status: running
- Created: $(date '+%Y-%m-%dT%H:%M:%S%z')

## Progress ledger

| iter | datetime | diff stat | gate | cost (USD) |
|------|----------|-----------|------|------------|

## Lessons learned

## Next-iteration hint

## Blocked

## Gate log
EOF
}

_set_status() {
  sed "s|^- Status: .*|- Status: $1|" "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
}

# agent が state.md を壊していないか (必須 heading 4 つ)
_validate_state() {
  local h
  for h in '## Progress ledger' '## Lessons learned' '## Next-iteration hint' '## Blocked'; do
    grep -qF "$h" "$STATE" || return 1
  done
}

# table separator 行の直後に挿入 (newest-first で table を連続させる)
_append_ledger() {
  local row="| $1 | $(date '+%F %T') | $2 | $3 | $4 |"
  awk -v row="$row" '{ print; if (!done && /^\|---/) { print row; done = 1 } }' \
    "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
}

# Lessons learned 節の末尾 (次 heading の直前) に追記する
_append_lesson() {
  local line="$1"
  awk -v line="$line" '/^## Next-iteration hint/ && !done { print line; print ""; done = 1 } { print }' \
    "$STATE" > "${STATE}.tmp" && mv "${STATE}.tmp" "$STATE"
}

_append_gate_log() {
  grep -qF '## Gate log' "$STATE" || printf '\n## Gate log\n' >> "$STATE"
  {
    printf '\n### iter %s (%s)\n\n```text\n' "$1" "$2"
    tail -n 20 "$GATE_OUT" | _redact
    printf '```\n'
  } >> "$STATE"
}

_build_prompt() {
  cat "$PROMPT_FILE"
  printf '\n---\n\n## Current loop state (%s)\n\n' "$STATE"
  cat "$STATE"
  cat <<EOF

---

## Instructions for this iteration

- 作業 repo: ${REPO} (お前の cwd)。file 操作はこの repo 内で行う。
- 上の objective に向けて 1 iteration 分だけ進めよ。完了宣言はするな。gate だけが完了を判定する。
- gate command: \`${GATE}\` (お前は実行してよいが、判定は外側の driver が行う)
- 作業後、state file ${STATE} を更新せよ:
  - "## Lessons learned" に今回学んだことを append する (既存行は消すな)
  - "## Next-iteration hint" を次の 1 手が分かる 1-3 行に上書きする
  - 他の section と heading は変更するな
- 人間の判断が必要になったら "## Blocked" に理由を書いて作業を終えよ。
EOF
}

_run_gate() {
  local attempt=0
  while :; do
    if (cd "$REPO" && bash -c "$GATE") > "$GATE_OUT" 2>&1; then
      return 0
    fi
    attempt=$((attempt + 1))
    if [[ "$attempt" -gt "$GATE_RETRIES" ]]; then
      return 1
    fi
    _log "gate fail (attempt ${attempt}) → flaky 対策で即時再実行"
  done
}

CHECKER_REASON=""
_run_checker() {
  local diff cprompt out
  diff=$(git -C "$REPO" diff HEAD 2>/dev/null | head -c 100000)
  # shellcheck disable=SC2016  # backtick / $ は literal のまま渡す
  cprompt=$(printf 'You are an independent reviewer. Judge ONLY from the objective and the diff below.\n\n## Objective\n\n%s\n\n## Diff\n\n```diff\n%s\n```\n\nRespond with exactly one line: "VERDICT: APPROVE" or "VERDICT: REJECT <reason>".\n' \
    "$(cat "$PROMPT_FILE")" "$diff")
  if [[ -n "$CHECKER_CMD" ]]; then
    out=$(printf '%s' "$cprompt" | bash -c "$CHECKER_CMD" 2>>"$LOG" || true)
  else
    out=$(printf '%s' "$cprompt" | claude -p --model "$CHECKER_MODEL" --output-format json 2>>"$LOG" | jq -r '.result // empty' || true)
  fi
  if grep -q 'VERDICT: APPROVE' <<< "$out"; then
    return 0
  fi
  CHECKER_REASON=$(grep -o 'VERDICT: REJECT.*' <<< "$out" | head -1)
  [[ -n "$CHECKER_REASON" ]] || CHECKER_REASON="VERDICT: REJECT (checker 出力が parse 不能)"
  return 1
}

_notify() {
  [[ "$NOTIFY" -eq 1 ]] || return 0
  command -v osascript >/dev/null || return 0
  osascript -e "display notification \"$1\" with title \"loop.sh: ${NAME}\"" 2>/dev/null || true
}

_finish() {
  local code="$1" status_label="$2" msg="$3"
  _set_status "$status_label"
  _log "$msg"
  _notify "$msg"
  echo "---"
  echo "loop: ${NAME} / ${msg}"
  echo "state: ${STATE}"
  echo "次の一手: /loop status ${NAME} → 有用な lessons は /memory-save ${NAME}-loop で恒久化"
  exit "$code"
}

# shellcheck disable=SC2329  # trap 経由で呼ばれる
_on_interrupt() {
  trap - INT TERM
  _set_status "aborted(interrupt)"
  _log "interrupt を受けたので state を aborted にして終了する (自動再開しない)"
  exit 130
}

_init_state

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=== loop plan (dry-run) ==="
  echo "name=${NAME} repo=${REPO} model=${MODEL} gate=${GATE}"
  echo "max-iter=${MAX_ITER} max-minutes=${MAX_MINUTES} max-cost-usd=${MAX_COST_USD}"
  echo "review=${REVIEW} checker=${CHECKER_CMD:-claude:${CHECKER_MODEL}} gate-retries=${GATE_RETRIES}"
  echo ""
  echo "=== assembled prompt (iteration 1) ==="
  _build_prompt
  exit 0
fi

trap _on_interrupt INT TERM

PERM_ARGS=(--permission-mode "$PERMISSION_MODE")
[[ "$YOLO" -eq 1 ]] && PERM_ARGS=(--dangerously-skip-permissions)

MAX_SECONDS=$((MAX_MINUTES * 60))
iter=0
no_progress=0
total_cost=0

_log "loop start: name=${NAME} gate='${GATE}' max-iter=${MAX_ITER} max-minutes=${MAX_MINUTES} max-cost-usd=${MAX_COST_USD}"

while [[ "$iter" -lt "$MAX_ITER" ]]; do
  iter=$((iter + 1))

  if [[ "$SECONDS" -ge "$MAX_SECONDS" ]]; then
    _finish 3 "aborted(timeout)" "timeout: ${MAX_MINUTES}m 経過 (iter ${iter} 開始前)"
  fi

  cp "$STATE" "$STATE_BAK"
  before_hash=$(_tree_hash)
  _log "iter ${iter}/${MAX_ITER}: maker (${MODEL}) 起動"

  maker_json=$(_build_prompt | (cd "$REPO" && claude -p --model "$MODEL" --output-format json "${PERM_ARGS[@]}") 2>>"$LOG" || true)
  iter_cost=$(jq -r '.total_cost_usd // 0' <<< "$maker_json" 2>/dev/null || echo 0)
  total_cost=$(awk -v a="$total_cost" -v b="$iter_cost" 'BEGIN { printf "%.4f", a + b }')

  if ! _validate_state; then
    cp "$STATE_BAK" "$STATE"
    _finish 6 "aborted(state-corrupt)" "state.md の必須 heading が壊れたので .bak から復元して停止 (iter ${iter})"
  fi

  after_hash=$(_tree_hash)
  if [[ "$before_hash" == "$after_hash" ]]; then
    no_progress=$((no_progress + 1))
    _log "iter ${iter}: working tree 不変 (${no_progress} 連続)"
    if [[ "$no_progress" -ge 2 ]]; then
      _append_ledger "$iter" "-" "NO-PROGRESS" "$iter_cost"
      _finish 4 "aborted(no-progress)" "tree hash 不変が 2 連続 → 空回りと判定して停止"
    fi
  else
    no_progress=0
  fi

  diff_stat=$(git -C "$REPO" diff --shortstat 2>/dev/null | sed 's/^ *//' || true)
  [[ -n "$diff_stat" ]] || diff_stat="-"

  if _run_gate; then
    if [[ "$REVIEW" -eq 1 ]] && ! _run_checker; then
      _log "iter ${iter}: gate green だが checker REJECT → 続行"
      _append_ledger "$iter" "$diff_stat" "CHECKER-REJECT" "$iter_cost"
      _append_lesson "$(printf -- '- [checker iter %s] %s' "$iter" "$CHECKER_REASON" | _redact)"
    else
      _append_ledger "$iter" "$diff_stat" "PASS" "$iter_cost"
      _finish 0 "done" "gate green (iter ${iter}, cost \$${total_cost})"
    fi
  else
    _log "iter ${iter}: gate fail"
    _append_ledger "$iter" "$diff_stat" "FAIL" "$iter_cost"
    _append_gate_log "$iter" "FAIL"
  fi

  if awk -v a="$total_cost" -v b="$MAX_COST_USD" 'BEGIN { exit !(a >= b) }'; then
    _finish 5 "aborted(cost-budget)" "累積 cost \$${total_cost} が上限 \$${MAX_COST_USD} 到達"
  fi
done

_finish 2 "aborted(max-iter)" "max-iter ${MAX_ITER} 到達、gate は green にならず (cost \$${total_cost})"
