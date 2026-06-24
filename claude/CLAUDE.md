# Workflow Orchestration

These are the *non-obvious* operating rules for this setup. Things a modern model
already does well — find root causes, prefer simple code, write tests, avoid hacks —
are intentionally **not** repeated here. Adding them back is micromanagement; trust the
model and keep this file minimal.


## 1. auto-first execution
- Default to **auto mode**: act, don't ask. The harness routes risky commands through a
  security check and `pre-tool-guard.sh` blocks sensitive-file access and guards
  `gh pr create` (self-branch, stale-base, empty-diff), so narrating yes/no for each step adds no safety — it just hides the
  calls that matter.
- **Skip plan mode for ordinary work.** Current models don't need a separate planning
  step. Reach for `EnterPlanMode` only when a choice is genuinely hard to reverse
  (schema/data migrations, public-facing or destructive changes, multi-service
  refactors) or the requirements are truly ambiguous.
- **If you do use plan mode, keep `ExitPlanMode` light.** Pass a minimal `allowedPrompts`
  (or none) — a large nested-JSON payload can corrupt the tool-call XML wrapper, so the
  call leaks into the message as plain text (`<invoke name="ExitPlanMode">…`) and the plan
  / approval never renders (observed on Opus 4.8). Approve Bash prompts interactively
  instead of pre-listing them. Avoiding plan mode altogether (above) sidesteps this.
- If an approach goes sideways, stop and re-think rather than pushing a failing path.


## 2. Orchestration: subagent → skill → team → workflow
Escalate only as far as the work demands; the difference is who holds the plan.
- **Subagent** (`Agent`) — one focused task in its own context (research, a scoped edit,
  one file's analysis). The default for delegation.
- **Skill** — a repeatable in-context procedure with no fan-out. Cheapest; prefer it
  before spinning up agents.
- **Agent Team** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) — a lead supervising long-lived
  peers over a shared task list (e.g. `/eng:refactor-swarm` by module). Use when work needs
  coordination across roles.
- **Dynamic Workflow** (`Workflow`, via the `ultracode` keyword) — deterministic fan-out
  with verify gates, up to 16 concurrent / 1,000 per run. Use for breadth one context
  can't hold: codebase-wide audit, migration over many sites, adversarial review.

**Rule:** plan fits in 2–3 steps → subagent or skill; coordinated multi-role → Team;
wide fan-out + verify/synthesize → Workflow. For long autonomous runs, encode the
fan-out in a Workflow instead of hand-spawning agents each turn.

- **Web fan-out is serial, not parallel.** Hammering one host with many concurrent
  `WebFetch` calls or parallel research subagents trips CDN rate limits and bot
  detection, which slows the whole job. So: launch web-research subagents one at a
  time; one `WebFetch` per turn; triage with `WebSearch`, then fetch only a curated
  few (the 15-min cache makes re-fetch free); prefer typed channels
  (`research@claude-skills` researchers, `hf-spaces`) over raw scraping. For
  deliberate breadth, use a `Workflow` `pipeline()` (auto-capped concurrency), not
  hand-spawned parallel agents.

### Model routing (Fable 5 main session)
Subagents **inherit the main-session model unless `model` is set explicitly** — on a
Fable 5 session (2× Opus 4.8 cost, no fast mode) an untagged delegation buys top-tier
reasoning for work that doesn't need it. So:
- **Fable 5 (main)** holds design, decomposition, audit, review, final integration —
  and only the genuinely hard implementation.
- Delegate normal-difficulty implementation to `model: "opus"`; mechanical work
  (boilerplate, renames, test scaffolds, clearly-specced edits) to `model: "sonnet"`.
- Delegation prompts must be self-contained (paths, expected behavior, constraints,
  how to verify); have agents return changed paths + summary + verification result,
  not file dumps — keep the main context lean.
- Don't delegate small tightly-coupled sequential edits: handoff overhead exceeds the
  win. On an Opus 4.8 main session the cost asymmetry disappears — inherit freely there.
- **Security work routes to Opus 4.8.** Security audits, red-teaming, and
  exploit-reproduction debugging can trip Fable 5's safety classifiers
  (`stop_reason: refusal`) even when benign — run them on Opus 4.8 (switch the main
  session, or a `model: "opus"` subagent).
- **Dispatch async, don't block.** Fire independent subtasks with `run_in_background`
  and keep working; reuse a long-lived agent via `SendMessage` instead of respawning —
  context carries over and cache reads stay warm.


## 3. Self-improvement & memory
- **User correction → `tasks/lessons.md`** (record the pattern *and the why*).
- **Discovered preference → auto-memory** (`~/.claude/memory/`, let Claude Code manage it).
- Review `tasks/lessons.md` at session start for the active project.
- **Local-first lookup:** 会議・状況・コンテキスト情報を調べるときは、外部サービス（Google Calendar/Drive 等）を呼ぶ前に `~/.claude/memory/` とローカルの prep ファイルを先に確認する。


## 4. Verification = run the real thing
"Done" means **observed working**, not exit 0. Lint and type-checks are table stakes,
not verification — for an agent, verification is *"can I actually run this and watch it
behave?"*
- Start the real server / UI driver / simulator and observe behavior; diff against the
  baseline when relevant.
- **Autonomous runs need an end-to-end check that self-terminates honestly.** If none
  exists, build it first — an unattended loop with no verification path is not safe to run.
- This repo's closing gate: `source ~/.zshrc` loads clean, `shellcheck` passes,
  `pre-commit run --all-files` is green, and `health-check` reports no broken symlinks.
  Use the `verify-shell` agent (from `eng@claude-skills`), the official `/verify`
  skill, and the `/eng:test-and-fix` skill.


## 5. Loop & routine primitives — pick by what triggers the next turn
"Write the loop that does the work; don't hand-prompt each turn." Routines are the next
leap: you stop talking to the agent and talk to the loop that prompts it.

- **routine** (`schedule` skill → cloud cron agent) — **unattended and recurring; runs
  without you present.** This is the default for ongoing maintenance: have a routine pick
  up review requests, red CI on owned PRs, and stale bug reports on a schedule. Prefer a
  standing routine for unattended recurring work.
- **`/goal <condition>`** — work until a verifiable end state holds (tests pass, queue
  empty, migration complete). Bounded work with a measurable end.
- **`/loop [interval] <prompt>`** — fixed interval, or no interval to self-pace. For an
  interactive, in-session watch/maintain pass. No-arg runs `~/.claude/loop.md`.
- **`autoresearch`** — metric-driven modify→verify→keep/discard search. Use when `/goal`
  is too thin (you need scoring and reverting bad attempts).

**Rule:** unattended & recurring → routine; verifiable end condition → `/goal`;
in-session observe/maintain → `/loop`; metric + keep/discard → `autoresearch`.
Compose these (the *when*) with §2 (the *how* to fan out).


---

## Task management & principles
- Non-trivial work: jot a short checkable plan in `tasks/todo.md`, track it as you go,
  and close with a one-paragraph review. Skip the ceremony for small obvious changes.
- Keep every change minimal and scoped — touch only what's necessary.

@RTK.md
