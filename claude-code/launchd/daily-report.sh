#!/usr/bin/env bash

set -euo pipefail

WEBHOOK_FILE="$HOME/.claude/secrets/slack-webhook"
LOG_DIR="$HOME/.claude/logs/launchd"
JOBS=(sleep-review memory-clean retrospective)

declare -A JOB_LABEL_JA=(
    [sleep-review]="夜間 pipeline (sleep-review)"
    [memory-clean]="memory 掃除 (memory-clean)"
    [retrospective]="週次振り返り (retrospective)"
)

if [[ ! -f "$WEBHOOK_FILE" ]]; then
    echo "ERROR: webhook file が見つからない: $WEBHOOK_FILE" >&2
    exit 1
fi

WEBHOOK_URL="$(cat "$WEBHOOK_FILE" | tr -d '\n\r ')"

if [[ "$WEBHOOK_URL" == "PASTE_YOUR_SLACK_WEBHOOK_URL_HERE" || -z "$WEBHOOK_URL" ]]; then
    echo "ERROR: webhook URL が未設定。$WEBHOOK_FILE を編集する" >&2
    exit 1
fi

if [[ ! "$WEBHOOK_URL" =~ ^https://hooks\.slack\.com/ ]]; then
    echo "ERROR: slack webhook URL の形式ではない" >&2
    exit 1
fi

extract_summary() {
    local log_path="$1"
    if [[ ! -f "$log_path" || ! -s "$log_path" ]]; then
        echo "(log なし)"
        return
    fi
    python3 -c "
import sys
data = open('$log_path', 'rb').read(1600).decode('utf-8', errors='replace')
paras = data.split('\n\n', 2)
head = paras[0] if paras else data
if len(head) > 400:
    head = head[:400] + '…'
print(head)
"
}

now_str="$(date '+%Y-%m-%d %H:%M')"
lines=("*Claude 自動運用 daily report* — $now_str")
lines+=("")

for job in "${JOBS[@]}"; do
    label="com.claude.$job"
    log_path="$LOG_DIR/$job.log"
    err_path="$LOG_DIR/$job.err.log"
    ja_label="${JOB_LABEL_JA[$job]:-$job}"

    if launchctl list "$label" &>/dev/null; then
        status_line="$(launchctl list "$label" | grep -E '"(PID|LastExitStatus)" =' | tr -d '"' | tr '\n' ' ')"
        last_exit="$(echo "$status_line" | grep -oE 'LastExitStatus = -?[0-9]+' | awk '{print $NF}' || echo "?")"
        pid="$(echo "$status_line" | grep -oE 'PID = -?[0-9]+' | awk '{print $NF}' || echo "")"
    else
        last_exit="unloaded"
        pid=""
    fi

    if [[ -f "$log_path" ]]; then
        log_size=$(wc -c < "$log_path" | tr -d ' ')
        log_mtime=$(stat -f '%Sm' -t '%m-%d %H:%M' "$log_path" 2>/dev/null || echo "?")
    else
        log_size=0
        log_mtime="実行なし"
    fi

    err_size=0
    if [[ -f "$err_path" ]]; then
        err_size=$(wc -c < "$err_path" | tr -d ' ')
    fi

    if [[ -n "$pid" ]]; then
        icon=":arrows_counterclockwise:"
        state="実行中 (pid $pid)"
    elif [[ "$err_size" -gt 0 ]]; then
        icon=":rotating_light:"
        state="エラー発生 (err ${err_size}B)"
    elif [[ "$last_exit" == "0" ]]; then
        state="正常終了"
        icon=":white_check_mark:"
    elif [[ "$last_exit" == "?" ]]; then
        state="未実行 (前回 fire 情報なし)"
        icon=":hourglass:"
    else
        icon=":warning:"
        state="異常終了 (exit $last_exit)"
    fi

    lines+=("$icon *$ja_label* — $state")
    lines+=("  最終 log: ${log_size}B ($log_mtime)")

    summary="$(extract_summary "$log_path")"
    if [[ -n "$summary" && "$summary" != "(log なし)" ]]; then
        lines+=("\`\`\`${summary}\`\`\`")
    else
        lines+=("  (実行 log なし)")
    fi

    if [[ "$err_size" -gt 0 ]]; then
        err_summary="$(head -c 200 "$err_path" | tr '\n' ' ')"
        lines+=(":warning: err.log 抜粋: \`${err_summary}\`")
    fi

    lines+=("")
done

body=$(printf '%s\n' "${lines[@]}")

payload=$(cat <<EOF
{"text": $(printf '%s' "$body" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read()))')}
EOF
)

response=$(curl -sf -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" 2>&1) || {
    echo "ERROR: slack への送信に失敗: $response" >&2
    exit 1
}

echo "slack に送信した ($response)"

HEALTHCHECK_FILE="$HOME/.claude/secrets/healthchecks-url"
if [[ -f "$HEALTHCHECK_FILE" && -s "$HEALTHCHECK_FILE" ]]; then
    hc_url="$(cat "$HEALTHCHECK_FILE" | tr -d '\n\r ')"
    if [[ "$hc_url" =~ ^https://hc-ping\.com/ ]]; then
        curl -sf --max-time 10 "$hc_url" &>/dev/null && echo "healthchecks に ping 送信済" || echo "warn: healthchecks ping 失敗"
    fi
fi
