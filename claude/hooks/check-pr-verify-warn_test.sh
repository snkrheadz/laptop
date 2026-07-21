#!/bin/bash
# Behavior tests for claude/hooks/check-pr-verify-warn.sh (the warn-only
# verify.sh nudge at PR creation).
#
# Unlike the two blocking PR hooks, this one ALWAYS exits 0 — the signal is the
# presence or absence of a stderr warning, so every case asserts on OUTPUT, not
# the exit code:
#   warn         — pr create, transcript shows no verify.sh run → warning on stderr
#   quiet-cmd    — transcript has a "command":"…verify.sh" entry → no warning
#   quiet-binary — verify.sh command among invalid-UTF8/NUL bytes → no warning
#   quiet-sub    — verify.sh command only in sidecar subagent transcript → no warning
#   data         — `gh pr create` as quoted data                → no warning (pre-filter)
#   skip         — command is not `gh pr create`                → no warning (pre-filter)
#   prose        — verify.sh only as prose text, not a command  → warning (must still fire)
#   no-path      — payload has no transcript_path               → no warning (fail-open)
#   no-file      — transcript_path points at a missing file     → no warning (fail-open)
#   no-jq        — jq unavailable on PATH                       → no warning (fail-open)
# Every case additionally asserts exit code 0 (the hook never blocks).
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
DOTFILES_DIR="$(pwd)"
HOOK="$DOTFILES_DIR/claude/hooks/check-pr-verify-warn.sh"

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
# No verify.sh run: only unrelated Bash commands.
NORUN="$TMP/norun.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status"}}]}}' \
    > "$NORUN"

# verify.sh invoked as a shell command.
RAN="$TMP/ran.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash scripts/verify.sh"}}]}}' \
    > "$RAN"

# verify.sh command embedded among invalid-UTF8/NUL bytes (see check-pr-reviewed).
BINARY="$TMP/binary.jsonl"
{
    printf '\x00\xff\xfe garbage \x80\x81\n'
    printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash scripts/verify.sh"}}]}}'
    printf '\x00\xc3\x28 more garbage\n'
} > "$BINARY"

# Delegated verify: command only in a sidecar subagent transcript.
SUBMAIN="$TMP/submain.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git log"}}]}}' \
    > "$SUBMAIN"
mkdir -p "$TMP/submain/subagents"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"bash scripts/verify.sh"}}]}}' \
    > "$TMP/submain/subagents/agent-abc123.jsonl"

# verify.sh mentioned ONLY as prose text (an assistant message), never run as a
# command — the warning must still fire (this is the scoping the hook targets).
PROSE="$TMP/prose.jsonl"
printf '%s\n' \
    '{"type":"assistant","message":{"content":[{"type":"text","text":"You should run scripts/verify.sh before the PR."}]}}' \
    > "$PROSE"

# Payload builder: gh-pr-create PreToolUse JSON pointing at a given transcript.
payload() {
    local transcript="$1"
    printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create --fill"},"transcript_path":"%s"}' "$transcript"
}

# run_hook <payload> [env VAR=VAL ...] → captures stderr, sets $rc and $err.
# The hook always exits 0, so the discriminating signal is stderr, not $?.
run_hook() {
    local p="$1"; shift
    err=$( env "$@" "$HOOK" <<< "$p" 2>&1 >/dev/null )
    rc=$?
}

# assert_warn <label>  — expects a warning on stderr and exit 0.
assert_warn() {
    if [[ "$rc" == "0" && "$err" == *"scripts/verify.sh has not been run"* ]]; then
        pass "$1: warns on stderr, exit 0"
    else
        fail "$1: expected warning + exit 0, got rc=$rc err=${err:-<empty>}"
    fi
}

# assert_quiet <label>  — expects NO warning and exit 0.
assert_quiet() {
    if [[ "$rc" == "0" && -z "$err" ]]; then
        pass "$1: no warning, exit 0"
    else
        fail "$1: expected silent exit 0, got rc=$rc err=${err:-<empty>}"
    fi
}

# --- warn: pr create with no verify.sh run ----------------------------------
run_hook "$(payload "$NORUN")"
assert_warn "warn"

# --- quiet: verify.sh run as a command --------------------------------------
run_hook "$(payload "$RAN")"
assert_quiet "quiet-cmd"

# --- quiet: evidence among binary garbage -----------------------------------
run_hook "$(payload "$BINARY")"
assert_quiet "quiet-binary"

# --- quiet: evidence only in a sidecar subagent transcript ------------------
run_hook "$(payload "$SUBMAIN")"
assert_quiet "quiet-sub"

# --- prose: verify.sh only as text → warning must still fire -----------------
run_hook "$(payload "$PROSE")"
assert_warn "prose"

# --- data: quoted mention of gh pr create must not warn ----------------------
DATA_JSON=$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m \\"docs: the gh pr create workflow\\""},"transcript_path":"%s"}' "$NORUN")
run_hook "$DATA_JSON"
assert_quiet "data"

# --- skip: command is not gh pr create ---------------------------------------
NON_JSON=$(printf '{"tool_name":"Bash","tool_input":{"command":"git status"},"transcript_path":"%s"}' "$NORUN")
run_hook "$NON_JSON"
assert_quiet "skip"

# --- fail-open: payload without transcript_path ------------------------------
run_hook '{"tool_name":"Bash","tool_input":{"command":"gh pr create --fill"}}'
assert_quiet "no-path"

# --- fail-open: transcript file does not exist -------------------------------
run_hook "$(payload "$TMP/does-not-exist.jsonl")"
assert_quiet "no-file"

# --- fail-open: jq unavailable on PATH ---------------------------------------
# Restrict PATH to a dir holding none of the binaries the hook needs before the
# jq check (read/[[ are builtins), so it finds no jq and bails silently.
NOJQBIN="$TMP/nojqbin"
mkdir -p "$NOJQBIN"
run_hook "$(payload "$NORUN")" PATH="$NOJQBIN"
assert_quiet "no-jq"

echo
echo "check-pr-verify-warn: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
