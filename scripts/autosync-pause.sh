#!/bin/bash
# Pause dotfiles auto-sync for N minutes by writing an auto-expiring lock that
# auto-sync.sh checks before running. Use during PR creation or manual edits on
# main so the hourly daemon doesn't commit your changes directly to main and
# leave no diff to PR (the gh pr create guard blocks the empty PR after the fact;
# this prevents the race in the first place).
#
#   scripts/autosync-pause.sh [minutes]   # pause (default 30)
#   scripts/autosync-pause.sh resume      # clear the lock now
#   scripts/autosync-pause.sh status      # show remaining time
#
# The lock auto-expires so a forgotten pause can never silently disable sync.

set -euo pipefail

PAUSE_LOCK="$HOME/.cache/dotfiles-autosync.pause"
mkdir -p "$(dirname "$PAUSE_LOCK")"

case "${1:-}" in
    resume | off | clear)
        rm -f "$PAUSE_LOCK"
        echo "auto-sync resumed"
        exit 0
        ;;
    status)
        if [ -f "$PAUSE_LOCK" ]; then
            expiry=$(cat "$PAUSE_LOCK" 2>/dev/null || echo 0)
            now=$(date +%s)
            if [[ "$expiry" =~ ^[0-9]+$ ]] && [ "$now" -lt "$expiry" ]; then
                echo "auto-sync paused until $(date -r "$expiry" '+%H:%M:%S') ($(( (expiry - now) / 60 ))m left)"
            else
                echo "auto-sync active (lock expired)"
            fi
        else
            echo "auto-sync active (no lock)"
        fi
        exit 0
        ;;
esac

minutes="${1:-30}"
if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
    echo "usage: $0 [minutes|resume|status]" >&2
    exit 1
fi

expiry=$(( $(date +%s) + minutes * 60 ))
echo "$expiry" > "$PAUSE_LOCK"
echo "auto-sync paused for ${minutes}m (until $(date -r "$expiry" '+%H:%M:%S'))"
