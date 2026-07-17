#!/bin/bash
# PreToolUse hook (Bash matcher): require a code review before PR creation.
#
# Promotes "automated code review is on by default" (the step-1→2 transition
# condition in Boris Cherny's Steps of AI Adoption) from a norm the model must
# remember into an invariant the harness checks: a `gh pr create` is blocked
# unless THIS session's transcript already contains evidence that a review ran
# — a ReportFindings tool call (emitted by /code-review's typed findings) or a
# code-review / security-review skill invocation.
#
# FAIL-OPEN is the governing principle (same as check-pr-base.sh): a broken
# guard that blocks every PR is far worse than a missed review nudge, so every
# anomaly — jq missing, no transcript path, transcript unreadable — exits 0.
# Only one condition blocks: we positively confirmed no review evidence exists.
#
# Deliberate bypass (documented here for humans, NOT advertised in the block
# message): set CLAUDE_SKIP_REVIEW=1 in the environment for PRs where a review
# is genuinely pointless (e.g. a docs-only or generated-file PR).
#
# Exit codes: 0 = allow (the common path and every fail-open branch);
#             2 = block, with the reason on stderr (no review evidence found).

# Builtin read (no `cat` fork): this hook fires on EVERY Bash call, so the
# non-matching fast path must spawn zero processes.
IFS= read -r -d '' input || true

# Cheap pure-builtin pre-filter, identical rationale to check-pr-base.sh.
[[ "$input" == *"pr create"* ]] || exit 0

# Explicit human bypass — before any parsing, so it works even without jq.
[[ "${CLAUDE_SKIP_REVIEW:-0}" == "1" ]] && exit 0

# jq parses the tool_input JSON; without it we cannot read the command → allow.
command -v jq &> /dev/null || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<< "$input" 2>/dev/null)
[[ -n "$cmd" ]] || exit 0

# Precision match, two steps (same asymmetry as check-pr-base.sh: a missed
# match fails open, a false match must never block unrelated work):
#  1. Strip quoted spans so `gh pr create` appearing as DATA cannot trigger.
#  2. Require an actual `gh … pr create` invocation in a pipeline segment.
stripped=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<< "$cmd" 2>/dev/null) || stripped="$cmd"
grep -Eq '(^|[;&|[:space:]])gh[[:space:]]+([^;&|]*[[:space:]])?pr[[:space:]]+create([[:space:]]|$|[;&|)])' \
    <<< "$stripped" || exit 0

# Locate this session's transcript; without one we cannot prove anything → allow.
transcript=$(jq -r '.transcript_path // empty' <<< "$input" 2>/dev/null)
[[ -n "$transcript" && -f "$transcript" ]] || exit 0

# Review evidence: a ReportFindings tool call, a code-review / security-review
# Skill invocation, or the harness's attributionSkill stamp. Three INDEPENDENT
# transcript shapes (verified against a real session 2026-07-17: `"skill":
# "code-review"` and `"attributionSkill":"code-review"` both occur;
# ReportFindings is emitted by /code-review's typed-findings path) so a single
# harness format change cannot silently rot the gate.
#
# LC_ALL=C + -a: real transcripts contain invalid-UTF8/NUL bytes, on which BSD
# grep otherwise errors (exit 2) or takes the binary shortcut — measured to
# fail-CLOSE this gate on a genuinely reviewed session. Byte-mode scanning
# sidesteps both. grep -q short-circuits on first match, so multi-MB
# transcripts stay cheap.
PATTERN='"name"[[:space:]]*:[[:space:]]*"ReportFindings"|"(skill|attributionSkill)"[[:space:]]*:[[:space:]]*"[^"]*(code-review|security-review)'
evidence() {
    LC_ALL=C grep -a -Eq "$PATTERN" "$1" 2>/dev/null
}

evidence "$transcript"
rc=$?
[[ $rc -eq 0 ]] && exit 0
# grep error (≥2): we cannot prove absence of a review → fail open, per the
# governing principle. Only a clean no-match (rc 1) may block.
[[ $rc -ge 2 ]] && exit 0

# A delegated review (/code-review at high effort runs in a subagent) records
# its evidence in the session's sidecar subagent transcripts, not the main
# file — scan those too before concluding no review happened.
subdir="${transcript%.jsonl}/subagents"
if [[ -d "$subdir" ]]; then
    for f in "$subdir"/*.jsonl; do
        [[ -f "$f" ]] || continue
        evidence "$f" && exit 0
    done
fi

echo "No code review found in this session. Run /code-review (or /security-review) on the diff first, then create the PR." >&2
exit 2
