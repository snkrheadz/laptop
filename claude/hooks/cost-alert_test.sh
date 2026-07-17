#!/bin/bash
# Behavior tests for claude/hooks/cost-alert.sh (the Stop-hook cost notifier).
#
# osascript is mocked via a PATH-prepended shim that logs its arguments instead
# of showing a notification; HOME is redirected to an isolated fixture so the
# daily-usage file is controlled. The hook keys its once-per-session state in
# /tmp by session_id, so every case uses a unique test session id (cleaned on
# exit). Cases:
#   quiet     — cost below both thresholds        → no notification, exit 0
#   session   — session cost crosses threshold    → exactly one notification
#   once      — same session crosses again        → no second notification
#   daily     — daily usage file crosses threshold→ daily notification
#   override  — env threshold override honored    → fires below the default
#   no-jq     — jq unavailable on PATH            → exit 0 (fail-open)
#
# Exit 0 when every case passes; non-zero (listing the failed case) otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
HOOK="$(pwd)/claude/hooks/cost-alert.sh"

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
SID_PREFIX="costtest-$$"
cleanup() {
    rm -rf "$TMP"
    rm -f "/tmp/claude-cost-alert-${SID_PREFIX}"-*
}
trap cleanup EXIT

# osascript shim: append the notification text to a log instead of displaying.
SHIM="$TMP/shim"
mkdir -p "$SHIM"
cat > "$SHIM/osascript" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$TMP/osascript.log"
EOF
chmod +x "$SHIM/osascript"

FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude/usage"

payload() {  # payload <session_id> <cost>
    printf '{"session_id":"%s","cost":{"total_cost_usd":%s}}' "$1" "$2"
}

run_hook() {  # run_hook <payload> [VAR=VAL ...] → echoes exit code
    local p="$1"; shift
    env HOME="$FAKE_HOME" PATH="$SHIM:$PATH" "$@" "$HOOK" <<< "$p" > /dev/null 2>&1
    echo $?
}

notifications() { wc -l < "$TMP/osascript.log" 2>/dev/null | tr -d ' ' || echo 0; }

# --- quiet: below both thresholds -------------------------------------------
rc=$(run_hook "$(payload "$SID_PREFIX-quiet" 1.0)")
if [[ "$rc" == "0" && ! -f "$TMP/osascript.log" ]]; then
    pass "quiet: below thresholds fires nothing and exits 0"
else
    fail "quiet: expected exit 0 and no notification (rc=$rc, log=$(notifications))"
fi

# --- session: cost crosses the default $5 threshold --------------------------
rc=$(run_hook "$(payload "$SID_PREFIX-sess" 6.0)")
if [[ "$rc" == "0" && "$(notifications)" == "1" ]] \
    && grep -q 'session cost' "$TMP/osascript.log"; then
    pass "session: crossing fires exactly one session notification"
else
    fail "session: expected 1 session notification (rc=$rc, log=$(notifications))"
fi

# --- once: the same session must not re-notify -------------------------------
rc=$(run_hook "$(payload "$SID_PREFIX-sess" 7.0)")
if [[ "$rc" == "0" && "$(notifications)" == "1" ]]; then
    pass "once: second crossing in the same session stays silent"
else
    fail "once: expected no second notification (rc=$rc, log=$(notifications))"
fi

# --- daily: usage file total crosses the default $20 threshold ---------------
TODAY=$(date +%Y-%m-%d)
printf '{"sessions":{"a":15,"b":10}}' > "$FAKE_HOME/.claude/usage/$TODAY.json"
rc=$(run_hook "$(payload "$SID_PREFIX-daily" 0.5)")
if [[ "$rc" == "0" ]] && grep -q 'daily cost' "$TMP/osascript.log"; then
    pass "daily: usage-file total crossing fires the daily notification"
else
    fail "daily: expected a daily notification (rc=$rc)"
fi
rm -f "$FAKE_HOME/.claude/usage/$TODAY.json"

# --- override: CLAUDE_COST_SESSION_THRESHOLD is honored -----------------------
before=$(notifications)
rc=$(run_hook "$(payload "$SID_PREFIX-ovr" 3.0)" CLAUDE_COST_SESSION_THRESHOLD=2)
after=$(notifications)
if [[ "$rc" == "0" && "$after" == "$((before + 1))" ]]; then
    pass "override: env threshold 2 fires at cost 3"
else
    fail "override: expected one more notification (rc=$rc, before=$before after=$after)"
fi

# --- fail-open: jq unavailable on PATH ----------------------------------------
NOJQBIN="$TMP/nojqbin"
mkdir -p "$NOJQBIN"
ln -s "$(command -v cat)" "$NOJQBIN/cat"
nojq_rc=$( env HOME="$FAKE_HOME" PATH="$NOJQBIN" "$HOOK" <<< "$(payload "$SID_PREFIX-nojq" 9.0)" > /dev/null 2>&1; echo $? )
if [[ "$nojq_rc" == "0" ]]; then
    pass "fail-open: missing jq exits 0"
else
    fail "fail-open: no-jq expected exit 0, got $nojq_rc"
fi

echo
echo "cost-alert: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
