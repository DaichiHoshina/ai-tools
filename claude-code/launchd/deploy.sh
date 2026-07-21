#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/.claude/logs/launchd"

JOBS=(sleep-review memory-clean retrospective daily-report night-caffeinate)

usage() {
    cat <<'EOF'
usage: deploy.sh {install|uninstall|test|status} [<job>|all]

  install <job|all>    plist を ~/Library/LaunchAgents/ に置いて load する
  uninstall <job|all>  unload して plist を削除する
  test <job>           即時 1 回だけ発火する (launchctl kickstart)
  status               現在の load 状況と log を表示する

  jobs: sleep-review / memory-clean / retrospective / daily-report / night-caffeinate

  night-caffeinate は pmset の自動 wake とセットで使う (要 1 回だけ sudo):
    sudo pmset repeat wakeorpoweron MTWRFSU 01:58:00
EOF
}

plist_src() { echo "$SCRIPT_DIR/com.claude.$1.plist"; }
plist_dst() { echo "$LAUNCH_AGENTS_DIR/com.claude.$1.plist"; }
label() { echo "com.claude.$1"; }

ensure_dirs() {
    mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"
}

install_job() {
    local job="$1"
    local src dst
    src="$(plist_src "$job")"
    dst="$(plist_dst "$job")"

    if [[ ! -f "$src" ]]; then
        echo "ERROR: plist not found: $src" >&2
        return 1
    fi

    ensure_dirs

    if [[ -f "$dst" ]]; then
        echo "→ unload existing: $(label "$job")"
        launchctl unload "$dst" 2>/dev/null || true
    fi

    echo "→ copy plist: $src → $dst"
    cp "$src" "$dst"

    echo "→ load: $(label "$job")"
    launchctl load "$dst"

    echo "✓ installed: $(label "$job")"
}

uninstall_job() {
    local job="$1"
    local dst
    dst="$(plist_dst "$job")"

    if [[ ! -f "$dst" ]]; then
        echo "skip (not installed): $(label "$job")"
        return 0
    fi

    echo "→ unload: $(label "$job")"
    launchctl unload "$dst" 2>/dev/null || true

    echo "→ remove: $dst"
    rm -f "$dst"

    echo "✓ uninstalled: $(label "$job")"
}

test_job() {
    local job="$1"
    local uid
    uid="$(id -u)"
    echo "→ kickstart: gui/$uid/$(label "$job")"
    launchctl kickstart -k "gui/$uid/$(label "$job")"
    echo "✓ triggered. tail log:"
    echo "  tail -f $LOG_DIR/$job.log $LOG_DIR/$job.err.log"
}

status() {
    echo "== Installed LaunchAgents =="
    for job in "${JOBS[@]}"; do
        local dst
        dst="$(plist_dst "$job")"
        if [[ -f "$dst" ]]; then
            local loaded
            loaded="$(launchctl list | grep -c "$(label "$job")" || true)"
            if [[ "$loaded" -gt 0 ]]; then
                echo "  ✓ $(label "$job") (loaded)"
            else
                echo "  △ $(label "$job") (plist ある / unload 状態)"
            fi
        else
            echo "  ✗ $(label "$job") (未 install)"
        fi
    done

    echo
    echo "== Log files =="
    if [[ -d "$LOG_DIR" ]]; then
        ls -lh "$LOG_DIR" 2>/dev/null || echo "  (empty)"
    else
        echo "  (log dir not created yet: $LOG_DIR)"
    fi
}

resolve_targets() {
    if [[ "$1" == "all" ]]; then
        printf '%s\n' "${JOBS[@]}"
    else
        printf '%s\n' "$1"
    fi
}

cmd="${1:-status}"
case "$cmd" in
    install)
        target="${2:?usage: deploy.sh install <job|all>}"
        while IFS= read -r job; do install_job "$job"; done < <(resolve_targets "$target")
        ;;
    uninstall)
        target="${2:?usage: deploy.sh uninstall <job|all>}"
        while IFS= read -r job; do uninstall_job "$job"; done < <(resolve_targets "$target")
        ;;
    test)
        target="${2:?usage: deploy.sh test <job>}"
        test_job "$target"
        ;;
    status)
        status
        ;;
    *)
        usage
        exit 1
        ;;
esac
