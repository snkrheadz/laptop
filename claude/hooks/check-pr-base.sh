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

# Builtin read (no `cat` fork): this hook fires on EVERY Bash call, so the
# non-matching fast path must spawn zero processes. read -d '' consumes stdin
# to EOF and returns non-zero there — that is its success mode, hence || true.
IFS= read -r -d '' input || true

# Cheap pure-builtin pre-filter: any guarded invocation must contain the
# literal `pr create` (it survives JSON encoding). `gh` is NOT required here —
# flags may sit between (`gh -R owner/repo pr create`); the regex below does
# the precise match. No substring → nothing to guard, zero processes spawned.
[[ "$input" == *"pr create"* ]] || exit 0

# jq parses the tool_input JSON; without it we cannot read the command → allow.
command -v jq &> /dev/null || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
[[ -n "$cmd" ]] || exit 0

# Precision match, two steps. The asymmetry is deliberate: a missed match
# fails open (acceptable — this is a mistake guardrail, not a security
# boundary), while a false match blocks unrelated work (never acceptable).
#  1. Strip quoted spans, so `gh pr create` appearing as DATA (a commit
#     message, an echo, a doc line) cannot trigger the guard.
#  2. Require an actual invocation: `gh` at a command position with
#     `pr create` in the same pipeline segment (flags like -R may intervene).
stripped=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<< "$cmd" 2>/dev/null) || stripped="$cmd"
grep -Eq '(^|[;&|[:space:]])gh[[:space:]]+([^;&|]*[[:space:]])?pr[[:space:]]+create([[:space:]]|$|[;&|)])' \
    <<< "$stripped" || exit 0

# A command that performs its own base sync before creating the PR — the
# documented /eng:create-pr flow runs fetch→merge→push→create as ONE Bash
# block — must not be blocked: PreToolUse inspects the pre-merge HEAD, but the
# block itself establishes the invariant before `gh pr create` runs. Trust it.
if grep -Eq 'git[[:space:]]+fetch' <<< "$stripped" \
    && grep -Eq 'git[[:space:]]+(merge|rebase|pull)' <<< "$stripped"; then
    exit 0
fi

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
