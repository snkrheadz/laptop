#!/bin/bash
# Behavior tests for claude/hooks/weekly-maintenance.sh (the SessionStart sweep).
#
# Each case runs the hook under an isolated fixture HOME holding a throwaway
# "dotfiles repo" wired up exactly like install.sh does it (settings.json
# symlinked from ~/.claude/), and asserts exit code + stdout:
#   drift      — uncommitted file in the repo      → report on stdout, exit 0
#   broken     — dangling symlink into the repo    → report on stdout, exit 0
#   throttle   — second run inside the same week   → silent, exit 0
#   healthy    — clean repo, marker expired        → silent, marker refreshed
#   uninstalled— no settings.json symlink          → silent, exit 0 (fail-open)
#
# The hook must NEVER write anything into the fixture repo (detection only);
# the healthy case asserts the tree stays clean after a sweep.
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
HOOK="$(pwd)/claude/hooks/weekly-maintenance.sh"

PASS=0
FAIL=0
pass() {
    echo "  [pass] $1"
    PASS=$((PASS + 1))
}
fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

TMP="$(mktemp -d)"
export GIT_CEILING_DIRECTORIES="$TMP"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- fixture: a fake dotfiles repo installed into a fake HOME -----------------
FAKE_HOME="$TMP/home"
REPO="$TMP/dotfiles"
mkdir -p "$FAKE_HOME/.claude" "$REPO/claude"
(
    cd "$REPO" || exit 1
    git init -b main . > /dev/null 2>&1
    git config user.email test@example.com
    git config user.name "Weekly Test"
    echo '{}' > claude/settings.json
    git add -A
    git commit -m seed > /dev/null 2>&1
)
ln -s "$REPO/claude/settings.json" "$FAKE_HOME/.claude/settings.json"

MARKER="$FAKE_HOME/.claude/cache/weekly-maintenance.last"

run_hook() { HOME="$FAKE_HOME" "$HOOK" 2>/dev/null; }

# --- drift: uncommitted file is reported --------------------------------------
echo dirty > "$REPO/untracked.txt"
out=$(run_hook); rc=$?
if [[ $rc -eq 0 && "$out" == *"uncommitted file(s)"* && "$out" == *"nothing was changed"* ]]; then
    pass "drift: uncommitted file is reported, exit 0"
else
    fail "drift: expected drift report (rc=$rc, out: ${out:-<empty>})"
fi
if [[ -f "$MARKER" ]]; then
    pass "drift: marker stamped after the sweep"
else
    fail "drift: marker not written"
fi
rm -f "$REPO/untracked.txt"

# --- throttle: second run inside the week stays silent -------------------------
echo dirty-again > "$REPO/untracked.txt"
out=$(run_hook); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "throttle: run inside the week is silent even with drift present"
else
    fail "throttle: expected silence (rc=$rc, out: ${out:-<empty>})"
fi
rm -f "$REPO/untracked.txt"

# --- broken: dangling symlink into the repo is reported ------------------------
printf '%s' "$(( $(date +%s) - 8 * 24 * 3600 ))" > "$MARKER"   # expire the marker
ln -s "$REPO/claude/gone.sh" "$FAKE_HOME/dead-link"
out=$(run_hook); rc=$?
if [[ $rc -eq 0 && "$out" == *"broken symlinks"* && "$out" == *"dead-link"* ]]; then
    pass "broken: dangling symlink is reported, exit 0"
else
    fail "broken: expected symlink report (rc=$rc, out: ${out:-<empty>})"
fi
rm -f "$FAKE_HOME/dead-link"

# --- healthy: clean tree, expired marker → silent + marker refreshed -----------
printf '%s' "$(( $(date +%s) - 8 * 24 * 3600 ))" > "$MARKER"
before_status=$(git -C "$REPO" status --porcelain)
out=$(run_hook); rc=$?
after_status=$(git -C "$REPO" status --porcelain)
new_marker=$(cat "$MARKER" 2>/dev/null)
if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "healthy: clean tree stays silent"
else
    fail "healthy: expected silence (rc=$rc, out: ${out:-<empty>})"
fi
if (( new_marker > $(date +%s) - 60 )); then
    pass "healthy: marker refreshed to now"
else
    fail "healthy: marker not refreshed (got: ${new_marker:-<empty>})"
fi
if [[ "$before_status" == "$after_status" ]]; then
    pass "healthy: sweep changed nothing in the repo (detection only)"
else
    fail "healthy: sweep mutated the repo tree"
fi

# --- uninstalled: settings.json is a real file, not a symlink ------------------
BARE_HOME="$TMP/bare-home"
mkdir -p "$BARE_HOME/.claude"
echo '{}' > "$BARE_HOME/.claude/settings.json"
out=$(HOME="$BARE_HOME" "$HOOK" 2>/dev/null); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "uninstalled: non-symlink settings.json is silent, exit 0"
else
    fail "uninstalled: expected silence (rc=$rc, out: ${out:-<empty>})"
fi

echo
echo "weekly-maintenance: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
