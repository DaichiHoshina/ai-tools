#!/usr/bin/env bash

set -euo pipefail

WEBHOOK_FILE="$HOME/.claude/secrets/slack-webhook"
LOG_DIR="$HOME/.claude/logs/launchd"
JOBS=(sleep-review memory-clean retrospective)

if [[ ! -f "$WEBHOOK_FILE" ]]; then
    echo "ERROR: webhook file not found: $WEBHOOK_FILE" >&2
    exit 1
fi

WEBHOOK_URL="$(cat "$WEBHOOK_FILE" | tr -d '\n\r ')"

if [[ "$WEBHOOK_URL" == "PASTE_YOUR_SLACK_WEBHOOK_URL_HERE" || -z "$WEBHOOK_URL" ]]; then
    echo "ERROR: webhook URL not configured. edit $WEBHOOK_FILE" >&2
    exit 1
fi

if [[ ! "$WEBHOOK_URL" =~ ^https://hooks\.slack\.com/ ]]; then
    echo "ERROR: not a valid slack webhook URL" >&2
    exit 1
fi

now_str="$(date '+%Y-%m-%d %H:%M')"
lines=("*Claude LaunchAgent daily report* — $now_str")

for job in "${JOBS[@]}"; do
    label="com.claude.$job"
    log_path="$LOG_DIR/$job.log"
    err_path="$LOG_DIR/$job.err.log"

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
        log_mtime="never"
    fi

    err_size=0
    if [[ -f "$err_path" ]]; then
        err_size=$(wc -c < "$err_path" | tr -d ' ')
    fi

    if [[ -n "$pid" ]]; then
        icon=":arrows_counterclockwise:"
        state="running (pid $pid)"
    elif [[ "$err_size" -gt 0 ]]; then
        icon=":rotating_light:"
        state="ERR ${err_size}B"
    elif [[ "$last_exit" == "0" || "$last_exit" == "?" ]]; then
        icon=":white_check_mark:"
        state="ok (exit $last_exit)"
    else
        icon=":warning:"
        state="exit $last_exit"
    fi

    lines+=("$icon *$job* — $state · log ${log_size}B ($log_mtime)")
done

body=$(printf '%s\n' "${lines[@]}")

payload=$(cat <<EOF
{"text": $(printf '%s' "$body" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read()))')}
EOF
)

response=$(curl -sf -X POST -H "Content-Type: application/json" -d "$payload" "$WEBHOOK_URL" 2>&1) || {
    echo "ERROR: slack POST failed: $response" >&2
    exit 1
}

echo "sent to slack ($response)"
