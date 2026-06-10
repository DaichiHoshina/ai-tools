#!/usr/bin/env bash
# =============================================================================
# Canonical threshold definitions for ai-tools hooks.
# Edit here only. All hook / bats references must source this file.
# =============================================================================

readonly _TH_PARALLEL_SEQ=2               # 並列 warn: sequential agent fire
readonly _TH_DELEGATE_SEQ=3               # 委譲 warn: large-repo 連続 edit
readonly _TH_PARALLEL_WINDOW_NS=500000000 # 500ms 並列判定 window (nanosec)
readonly _TH_SESSION_AGE_S=10800          # 3h (sec)
readonly _TH_SESSION_MSG=1000             # 1000 msg
readonly _TH_TOKEN=500000                 # 500K token
readonly _TH_TASK_COMPLETED_SEQ=2         # task 完了 warn
readonly _TH_STOP_MEMORY_FILES=3          # stop.sh memory-save 候補 file 数
readonly _TH_LOG_ROTATION_LINES=1000      # subagent-start.sh log rotation
