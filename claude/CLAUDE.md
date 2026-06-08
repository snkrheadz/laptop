# Workflow Orchestration

## 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately – don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity


## 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution


## 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### Memory Separation
- **Auto-Memory** (`~/.claude/memory/`): tool patterns, environment info, API knowledge → let Claude Code manage automatically
- **tasks/lessons.md**: user corrections, mistake patterns, project-specific rules → record explicitly
- Rule: "corrected by user → lessons.md, discovered preference → auto-memory"


## 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness


## 5. Demand Elegance
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes – don't over-engineer
- Challenge your own work before presenting it


## 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests – then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how


## 7. Loop Primitives: `/goal` vs `/loop` vs `autoresearch`
Boris Cherny's principle – "write the loop that does the work, don't just prompt each turn" – maps to three primitives. **Pick by what should trigger the next turn:**

- **`/goal <condition>`** (condition-driven, official) – keep working autonomously until a verifiable end state holds; a fast model checks the condition after every turn. Use for **bounded work with a measurable end**: tests pass, lint clean, queue empty, migration complete.
- **`/loop [interval] <prompt>`** (time-driven, official) – re-run on a fixed interval, or omit the interval to let Claude self-pace (dynamic). Use for **open-ended observation/maintenance**: watch a deploy, babysit PRs, periodic cleanup. Ends on manual stop or autonomously in dynamic mode. With no args it runs `~/.claude/loop.md`.
- **`autoresearch`** (metric-driven, third-party plugin) – structured modify→verify→keep/discard iteration against a measurable metric. Use only when `/goal` is too thin: you need scoring, reverting bad attempts, and a kept-best record.

**Decision rule:** verifiable end condition → `/goal`; observe/maintain over time → `/loop`; metric + keep/discard search → `autoresearch`. Default to encoding the loop over hand-prompting each turn.


---

## Task Management
1. Plan First: Write plan to `tasks/todo.md` with checkable items
2. Verify Plan: Check in before starting implementation
3. Track Progress: Mark items complete as you go
4. Explain Changes: High-level summary at each step
5. Document Results: Add review section to `tasks/todo.md`
6. Capture Lessons: Update `tasks/lessons.md` after corrections


---

## Core Principles
- Simplicity First: Make every change as simple as possible. Impact minimal code.
- No Laziness: Find root causes. No temporary fixes. Senior developer standards.
- Minimal Impact: Changes should only touch what's necessary. Avoid introducing bugs.
