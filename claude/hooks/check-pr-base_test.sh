#!/bin/bash
# Behavior tests for claude/hooks/check-pr-base.sh (the PreToolUse PR-base guard).
#
# Each case builds a throwaway git fixture (a local bare repo as `origin`) under
# an isolated mktemp dir OUTSIDE this repository, feeds the hook a PreToolUse
# stdin payload, and asserts the exit code:
#   red        — HEAD behind origin/main            → 2 (block)
#   red-flags  — `gh -R <repo> pr create`, stale     → 2 (block; flags between gh/pr)
#   compose    — self-syncing /eng:create-pr block   → 0 (allow; block syncs itself)
#   data       — `gh pr create` as quoted data       → 0 (allow; not an invocation)
#   green      — HEAD in sync with origin/main       → 0 (allow)
#   skip       — command is not `gh pr create`       → 0 (allow, pre-filter)
#   non-git    — cwd is not a git repo               → 0 (fail-open)
#   no-origin  — git repo without an origin remote   → 0 (fail-open)
#   no-jq      — jq unavailable on PATH              → 0 (fail-open)
#
# GIT_CEILING_DIRECTORIES pins git's upward search to the fixture root so the
# "non-git" case cannot accidentally discover a real repo above the temp dir.
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail   # no -e: cases are aggregated, a blocking exit 2 must not abort

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
DOTFILES_DIR="$(pwd)"
HOOK="$DOTFILES_DIR/claude/hooks/check-pr-base.sh"

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

# A gh-pr-create PreToolUse payload, and a non-matching one.
PR_JSON='{"tool_name":"Bash","tool_input":{"command":"gh pr create --fill"}}'
NON_JSON='{"tool_name":"Bash","tool_input":{"command":"git status"}}'

# Isolated fixture root outside the repo; git never searches above it.
TMP="$(mktemp -d)"
export GIT_CEILING_DIRECTORIES="$TMP"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

git_id() { git config user.email test@example.com && git config user.name "PR Base Test"; }

# --- Shared origin seeded with one commit on main -------------------------
ORIGIN="$TMP/origin.git"
SEED="$TMP/seed"
git init --bare -b main "$ORIGIN" > /dev/null 2>&1
git clone "$ORIGIN" "$SEED" > /dev/null 2>&1
(
    cd "$SEED" || exit 1
    git_id
    echo one > file.txt
    git add file.txt
    git commit -m "one" > /dev/null 2>&1
    git push origin main > /dev/null 2>&1
)

# --- red: work clone left behind after origin advances --------------------
WORK="$TMP/work"
git clone "$ORIGIN" "$WORK" > /dev/null 2>&1
( cd "$WORK" && git_id )
# Advance origin/main beyond what WORK has.
(
    cd "$SEED" || exit 1
    echo two >> file.txt
    git commit -am "two" > /dev/null 2>&1
    git push origin main > /dev/null 2>&1
)
red_err="$( cd "$WORK" && echo "$PR_JSON" | "$HOOK" 2>&1 >/dev/null )"
red_rc=$( cd "$WORK" && echo "$PR_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$red_rc" == "2" ]]; then
    pass "red: stale base blocks with exit 2"
else
    fail "red: expected exit 2, got $red_rc"
fi
if [[ "$red_err" == *"Base branch is stale"* && "$red_err" == *"/eng:create-pr"* ]]; then
    pass "red: stderr names the stale base and /eng:create-pr"
else
    fail "red: stderr missing expected message (got: ${red_err:-<empty>})"
fi

# --- red-flags: `gh -R owner/repo pr create` (flags between gh and pr) -----
# The guard must catch flag-bearing invocations, not only the bare form.
RFLAG_JSON='{"tool_name":"Bash","tool_input":{"command":"gh -R snkrheadz/laptop pr create --fill"}}'
rflag_rc=$( cd "$WORK" && echo "$RFLAG_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$rflag_rc" == "2" ]]; then
    pass "red: gh -R <repo> pr create on stale base blocks with exit 2"
