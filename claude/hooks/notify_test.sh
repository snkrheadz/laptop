#!/bin/bash
# Behavior tests for claude/hooks/notify.sh (the Notification-event voice cue).
#
# `say` is mocked via a PATH-prepended shim that logs its arguments instead of
# speaking. Cases:
#   completed  — notification_type=agent_completed  → "Claude finished a task"
#   input      — notification_type=permission_prompt → "Claude needs input"
#   unknown    — unrecognized notification_type      → "Claude needs input"
#   auth       — notification_type=auth_success      → silent, exit 0
#   bad-json   — unparseable stdin                   → fallback "Claude needs input"
#   no-jq      — jq unavailable on PATH              → fallback "Claude needs input"
#   no-say     — say unavailable on PATH             → exit 0, no crash
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
HOOK="$(pwd)/claude/hooks/notify.sh"

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

# say shim: append the spoken text to a log instead of speaking.
SHIM="$TMP/shim"
mkdir -p "$SHIM"
cat > "$SHIM/say" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$TMP/say.log"
EOF
chmod +x "$SHIM/say"

payload() {  # payload <notification_type>
    printf '{"session_id":"notifytest","notification_type":"%s","message":"m"}' "$1"
}

run_hook() {  # run_hook <stdin> [PATH override] → echoes exit code
    local p="$1" path="${2:-$SHIM:$PATH}"
    env PATH="$path" "$HOOK" <<< "$p" > /dev/null 2>&1
    echo $?
}

last_said() { tail -n 1 "$TMP/say.log" 2>/dev/null; }
said_count() { wc -l < "$TMP/say.log" 2>/dev/null | tr -d ' ' || echo 0; }

# --- completed: agent_completed announces a finish, not "needs input" ---------
rc=$(run_hook "$(payload agent_completed)")
if [[ "$rc" == "0" && "$(last_said)" == "Claude finished a task" ]]; then
    pass "completed: agent_completed says 'Claude finished a task'"
else
    fail "completed: expected finish cue (rc=$rc, said='$(last_said)')"
fi

# --- input: permission_prompt keeps the needs-input cue -----------------------
rc=$(run_hook "$(payload permission_prompt)")
if [[ "$rc" == "0" && "$(last_said)" == "Claude needs input" ]]; then
    pass "input: permission_prompt says 'Claude needs input'"
else
    fail "input: expected needs-input cue (rc=$rc, said='$(last_said)')"
fi

# --- unknown: an unrecognized type falls back to needs-input ------------------
rc=$(run_hook "$(payload some_future_type)")
if [[ "$rc" == "0" && "$(last_said)" == "Claude needs input" ]]; then
    pass "unknown: unrecognized type falls back to 'Claude needs input'"
else
    fail "unknown: expected needs-input fallback (rc=$rc, said='$(last_said)')"
fi

# --- auth: auth_success stays silent ------------------------------------------
before=$(said_count)
rc=$(run_hook "$(payload auth_success)")
after=$(said_count)
if [[ "$rc" == "0" && "$after" == "$before" ]]; then
    pass "auth: auth_success says nothing"
else
    fail "auth: expected silence (rc=$rc, before=$before after=$after)"
fi

# --- bad-json: unparseable stdin falls back to needs-input --------------------
rc=$(run_hook 'not json at all')
if [[ "$rc" == "0" && "$(last_said)" == "Claude needs input" ]]; then
    pass "bad-json: garbage stdin falls back to 'Claude needs input'"
else
    fail "bad-json: expected needs-input fallback (rc=$rc, said='$(last_said)')"
fi

# --- no-jq: missing jq falls back to the previous fixed behavior --------------
NOJQ="$TMP/nojq"
mkdir -p "$NOJQ"
ln -s "$(command -v cat)" "$NOJQ/cat"
ln -s "$SHIM/say" "$NOJQ/say"
rc=$(run_hook "$(payload agent_completed)" "$NOJQ")
if [[ "$rc" == "0" && "$(last_said)" == "Claude needs input" ]]; then
    pass "no-jq: missing jq falls back to 'Claude needs input'"
else
    fail "no-jq: expected needs-input fallback (rc=$rc, said='$(last_said)')"
fi

# --- no-say: missing say is a silent no-op ------------------------------------
NOSAY="$TMP/nosay"
mkdir -p "$NOSAY"
ln -s "$(command -v cat)" "$NOSAY/cat"
ln -s "$(command -v jq)" "$NOSAY/jq" 2>/dev/null
rc=$(run_hook "$(payload permission_prompt)" "$NOSAY")
if [[ "$rc" == "0" ]]; then
    pass "no-say: missing say exits 0"
else
    fail "no-say: expected exit 0, got $rc"
fi

echo
echo "notify: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
