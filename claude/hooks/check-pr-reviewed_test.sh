#!/bin/bash
# Behavior tests for claude/hooks/check-pr-reviewed.sh (the PreToolUse review gate).
#
# Each case feeds the hook a PreToolUse stdin payload pointing at a throwaway
# transcript fixture under an isolated mktemp dir, and asserts the exit code:
#   red          — pr create, transcript has no review evidence → 2 (block)
#   green-report — transcript contains a ReportFindings tool call → 0 (allow)
#   green-skill  — transcript contains a code-review skill call   → 0 (allow)
#   green-sec    — transcript contains security-review skill call → 0 (allow)
#   green-attrib — transcript contains an attributionSkill stamp  → 0 (allow)
#   green-binary — evidence embedded among invalid-UTF8/NUL bytes → 0 (allow)
#   green-subagent — evidence only in sidecar subagent transcript → 0 (allow)
#   bypass       — CLAUDE_SKIP_REVIEW=1 in the environment        → 0 (allow)
#   data         — `gh pr create` as quoted data                  → 0 (allow)
#   skip         — command is not `gh pr create`                  → 0 (allow, pre-filter)
#   no-path      — payload has no transcript_path                 → 0 (fail-open)
#   no-file      — transcript_path points at a missing file       → 0 (fail-open)
#   no-jq        — jq unavailable on PATH                         → 0 (fail-open)
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail   # no -e: cases are aggregated, a blocking exit 2 must not abort

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
DOTFILES_DIR="$(pwd)"
HOOK="$DOTFILES_DIR/claude/hooks/check-pr-reviewed.sh"

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
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- transcript fixtures ----------------------------------------------------
# Shapes mirror real session JSONL: review evidence appears as a ReportFindings
# tool_use or a Skill tool call whose input names code-review/security-review.
NOREVIEW="$TMP/noreview.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status"}}]}}' \
    > "$NOREVIEW"

REPORTED="$TMP/reported.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ReportFindings","input":{"findings":[]}}]}}' \
    > "$REPORTED"

SKILLED="$TMP/skilled.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"code-review:code-review"}}]}}' \
    > "$SKILLED"

SECREV="$TMP/secrev.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"security-review"}}]}}' \
    > "$SECREV"

ATTRIB="$TMP/attrib.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"text","text":"..."}],"attributionSkill":"code-review"}}' \
    > "$ATTRIB"

# Real transcripts carry invalid-UTF8/NUL bytes; evidence must still be found
# (BSD grep would otherwise error or take the binary shortcut — the measured
# fail-closed bug this fixture pins down).
BINARY="$TMP/binary.jsonl"
{
    printf '\x00\xff\xfe garbage \x80\x81\n'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ReportFindings","input":{}}]}}'
    printf '\x00\xc3\x28 more garbage\n'
} > "$BINARY"

# Delegated reviews record evidence only in the session's sidecar subagent
# transcripts (<transcript-stem>/subagents/agent-*.jsonl), not the main file.
SUBMAIN="$TMP/submain.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git log"}}]}}' \
    > "$SUBMAIN"
mkdir -p "$TMP/submain/subagents"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ReportFindings","input":{"findings":[]}}]}}' \
    > "$TMP/submain/subagents/agent-abc123.jsonl"

# Payload builder: gh-pr-create PreToolUse JSON pointing at a given transcript.
payload() {
    local transcript="$1"
    printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create --fill"},"transcript_path":"%s"}' "$transcript"
}

run_hook() {  # run_hook <payload> [env VAR=VAL ...] → echoes exit code
    local p="$1"; shift
    env "$@" "$HOOK" <<< "$p" > /dev/null 2>&1
    echo $?
}

# --- red: pr create with no review evidence --------------------------------
# Single invocation: the substitution's $? is the hook's exit code.
red_err="$( "$HOOK" <<< "$(payload "$NOREVIEW")" 2>&1 >/dev/null )"
red_rc=$?
if [[ "$red_rc" == "2" ]]; then
    pass "red: no review evidence blocks with exit 2"
else
    fail "red: expected exit 2, got $red_rc"
fi
if [[ "$red_err" == *"/code-review"* ]]; then
    pass "red: stderr names /code-review as the fix"
else
    fail "red: stderr missing expected message (got: ${red_err:-<empty>})"
fi

# --- green: ReportFindings tool call in transcript --------------------------
rc=$(run_hook "$(payload "$REPORTED")")
if [[ "$rc" == "0" ]]; then
    pass "green-report: ReportFindings evidence allows with exit 0"
