# Default `/loop` maintenance routine

This is the prompt run by a no-argument `/loop` (dynamic self-pacing). It is
**project-agnostic** – it lives at `~/.claude/loop.md` and applies to every repo.

Run **one pass** of lightweight, safe maintenance. Do NOT start large refactors,
force-push, merge, or anything destructive. Each pass:

1. **Continue pending work** – if there is in-progress work (`tasks/todo.md`, an open
   plan, or unfinished edits), advance it by one concrete step.
2. **Tend owned PRs** – run `gh pr status`; if a PR I own has failing CI or new review
   comments, address them. Never merge without explicit approval.
3. **Repo hygiene** – surface (don't silently auto-fix) uncommitted drift, broken
   symlinks, or a failing `pre-commit run --all-files`.
4. **Report** – one short status line: what changed this pass, what's blocked, what's
   next. If nothing is actionable, say so and let the loop idle longer.

**End the loop** when there is no pending work and all owned PRs are green. For bounded
work with a single verifiable end state, prefer `/goal <condition>` over this loop; for
unattended recurring maintenance, prefer a standing **routine** (the `schedule` skill)
over remembering to launch `/loop` (see `~/.claude/CLAUDE.md` §5 for the decision rule).
