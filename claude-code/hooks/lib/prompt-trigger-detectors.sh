#!/usr/bin/env bash
# trigger 判定系 (外向き文書 / 委譲 / NG語 pre-sweep trigger) - user-prompt-submit.sh から抽出
# 多重 source 防止
if [[ "${_PROMPT_TRIGGER_DETECTORS_LOADED:-}" == "1" ]]; then
    return 0
fi
_PROMPT_TRIGGER_DETECTORS_LOADED=1

# === 外向き執筆 trigger 語彙 (single source of truth) ===
# _OUTWARD_SHARE_TRIGGERS: 共有/報告 phrase subset。chat 応答にも外向き規範を適用する trigger。
# _OUTWARD_EXTRA_TRIGGERS: 文書種別 + 動作動詞 (外向き文書 trigger の残り部分、subset の superset を構成)。
# 論理: _is_outward_writing_trigger = SHARE ∪ EXTRA、_inject_outward_mode_if_trigger = SHARE。
readonly _OUTWARD_SHARE_TRIGGERS=(
  "共有用" "報告用" "共有して" "報告して" "共有文" "報告文"
  "共有テキスト" "報告書" "共有する文" "報告する内容"
)
readonly _OUTWARD_EXTRA_TRIGGERS=(
  "プルリク" "commit" "コミット" "push" "issue" "slack" "notion"
  "design doc" "デザインドック" "設計書" "prd" "rca" "障害報告" "ポストモーテム" "postmortem"
  "/git-push" "/commit" "/post-comment" "/design-doc" "/prd" "/docs"
  "ドラフト" "下書き"
)

# === 共有/報告系 trigger → outward-mode inject ===
# user 入力に共有/報告系 phrase が含まれる場合、chat 応答にも外向き規範を適用するよう inject
_inject_outward_mode_if_trigger() {
  local prompt="$1"
  local t
  for t in "${_OUTWARD_SHARE_TRIGGERS[@]}"; do
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
    read -r _LAST_TS < "${_FLAG}" 2>/dev/null || _LAST_TS=""
    # flag は存在するが TS が空 / 非数値 / 0 = 直前 write が壊れた / 競合 → throttle 継続
    if [[ ! "${_LAST_TS}" =~ ^[0-9]+$ ]] || (( _LAST_TS == 0 )); then
      return 1
    fi
    printf -v _NOW '%(%s)T' -1
    _SINCE=$(( _NOW - _LAST_TS ))
    if (( _SINCE >= 0 && _SINCE < 300 )); then
      return 1
    fi
  fi

  # flag 更新
  printf -v _NOW '%(%s)T' -1
  printf '%s\n' "${_NOW}" > "${_FLAG}" 2>/dev/null || true

  printf '%s\n' "[delegation-checklist] developer-agent 委譲意図検出。発火前に §0 checklist 7 項目を満たすこと: (1) target file:line 特定済 (2) verify cmd bash literal 確定 (3) DoD 1 行化 (4) 単 domain (5) touchable_files: YAML block を delegation prompt §1 に literal 記載 (6) blocker-on-stop 方針記載 (7) Self-Review Gate 明示。touchable_files 欠落で発火 = subagent 側 partial 停止。Return 時は §0.5 B fact-check (数値 formula 確認 / 測定値 1 sample 再現 / file 変更 git diff --stat) を最低 1 つ実行。source: references/developer-agent-delegation-prompt.md §0, §0.5, §1"
  return 0
}