else
    fail "green-report: expected exit 0, got $rc"
fi

# --- green: code-review skill invocation in transcript -----------------------
rc=$(run_hook "$(payload "$SKILLED")")
if [[ "$rc" == "0" ]]; then
    pass "green-skill: code-review skill evidence allows with exit 0"
else
    fail "green-skill: expected exit 0, got $rc"
fi

# --- green: security-review skill invocation in transcript -------------------
rc=$(run_hook "$(payload "$SECREV")")
if [[ "$rc" == "0" ]]; then
    pass "green-sec: security-review skill evidence allows with exit 0"
else
    fail "green-sec: expected exit 0, got $rc"
fi

# --- green: attributionSkill stamp (the harness's other real shape) -----------
rc=$(run_hook "$(payload "$ATTRIB")")
if [[ "$rc" == "0" ]]; then
    pass "green-attrib: attributionSkill evidence allows with exit 0"
else
    fail "green-attrib: expected exit 0, got $rc"
fi

# --- green: evidence inside a transcript with binary garbage ------------------
rc=$(run_hook "$(payload "$BINARY")")
if [[ "$rc" == "0" ]]; then
    pass "green-binary: evidence found despite invalid-UTF8/NUL bytes"
else
    fail "green-binary: expected exit 0, got $rc"
fi

# --- green: evidence only in a sidecar subagent transcript --------------------
rc=$(run_hook "$(payload "$SUBMAIN")")
if [[ "$rc" == "0" ]]; then
    pass "green-subagent: sidecar subagent evidence allows with exit 0"
else
    fail "green-subagent: expected exit 0, got $rc"
fi

# --- bypass: CLAUDE_SKIP_REVIEW=1 -------------------------------------------
rc=$(run_hook "$(payload "$NOREVIEW")" CLAUDE_SKIP_REVIEW=1)
if [[ "$rc" == "0" ]]; then
    pass "bypass: CLAUDE_SKIP_REVIEW=1 allows with exit 0"
else
    fail "bypass: expected exit 0, got $rc"
fi

# --- data: quoted mention must never block -----------------------------------
DATA_JSON=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"docs: explain the gh pr create workflow\\""},"transcript_path":"%s"}' "$NOREVIEW")
rc=$(run_hook "$DATA_JSON")
if [[ "$rc" == "0" ]]; then
    pass "data: quoted mention of gh pr create allows with exit 0"
else
    fail "data: expected exit 0, got $rc"
fi

# --- skip: command is not gh pr create ---------------------------------------
NON_JSON=$(printf '{"tool_name":"Bash","tool_input":{"command":"git status"},"transcript_path":"%s"}' "$NOREVIEW")
rc=$(run_hook "$NON_JSON")
if [[ "$rc" == "0" ]]; then
    pass "skip: non-matching command allows with exit 0"
else
    fail "skip: expected exit 0, got $rc"
fi

# --- fail-open: payload without transcript_path -------------------------------
NOPATH_JSON='{"tool_name":"Bash","tool_input":{"command":"gh pr create --fill"}}'
rc=$(run_hook "$NOPATH_JSON")
if [[ "$rc" == "0" ]]; then
    pass "fail-open: missing transcript_path allows with exit 0"
else
    fail "fail-open: no-path expected exit 0, got $rc"
fi

# --- fail-open: transcript file does not exist --------------------------------
rc=$(run_hook "$(payload "$TMP/does-not-exist.jsonl")")
if [[ "$rc" == "0" ]]; then
    pass "fail-open: missing transcript file allows with exit 0"
else
    fail "fail-open: no-file expected exit 0, got $rc"
fi

# --- fail-open: jq unavailable on PATH ----------------------------------------
# Restrict PATH to a dir holding only the binaries the hook needs before the jq
# check (none — read/[[ are builtins), so it finds no jq and bails out.
NOJQBIN="$TMP/nojqbin"
mkdir -p "$NOJQBIN"
nojq_rc=$( PATH="$NOJQBIN" "$HOOK" <<< "$(payload "$NOREVIEW")" > /dev/null 2>&1; echo $? )
if [[ "$nojq_rc" == "0" ]]; then
    pass "fail-open: missing jq allows with exit 0"
else
    fail "fail-open: no-jq expected exit 0, got $nojq_rc"
fi

echo
echo "check-pr-reviewed: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
