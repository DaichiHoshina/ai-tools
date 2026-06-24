#!/usr/bin/env bash
# =============================================================================
# Canonical threshold definitions for ai-tools hooks.
# Edit here only. All hook / bats references must source this file.
# =============================================================================

# 多重 source 防止
if [[ "${_THRESHOLDS_LOADED:-}" == "1" ]]; then
    return 0
fi
_THRESHOLDS_LOADED=1

readonly _TH_PARALLEL_SEQ=2               # 並列 warn: sequential agent fire
readonly _TH_BUNDLE_HARD_BLOCK_SEQ=3      # bundle 違反 hard block: warn 後の更なる sequential fire (PO Gate v2 enforcement)
readonly _TH_DELEGATE_SEQ=3               # 委譲 warn: large-repo 連続 edit
readonly _TH_PARALLEL_WINDOW_NS=500000000 # 500ms 並列判定 window (nanosec)
readonly _TH_SESSION_AGE_S=10800          # 3h (sec) warn
readonly _TH_SESSION_AGE_URGENT_S=21600   # 6h (sec) urgent
readonly _TH_SESSION_MSG=150              # 150 msg (~75 opus turn)。実測 (2026-06-19): 278 msg で $41/session、149 msg で $46/session。中規模 session が cost driver
readonly _TH_SESSION_MSG_URGENT=350       # 350 msg (~175 opus turn)。実測: 300+ msg = $45+/session の帯
readonly _TH_TOKEN=3000000                # 3M token warn (cache_read 込み累積)。閾値引下げで sweet spot を逃さない
readonly _TH_TOKEN_URGENT=50000000        # 50M token urgent (top session は 2B 行く実測あり)
readonly _TH_IDLE_S=1800                  # 30 分 idle で /clear 提案 (cache 全持越し回避)
readonly _TH_TASK_COMPLETED_SEQ=2         # task 完了 warn
readonly _TH_STOP_MEMORY_FILES=3          # stop.sh memory-save 候補 file 数
readonly _TH_LOG_ROTATION_LINES=1000      # subagent-start.sh log rotation
readonly _TH_LOG_MAX_BYTES=1048576        # 1MB、log rotation 閾値
readonly _TH_BLOAT_THROTTLE_S=900         # 15 分、session bloat warn throttle
readonly _TH_BLOAT_THROTTLE_URGENT_S=300  # 5 分、urgent は throttle 短く
