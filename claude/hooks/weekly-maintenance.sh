#!/bin/bash
# SessionStart hook (startup matcher): weekly local-maintenance sweep.
#
# Boris Cherny's adoption step 3 expects maintenance to "run continuously in
# the background", but this repo deliberately removed its launchd agent (an
# unattended loop once pushed a broken settings.json — see tasks/lessons.md
# 2026-06-19). This hook is the daemon-free compromise: the FIRST session of
# the week pays ~200ms to scan for local drift, every other session exits on
# the throttle marker instantly. Detection only — it reports into the session
# as context and never mutates anything (the auto-sync lesson again).
#
# Checks (both derived, nothing hardcoded):
#   1. broken symlinks pointing into the dotfiles repo (same derivation as
#      scripts/verify.sh check_symlinks, trimmed)
#   2. dotfiles repo drift: uncommitted files / commits not pushed upstream
#
# Output: stdout only when something needs attention (SessionStart stdout is
# injected as session context); silence when healthy. ALWAYS exit 0 — session
# start must never be blocked by a maintenance sweep (fail-open).

MARKER="$HOME/.claude/cache/weekly-maintenance.last"
WEEK_SECONDS=$((7 * 24 * 3600))

now=$(date +%s)
if [[ -f "$MARKER" ]]; then
    last=$(cat "$MARKER" 2>/dev/null)
    [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < WEEK_SECONDS )) && exit 0
fi

# Resolve the dotfiles repo through the settings.json symlink; a non-symlink
# means dotfiles are not installed on this machine → nothing to maintain.
[[ -L "$HOME/.claude/settings.json" ]] || exit 0
target=$(readlink "$HOME/.claude/settings.json") || exit 0
DOTFILES_DIR=$(cd "$(dirname "$target")/.." 2>/dev/null && pwd) || exit 0
[[ -d "$DOTFILES_DIR/.git" ]] || exit 0

issues=""

# 1. Broken symlinks pointing into the repo (bounded scan, never ~/Library).
broken=""
while IFS= read -r link; do
    [[ -n "$link" ]] || continue
    case "$(readlink "$link")" in
        "$DOTFILES_DIR"/*) [[ -e "$link" ]] || broken="$broken $link" ;;
    esac
done <<< "$( {
    find "$HOME" -maxdepth 1 -type l
    [[ -d "$HOME/.config" ]] && find "$HOME/.config" -type l
    [[ -d "$HOME/.claude" ]] && find "$HOME/.claude" -type l
} 2>/dev/null )"
[[ -n "$broken" ]] && issues="${issues}- broken symlinks:${broken}\n"

# 2. Repo drift: uncommitted files and unpushed commits (upstream optional).
uncommitted=$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
[[ "$uncommitted" =~ ^[0-9]+$ ]] || uncommitted=0
unpushed=$(git -C "$DOTFILES_DIR" rev-list '@{u}..HEAD' --count 2>/dev/null)
[[ "$unpushed" =~ ^[0-9]+$ ]] || unpushed=0
if (( uncommitted > 0 || unpushed > 0 )); then
    branch=$(git -C "$DOTFILES_DIR" branch --show-current 2>/dev/null)
    issues="${issues}- dotfiles drift (${branch:-?}): ${uncommitted} uncommitted file(s), ${unpushed} unpushed commit(s)\n"
fi

# Stamp the marker after a completed sweep (weekly cadence either way).
mkdir -p "$(dirname "$MARKER")" 2>/dev/null
printf '%s' "$now" > "$MARKER" 2>/dev/null

if [[ -n "$issues" ]]; then
    printf '[weekly-maintenance] dotfiles repo needs attention (%s):\n' "$DOTFILES_DIR"
    printf '%b' "$issues"
    printf 'Suggested: run /health-check, then ./scripts/auto-sync.sh (or commit deliberately). Detection only — nothing was changed.\n'
fi

exit 0
