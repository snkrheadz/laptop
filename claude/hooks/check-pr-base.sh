#!/bin/bash
# PreToolUse hook (Bash matcher): enforce a fresh PR base branch.
#
# Promotes the former prose rule "PR creation goes through /eng:create-pr (it
# syncs the base before gh pr create, so PRs never open against a stale base)"
# from a norm the model must remember into an invariant the harness checks:
# a `gh pr create` is blocked unless origin/<default-branch> is already an
# ancestor of HEAD (i.e. the base is not stale).
#
# FAIL-OPEN is the governing principle. A broken guard that blocks every Bash
# call is far worse than a missed stale-base check, so EVERY anomaly — not a
# git repo, no origin remote, jq missing, fetch failure — exits 0 (allow).
# Only one condition blocks: we positively confirmed the base is stale.
#
# Exit codes: 0 = allow (the common path and every fail-open branch);
#             2 = block, with the reason on stderr (base confirmed stale).

input=$(cat)

# Cheap pure-builtin pre-filter: the literal substring survives JSON encoding,
# so if the raw payload can't contain `gh pr create` there is nothing to guard
# and we skip spawning jq on every Bash call.
[[ "$input" == *"gh pr create"* ]] || exit 0

# jq parses the tool_input JSON; without it we cannot read the command → allow.
command -v jq &> /dev/null || exit 0
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Confirm the actual command (not just some other field) invokes gh pr create.
[[ "$cmd" == *"gh pr create"* ]] || exit 0

# From here we inspect git state; any failure means we cannot prove staleness → allow.
git rev-parse --git-dir &> /dev/null || exit 0        # not a git repo
git remote get-url origin &> /dev/null || exit 0      # no origin remote

# Resolve the default base branch from origin/HEAD, falling back to main.
base=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
    base="${ref#origin/}"
fi
[[ -n "$base" ]] || base="main"

# Refresh origin/<base> under a bounded timeout so a hung network can never
# stall the session. timeout/gtimeout when available, else a background+kill
# fallback; any non-zero (offline, timed out, unknown ref) → allow.
if command -v timeout &> /dev/null; then
    timeout 10 git fetch origin "$base" --quiet || exit 0
elif command -v gtimeout &> /dev/null; then
    gtimeout 10 git fetch origin "$base" --quiet || exit 0
else
    git fetch origin "$base" --quiet &
    fetch_pid=$!
    ( sleep 10; kill -TERM "$fetch_pid" 2>/dev/null ) &
    watcher_pid=$!
    fetch_rc=0
    wait "$fetch_pid" 2>/dev/null || fetch_rc=$?
    kill -TERM "$watcher_pid" 2>/dev/null
    wait "$watcher_pid" 2>/dev/null
    [[ $fetch_rc -eq 0 ]] || exit 0
fi

# Guard the ref before comparing: a missing origin/<base> would make
# merge-base exit >=2 and wrongly fall through to the block. Absent ref → allow.
git rev-parse --verify --quiet "refs/remotes/origin/$base" > /dev/null || exit 0

# The invariant: origin/<base> must already be an ancestor of HEAD. True (0)
# when HEAD contains all of base — including the equal case — so a synced
# branch passes and only a genuinely stale base falls through to the block.
if git merge-base --is-ancestor "refs/remotes/origin/$base" HEAD 2>/dev/null; then
    exit 0
fi

echo "Base branch is stale: origin/$base is not merged into HEAD. Run /eng:create-pr (it syncs the base before gh pr create)." >&2
exit 2
