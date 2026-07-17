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

now=$(date +%s)   # one unavoidable fork (bash 3.2 has no %(%s)T / EPOCHSECONDS)
if [[ -f "$MARKER" ]]; then
    # read exits non-zero at EOF-without-newline but still fills $last — do
    # NOT reset it on that "failure" (the marker is written without a newline).
    last=""
    IFS= read -r last < "$MARKER" 2>/dev/null || :
    [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < WEEK_SECONDS )) && exit 0
fi

# Resolve the dotfiles repo through any of the installed symlinks. Probing a
# LIST matters: the harness itself rewrites settings.json (config changes are
# atomic write+rename, which turns the symlink into a real file), and a single
# probe would then silently disable this hook forever. No probe is a symlink →
# dotfiles are not installed on this machine → nothing to maintain.
target=""
for probe in settings.json CLAUDE.md loop.md statusline.sh; do
    if [[ -L "$HOME/.claude/$probe" ]]; then
        target=$(readlink "$HOME/.claude/$probe") && break
        target=""
    fi
done
[[ -n "$target" ]] || exit 0
DOTFILES_DIR=$(cd "$(dirname "$target")/.." 2>/dev/null && pwd) || exit 0
[[ -d "$DOTFILES_DIR/.git" ]] || exit 0

issues=""

# 1. Broken symlinks pointing into the repo. Depth-bounded everywhere: this
#    runs at session START, and an unbounded find under ~/.claude walks the
#    entire plugins tree (~29k entries measured) — install.sh only ever links
#    at depth ≤2 under these roots (e.g. .config/ghostty/config, .claude/hooks/x).
broken=()
while IFS= read -r link; do
    [[ -n "$link" ]] || continue
    case "$(readlink "$link")" in
        "$DOTFILES_DIR"/*) [[ -e "$link" ]] || broken+=("$link") ;;
    esac
done <<< "$( {
    find "$HOME" -maxdepth 1 -type l
    [[ -d "$HOME/.config" ]] && find "$HOME/.config" -maxdepth 2 -type l
    [[ -d "$HOME/.claude" ]] && find "$HOME/.claude" -maxdepth 2 -type l
} 2>/dev/null )"
[[ ${#broken[@]} -gt 0 ]] && issues="${issues}- broken symlinks: ${broken[*]}\n"

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
