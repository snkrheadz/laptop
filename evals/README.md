# Evals

Behavioral eval suite for this setup, per `claude/CLAUDE.md` §4 and
`docs/evals-for-ai-agents.md`: tasks sourced from **real failures**
(`tasks/lessons.md`), graded on **outcomes, not paths**. The deterministic
layer (hook behavior) lives in `claude/hooks/*_test.sh` and runs in
`scripts/verify.sh`; this suite covers the **judgment** layer — behavior only
an agent run can exercise.

## When to run

- **A new model ships** — run BEFORE rewriting prompts/CLAUDE.md; adopt on
  measured wins (§4: "evals are the new-model lever").
- **A CLAUDE.md / hook / skill change** that intends to change agent behavior.

NOT wired into `scripts/verify.sh` or CI: each run spends real tokens and
takes minutes. Regression tasks are expected to stay at ~100% pass; read the
transcript of any failure before trusting the grade.

## Layout

```text
evals/
├── run.sh                  # runner: fixture → claude -p → check.sh, per task
└── tasks/<name>/
    ├── prompt.md           # the task prompt fed to claude -p
    ├── check.sh            # outcome grader (workdir as $1): exit 0 = pass
    └── fixture/            # copied to a throwaway workdir before the run
```

## Usage

```bash
./evals/run.sh                      # all tasks, current default model
EVAL_MODEL=claude-opus-4-8 ./evals/run.sh        # pin a model
./evals/run.sh json-config-edit     # one task
```

## Seed tasks (regression, from tasks/lessons.md)

| Task | Source failure | Outcome graded |
|------|----------------|----------------|
| `json-config-edit` | 2026-06-19: hand-edited nested JSON broke settings.json, pushed twice | file still parses, target key added, nothing else lost |
| `deletion-dependency-check` | 2026-03-05: deleted a dir still referenced by `.zshrc` (HISTFILE) | answers UNSAFE, cites the reference, deletes nothing |

Add a task per new lesson in `tasks/lessons.md` — that file is the intake
queue for this suite.