# === 外向き text trigger → NG top-N term inject ===
# commit / PR / Notion / Slack 等の外向き text 生成前に block top-N term を注入して retry loop を事前回避する
# 派生値禁止 rule 準拠: top-N は log から動的抽出 (literal 埋め込み禁止)
_inject_commit_ng_top6_if_trigger() {
  local prompt="$1"
  local prompt_lower="${prompt,,}"
  # commit/PR 系 + Notion/Slack 等の外向き投稿系 (2026-06-24: NG block 30+ 件/日対応で拡大)
  local triggers=(
    "push" "pushして" "commit" "/git-push" "/commit" "pr 作" "pr を作" "プルリク"
    "notion" "slack" "投稿" "送って" "送信" "share" "シェア" "/post-comment"
  )
  local hit=0
  local t
  for t in "${triggers[@]}"; do
    if [[ "${prompt_lower}" == *"${t,,}"* ]]; then hit=1; break; fi
  done
  (( hit )) || return 1

  # throttle: 同一 session で 300 秒以内の再 inject を抑制する (delegation checklist と同 pattern)。
  # inject は会話 history に残り以降の全 turn で再送されるため、dedup なしだと 1 日 100 回超の重複が発生した (2026-07-03 実測 117 回)。
  local _NG_FLAG="/tmp/claude-ng-topn-${_SESSION_ID:-$$}-${_DATE_TODAY:-0}"
  if [[ -f "${_NG_FLAG}" ]]; then
    local _NG_LAST _NG_NOW _NG_SINCE
    read -r _NG_LAST < "${_NG_FLAG}" 2>/dev/null || _NG_LAST=""
    if [[ ! "${_NG_LAST}" =~ ^[0-9]+$ ]] || (( _NG_LAST == 0 )); then
      return 1
    fi
    printf -v _NG_NOW '%(%s)T' -1
    _NG_SINCE=$(( _NG_NOW - _NG_LAST ))
    if (( _NG_SINCE >= 0 && _NG_SINCE < 300 )); then
      return 1
    fi
  fi
  local _NG_NOW_TS
  printf -v _NG_NOW_TS '%(%s)T' -1
  printf '%s\n' "${_NG_NOW_TS}" > "${_NG_FLAG}" 2>/dev/null || true

  local _LOG="${HOME}/.claude/logs/jp-quality-block.log"
  [[ -f "${_LOG}" ]] || return 1

  # ISO8601 timestamp は辞書順 = 時系列順。bash 側で cutoff 文字列を 1 回生成し、
  # awk 内で文字列比較するだけにして date fork を完全に排除する。
  local _NOW _CUTOFF_STR
  printf -v _NOW '%(%s)T' -1
  printf -v _CUTOFF_STR '%(%Y-%m-%dT%H:%M:%S)T' "$(( _NOW - 604800 ))"

  # top-N (拡大: 6 → 12) で日々の block 多様性をカバー
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
    }' "${_LOG}" 2>/dev/null | sort -rn | head -12 | awk '{$1=""; sub(/^ /,""); print}' | paste -sd "," -)

  [[ -n "${_TOP}" ]] || return 1
  printf '%s\n' "[outward-text-ng-pre-sweep] 外向き text (commit/PR/Notion/Slack 等) trigger 検出。直近7日 block top-12: ${_TOP}。draft 生成前に必ず self-check + 回避。代替例: 鑑みる→踏まえる / 踏襲→引き継ぐ / 喫緊→直近 / leverage→使う / utilize→活かす / mitigate→緩和する。source: ~/.claude/logs/jp-quality-block.log"

  # inject 効果計測用 log (誰 trigger / どの hit term / top-N)
  local _SWEEP_LOG="${HOME}/.claude/logs/ng-pre-sweep-inject.log"
  local _TS_INJ
  printf -v _TS_INJ '%(%Y-%m-%dT%H:%M:%S)T' -1
  printf '%s | user-prompt | trigger=%s | top12=%s\n' "$_TS_INJ" "${t}" "${_TOP}" \
    >> "$_SWEEP_LOG" 2>/dev/null || true
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
  # trigger 語彙は file 冒頭の SHARE ∪ EXTRA を union で走査 (single source of truth)。
  local t
  for t in "${_OUTWARD_SHARE_TRIGGERS[@]}" "${_OUTWARD_EXTRA_TRIGGERS[@]}"; do
    if [[ "${prompt_lower}" == *"${t,,}"* ]]; then return 0; fi
  done
  # "pr" は語境界 (前後が非英数字 or 行頭行末) のときのみ hit
  if [[ "${prompt_lower}" =~ (^|[^a-z0-9])pr([^a-z0-9]|$) ]]; then return 0; fi
  return 1
}
