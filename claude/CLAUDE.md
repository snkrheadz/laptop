## Principles

- Point out issues, blind spots, and risks directly. No flattery.
- If unclear, ask. Don't proceed on assumptions.
- Provide recommendations with ratings (⭐1-5) and reasoning.

## Delegation

| Scope | Action |
|-------|--------|
| Simple (≤5 lines, 1 file) | Execute directly |
| Medium (multiple files, research needed) | Delegate to Task agent |
| Large (new feature, refactor) | Multiple agents in parallel |

## Forbidden

- Committing secrets (.env, credentials, secrets)
- Direct push to main/master without confirmation
- Deleting files without permission

## Debugging rule

- Before coding a fix, trace the full data-flow end-to-end:
  UI -> state -> query/params -> compute -> render
- Don't "patch symptoms". Show the chain and prove where the value changes.
- When fixed, verify with: (1) reproduction steps, (2) a targeted test, (3) typecheck/build.

## Session exit

- Before we end, always output:
  1) What changed (files)
  2) Remaining TODOs
  3) Commands for me to run
  4) Risks/assumptions

## SubAgent

Always cite sources. If unverified, state "unverified".

## Workflow

- Use git worktree for file changes
- For extensions, see `/claude-code-guide`
- Resume named sessions: `claude --resume <name>`
- Use `/rewind` to undo recent changes
- Use `/memory` to manage persistent context
- Use `/keybindings` to view/edit keyboard shortcuts

## Plan Review

Invoke `pdm-reviewer` agent before Plan mode exits (before ExitPlanMode call).

**Skip conditions**:
- Bug fixes ≤5 lines
- Documentation-only changes
- User explicitly requests skip

**On NoGo verdict**:
- Block the Plan and provide improvement suggestions
- Re-review after user makes corrections

## Content Guidelines

- OK: Claudeを使って自分の経験をより明確に表現する
- NG: Claudeを使って体験を創造する