else
    fail "red: gh -R form expected exit 2, got $rflag_rc"
fi

# --- compose: the /eng:create-pr single-block flow on a STALE base ---------
# The skill runs fetch→merge→push→create as ONE Bash block; PreToolUse sees the
# pre-merge HEAD, so the sync steps inside the same command must grant passage
# (the block establishes the invariant itself). This is the deadlock guard.
FLOW_JSON=$(python3 - <<'PYEOF'
import json
flow = '''set -euo pipefail
base=main
cur=$(git rev-parse --abbrev-ref HEAD)
git fetch origin "$base"
git merge --no-edit "origin/$base"
git push --set-upstream origin "$cur"
gh pr create --base "$base" --fill'''
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": flow}}))
PYEOF
)
flow_rc=$( cd "$WORK" && echo "$FLOW_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$flow_rc" == "0" ]]; then
    pass "compose: self-syncing /eng:create-pr block allows with exit 0 even when stale"
else
    fail "compose: self-syncing block expected exit 0, got $flow_rc"
fi

# --- data: `gh pr create` as quoted data must never block ------------------
DATA_JSON='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"docs: explain the gh pr create workflow\""}}'
data_rc=$( cd "$WORK" && echo "$DATA_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$data_rc" == "0" ]]; then
    pass "data: quoted mention of gh pr create allows with exit 0"
else
    fail "data: quoted mention expected exit 0, got $data_rc"
fi

# --- green: fresh clone in sync with origin/main --------------------------
FRESH="$TMP/fresh"
git clone "$ORIGIN" "$FRESH" > /dev/null 2>&1
( cd "$FRESH" && git_id )
green_rc=$( cd "$FRESH" && echo "$PR_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$green_rc" == "0" ]]; then
    pass "green: synced base allows with exit 0"
else
    fail "green: expected exit 0, got $green_rc"
fi

# --- skip: command is not gh pr create ------------------------------------
skip_rc=$( cd "$WORK" && echo "$NON_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$skip_rc" == "0" ]]; then
    pass "skip: non-matching command allows with exit 0"
else
    fail "skip: expected exit 0, got $skip_rc"
fi

# --- fail-open: not a git repo --------------------------------------------
NONGIT="$TMP/nongit"
mkdir -p "$NONGIT"
nongit_rc=$( cd "$NONGIT" && echo "$PR_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$nongit_rc" == "0" ]]; then
    pass "fail-open: non-git repo allows with exit 0"
else
    fail "fail-open: non-git expected exit 0, got $nongit_rc"
fi

# --- fail-open: git repo with no origin remote ----------------------------
NOORIGIN="$TMP/noorigin"
git init -b main "$NOORIGIN" > /dev/null 2>&1
(
    cd "$NOORIGIN" || exit 1
    git_id
    echo x > f.txt
    git add f.txt
    git commit -m "x" > /dev/null 2>&1
)
noorigin_rc=$( cd "$NOORIGIN" && echo "$PR_JSON" | "$HOOK" > /dev/null 2>&1; echo $? )
if [[ "$noorigin_rc" == "0" ]]; then
    pass "fail-open: no origin remote allows with exit 0"
else
    fail "fail-open: no-origin expected exit 0, got $noorigin_rc"
fi

# --- fail-open: jq unavailable on PATH ------------------------------------
# Restrict PATH to a dir holding only `cat` (needed to read stdin) so the hook
# reaches the jq check, finds nothing, and bails out before any git work.
NOJQBIN="$TMP/nojqbin"
mkdir -p "$NOJQBIN"
ln -s "$(command -v cat)" "$NOJQBIN/cat"
nojq_rc=$( cd "$NONGIT" && PATH="$NOJQBIN" "$HOOK" <<< "$PR_JSON" > /dev/null 2>&1; echo $? )
if [[ "$nojq_rc" == "0" ]]; then
    pass "fail-open: missing jq allows with exit 0"
else
    fail "fail-open: no-jq expected exit 0, got $nojq_rc"
fi

echo
echo "check-pr-base: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
