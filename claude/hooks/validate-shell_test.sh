#!/bin/bash
# Behavior tests for claude/hooks/validate-shell.sh (the PostToolUse shellcheck gate).
#
# Each case feeds the hook a PostToolUse stdin payload naming a fixture file
# under an isolated mktemp dir and asserts the exit code:
#   clean      — well-formed .sh file              → 0 (allow)
#   dirty      — .sh file with shellcheck findings → 2 (block, findings on stderr)
#                (SKIPPED when shellcheck is not on PATH — the hook's fail-open
#                 path then legitimately returns 0; covered by no-tool below)
#   non-sh     — a .txt file                       → 0 (not in scope)
#   missing    — path that does not exist          → 0 (nothing to check)
#   no-path    — payload without file_path         → 0 (nothing to check)
#   no-tool    — shellcheck unavailable on PATH    → 0 (warn-only fail-open)
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
HOOK="$(pwd)/claude/hooks/validate-shell.sh"

PASS=0
FAIL=0
SKIP=0
pass() {
    echo "  [pass] $1"
    PASS=$((PASS + 1))
}
fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}
# skip: an inapplicable case (a missing external tool), reported distinctly and
# NOT counted as a failure — mirrors scripts/verify.sh's SKIP discipline
# ("inapplicable checks → SKIP, never silently treated as pass/fail").
skip() {
    echo "  [skip] $1"
    SKIP=$((SKIP + 1))
}

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- fixtures -----------------------------------------------------------------
CLEAN="$TMP/clean.sh"
printf '%s\n' '#!/bin/bash' 'echo "ok"' > "$CLEAN"

DIRTY="$TMP/dirty.sh"
# shellcheck disable=SC2016  # literal $1 is the point: the fixture must trip SC2086
printf '%s\n' '#!/bin/bash' 'echo $1' > "$DIRTY"

NONSH="$TMP/notes.txt"
# shellcheck disable=SC2016  # same literal, in a non-.sh file the hook must skip
printf '%s\n' 'echo $1' > "$NONSH"

payload() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }

# --- clean: no findings --------------------------------------------------------
rc=$( "$HOOK" <<< "$(payload "$CLEAN")" > /dev/null 2>&1; echo $? )
if [[ "$rc" == "0" ]]; then
    pass "clean: well-formed .sh allows with exit 0"
else
    fail "clean: expected exit 0, got $rc"
fi

# --- dirty: shellcheck findings block ------------------------------------------
# This case needs shellcheck on PATH. When it is absent, validate-shell.sh
# legitimately takes its warn-only fail-open path (exit 0, "shellcheck is not
# installed"), so asserting exit 2 here would be a false FAIL — the exact bug
# #121 recorded from a shellcheck-less audit container. Guard with `command -v`
# and SKIP instead, matching scripts/verify.sh's check_shellcheck; the
# fail-open path stays covered unconditionally by the "no-tool" case below.
if ! command -v shellcheck &> /dev/null; then
    skip "dirty: shellcheck absent — fail-open path covered by no-tool case"
else
    # Single invocation: the substitution's $? is the hook's exit code.
    dirty_err=$( "$HOOK" <<< "$(payload "$DIRTY")" 2>&1 >/dev/null )
    rc=$?
    if [[ "$rc" == "2" ]]; then
        pass "dirty: shellcheck findings block with exit 2"
    else
        fail "dirty: expected exit 2, got $rc"
    fi
    if [[ "$dirty_err" == *"shellcheck found issues"* && "$dirty_err" == *"SC"* ]]; then
        pass "dirty: stderr carries the findings"
    else
        fail "dirty: stderr missing findings (got: ${dirty_err:-<empty>})"
    fi
fi

# --- non-sh: out of scope -------------------------------------------------------
rc=$( "$HOOK" <<< "$(payload "$NONSH")" > /dev/null 2>&1; echo $? )
if [[ "$rc" == "0" ]]; then
    pass "non-sh: .txt file allows with exit 0"
else
    fail "non-sh: expected exit 0, got $rc"
fi

# --- missing: nonexistent path ---------------------------------------------------
rc=$( "$HOOK" <<< "$(payload "$TMP/ghost.sh")" > /dev/null 2>&1; echo $? )
if [[ "$rc" == "0" ]]; then
    pass "missing: nonexistent file allows with exit 0"
else
    fail "missing: expected exit 0, got $rc"
fi

# --- no-path: payload without file_path -------------------------------------------
rc=$( "$HOOK" <<< '{"tool_name":"Write","tool_input":{}}' > /dev/null 2>&1; echo $? )
if [[ "$rc" == "0" ]]; then
    pass "no-path: missing file_path allows with exit 0"
else
    fail "no-path: expected exit 0, got $rc"
fi

# --- no-tool: shellcheck absent → warn-only ----------------------------------------
# Shim PATH with only the binaries the hook needs before the shellcheck lookup
# (cat + jq), so `command -v shellcheck` fails and the hook warns + exits 0.
NOSCBIN="$TMP/noscbin"
mkdir -p "$NOSCBIN"
ln -s "$(command -v cat)" "$NOSCBIN/cat"
ln -s "$(command -v jq)"  "$NOSCBIN/jq"
notool_out=$( PATH="$NOSCBIN" "$HOOK" <<< "$(payload "$DIRTY")" 2>&1 >/dev/null )
notool_rc=$?
if [[ "$notool_rc" == "0" && "$notool_out" == *"shellcheck is not installed"* ]]; then
    pass "no-tool: missing shellcheck warns and exits 0"
else
    fail "no-tool: expected warn + exit 0, got rc=$notool_rc (out: ${notool_out:-<empty>})"
fi

echo
echo "validate-shell: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]]
