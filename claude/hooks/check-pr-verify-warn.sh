#!/bin/bash
# PreToolUse hook (Bash matcher): WARN (never block) when a PR is created
# without scripts/verify.sh having been run in this session.
#
# The sibling gates check-pr-base.sh and check-pr-reviewed.sh BLOCK (exit 2).
# This one deliberately does NOT: the #120 decision rejected a blocking version
# because verify.sh's "clean" verdict is environment-dependent (it SKIPs the
# lint/pre-commit/gitleaks checks when those tools are absent), so a hard gate
# would false-block legitimate PRs on a fresh checkout. A nudge is the ceiling.
#
# So the ONLY effect here is a one-line stderr warning; every path exits 0.
# This mirrors validate-shell.sh's warn-only idiom (stderr + exit 0) rather
# than the exit-2 gate of the two sibling PR hooks.
#
# FAIL-OPEN, same governing principle as the siblings: every anomaly — jq
# missing, no transcript, transcript unreadable, grep error — exits 0 WITHOUT
# warning (a spurious warning on a broken guard trains the reader to ignore it).
# The warning fires on exactly one positive condition: a `gh … pr create` whose
# session transcript contains no evidence that verify.sh was run.
#
# Exit code is ALWAYS 0. The signal is the presence/absence of stderr output.

# Builtin read (no `cat` fork): this hook fires on EVERY Bash call, so the
# non-matching fast path must spawn zero processes.
IFS= read -r -d '' input || true

# Cheap pure-builtin pre-filter, identical rationale to check-pr-reviewed.sh.
[[ "$input" == *"pr create"* ]] || exit 0

# jq parses the tool_input JSON; without it we cannot read the command → allow.
command -v jq &> /dev/null || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
[[ -n "$cmd" ]] || exit 0

# Precision match, two steps (same asymmetry as the sibling hooks: a missed
# match fails open, a false match must never warn on unrelated work):
#  1. Strip quoted spans so `gh pr create` appearing as DATA cannot trigger.
#  2. Require an actual `gh … pr create` invocation in a pipeline segment.
stripped=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<< "$cmd" 2>/dev/null) || stripped="$cmd"
grep -Eq '(^|[;&|[:space:]])gh[[:space:]]+([^;&|]*[[:space:]])?pr[[:space:]]+create([[:space:]]|$|[;&|)])' \
    <<< "$stripped" || exit 0

# Locate this session's transcript; without one we cannot prove anything → allow.
transcript=$(jq -r '.transcript_path // empty' <<< "$input" 2>/dev/null)
[[ -n "$transcript" && -f "$transcript" ]] || exit 0

# Evidence that verify.sh was RUN: a Bash tool call whose "command" field names
# verify.sh. Scoping to the "command" field (not the bare filename) is
# deliberate — verify.sh is discussed as prose all over a normal session
# (docs edits, this hook's own header), and matching those would suppress the
# warning permanently. A "command":"…verify.sh…" shape means it was actually
# invoked as a shell command. False negatives here only drop a nudge, never
# block, so the loose command-field proxy is acceptable.
#
# LC_ALL=C + -a: real transcripts carry invalid-UTF8/NUL bytes on which BSD
# grep otherwise errors or takes the binary shortcut (see check-pr-reviewed.sh).
PATTERN='"command"[[:space:]]*:[[:space:]]*"[^"]*verify\.sh'
evidence() {
    LC_ALL=C grep -a -Eq "$PATTERN" "$1" 2>/dev/null
}

evidence "$transcript"
rc=$?
[[ $rc -eq 0 ]] && exit 0
# grep error (≥2): we cannot prove absence → fail open (no warning), per the
# governing principle. Only a clean no-match (rc 1) proceeds toward warning.
[[ $rc -ge 2 ]] && exit 0

# A delegated verify (the verify-shell agent runs it in a subagent) records its
# command in the session's sidecar subagent transcripts, not the main file —
# scan those too before concluding verify.sh was never run.
subdir="${transcript%.jsonl}/subagents"
if [[ -d "$subdir" ]]; then
    for f in "$subdir"/*.jsonl; do
        [[ -f "$f" ]] || continue
        evidence "$f" && exit 0
    done
fi

echo "Warning: scripts/verify.sh has not been run in this session. It is the Closing Gate (shellcheck / pre-commit / symlink / hook-tests) — consider running 'bash scripts/verify.sh' before this PR. (warning only, not blocking)" >&2
exit 0
