# Workflow Orchestration

These are the *non-obvious* operating rules for this setup. Things a modern model
already does well — find root causes, prefer simple code, write tests, avoid hacks —
are intentionally **not** repeated here. Adding them back is micromanagement; trust the
model and keep this file minimal.


## 1. Execution defaults
- **Per-step confirmation adds no safety.** The harness routes risky commands through
  a security check, and accident guardrails (`settings.json` deny rules + the `core`
  pack's `pre-tool-guard` hook — guardrails against mistakes, not a security boundary)
  catch sensitive-file access. So act, don't ask; narrating yes/no just hides the
  calls that matter.
- **Skip plan mode for ordinary work.** Reach for `EnterPlanMode` only when a choice
  is hard to reverse (schema/data migrations, public-facing or destructive changes,
  multi-service refactors) or you cannot yet state the acceptance check in one line.
- **If you do use plan mode:** pass a minimal or empty `allowedPrompts` to
  `ExitPlanMode` and approve Bash prompts interactively — a large nested-JSON payload
  can corrupt the tool-call wrapper so the call leaks into the message as plain text
  and the plan never renders (Opus 4.8, recorded 2026-06; delete this rule once a
  large `allowedPrompts` renders correctly). If the call leaks, re-call
  `ExitPlanMode` with `allowedPrompts` empty.
- **Two consecutive failed fixes on the same hypothesis:** stop, restate the problem
  from the evidence, and re-derive the approach before touching more code.


## 2. Orchestration: skill → subagent → team → workflow
Escalate only as far as the work demands; each rung differs in who holds the plan.
- **Skill** — a repeatable in-context procedure; the skill text holds the plan.
- **Subagent** (`Agent`) — one focused task in its own context (research, a scoped
  edit, one file's analysis); you hold the plan, the agent executes one step of it.
- **Agent Team** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — long-lived peers over a
  shared task list; the lead holds the plan (e.g. `/eng:refactor-swarm` by module).
- **Dynamic Workflow** (`Workflow`, via the `ultracode` keyword) — the workflow
  definition holds the plan: deterministic fan-out with verify gates, up to 16
  concurrent / 1,000 per run (codebase-wide audit, migration over many sites,
  adversarial review).

**Rule:**
- a matching skill → use it, at any size
- edits tightly coupled to work already in your context → main session, always
- otherwise, a plan of 3 steps or fewer → delegate per model routing below
- longer single-role work → main session, planned per §6, delegating spec-complete
  chunks as they emerge
- coordinated multi-role → Team
- wide fan-out + verify/synthesize → Workflow (wins over Team when both match);
  long autonomous runs encode their fan-out in a Workflow instead of hand-spawning
  agents each turn

### Web fan-out is serial
Hammering one host with concurrent `WebFetch` calls or parallel research subagents
trips CDN rate limits and bot detection, which slows the whole job. So: web-research
subagents one at a time; one `WebFetch` per turn; triage with `WebSearch`, then fetch
only a curated few (the 15-min cache makes re-fetch free); prefer typed channels
(`research@the-boris-way` researchers) over raw scraping. For deliberate breadth, use
a `Workflow` `pipeline()` — its concurrency is auto-capped.

### Model routing
Subagents **inherit the main-session model unless `model` is set explicitly** — on a
Fable 5 session (2× Opus 4.8 cost, no fast mode) an untagged delegation buys
Fable-tier reasoning for work that doesn't need it:
- **Fable 5 (main) holds** design, decomposition, and the review and integration of
  everything delegated — plus implementation while its spec cannot yet be written.
  The rules below route what leaves main.
- **Delegate by spec-completeness:** implementation you can spec fully — paths,
  expected behavior, constraints, how to verify — goes to `model: "opus"`; mechanical
  work (boilerplate, renames, test scaffolds) to `model: "sonnet"`. The spec *is* the
  delegation prompt; agents return changed paths + summary + verification result,
  never file dumps — keep the main context lean.
- **Fact-finding delegations** (search, gather, summarize, locate) default to
  `model: "sonnet"`; raise to `model: "opus"` when weighing evidence is the task
  itself.
- **Delegatable work not routed above** defaults to `model: "opus"`.
- **On an Opus 4.8 main session** the cost asymmetry disappears — inherit freely
  there.
- **Security work that would run on Fable 5 routes to Opus 4.8 instead.** Security
  audits, red-teaming, and exploit-reproduction debugging can trip Fable 5's safety
  classifiers (`stop_reason: refusal`) even when benign — switch the main session or
  use a `model: "opus"` subagent. Delegations that never touch Fable (security
  fact-finding on sonnet) follow their own rules.
- **Dispatch async, don't block.** Fire independent subtasks with `run_in_background`
  (web research excepted — serial rule above) and keep working; reuse a long-lived
  agent via `SendMessage` instead of respawning — context carries over and cache
  reads stay warm.


## 3. Self-improvement & memory
- **User correction → `tasks/lessons.md`** (record the pattern *and the why*); a
  correction that also reveals a preference goes here, not to memory.
- **Discovered preference (uncorrected) → auto-memory**
  (`~/.claude/projects/<project>/memory/`, managed by Claude Code).
- **Session start:** review `tasks/lessons.md` for the active project.
- **Local-first lookup:** for meetings, status, or personal context, check auto-memory
  and local prep files before calling external services (Google Calendar/Drive etc.).


## 4. Verification: run the real thing
Exit 0, green lint, and passing types close nothing on their own.
- **Observe behavior:** start the real server / UI driver / simulator and drive the
  affected flow; for changes to existing behavior, diff against the pre-change
  baseline.
- **Autonomous runs need an end-to-end check that self-terminates honestly.** If
  none exists, build it before starting the run.
- **Per-repo closing gates:** when the repo's project CLAUDE.md defines one, run it
  before declaring work done.
- **Evals are the new-model lever.** Agent/product behavior worth keeping gets a
  small eval suite: 20–50 tasks sourced from real failures; grade outcomes, not
  paths; capability evals may start near 0%, regression evals stay ~100%. When a
  new model ships, run the suite before rewriting prompts — adopt on measured
  wins, and never trust a grader whose failing transcripts you haven't read.
  Full context: laptop repo `docs/evals-for-ai-agents.md`.


## 5. Loop & routine primitives: pick by what triggers the next turn
- **routine** (`schedule` skill) — a cloud cron agent; no live session needed (review
  requests, red CI on owned PRs, stale bug reports).
- **`/goal <condition>`** — the harness keeps re-prompting until a checker verifies
  the condition holds (tests pass, queue empty, metric ≥ target).
- **`/loop [interval] <prompt>`** — re-prompts inside the session at a fixed
  interval, or self-paced with no interval. No-arg runs `~/.claude/loop.md`.

**Rule:** unattended & clock-triggered (recurring or one-shot) → routine; a
verifiable end condition → `/goal`, even for in-session watches; open-ended
observe/maintain → `/loop`. Compose these (the *when*) with §2 (the *how* to fan
out).


## 6. Task management & principles
- **Plans:** work kept in the main session that runs past 3 steps gets a checkable
  plan in `tasks/todo.md`, tracked as you go and closed with a one-paragraph review.
  Below that, skip the ceremony.
- **Scope:** every changed line traces to the request. Remove only the
  imports/vars/functions *your* edit orphaned; pre-existing dead code → mention it,
  don't delete it (unless asked).
