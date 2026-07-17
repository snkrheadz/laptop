#!/bin/bash
# Eval runner: for each task under evals/tasks/, copy its fixture into a
# throwaway workdir, run `claude -p` with the task prompt inside it, then
# grade the OUTCOME with the task's check.sh (which inspects the final state
# of the workdir + the agent's answer, never the path taken).
#
# Usage: ./evals/run.sh [task-name ...]      # default: every task
#   EVAL_MODEL=<model>     pin the model (default: the CLI's configured default —
#                          NOTE: unpinned runs are not comparable across machines/time)
#   EVAL_TIMEOUT=<secs>    per-task wall clock cap (default 600; needs timeout/gtimeout)
#   EVAL_KEEP=1            keep workdirs for transcript reading on failure
#
# Exit 0 when every selected task passes; non-zero otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
ROOT="$(pwd)"
TASKS_DIR="evals/tasks"

# Grader/runner dependencies fail the RUN, distinctly — a missing tool must
# never be reported as the model getting the task wrong.
for dep in claude jq python3; do
    command -v "$dep" &> /dev/null || { echo "runner dependency not found: $dep"; exit 1; }
done

# Per-task timeout so a stuck agent cannot hang the suite (§4: autonomous runs
# must self-terminate honestly). macOS: coreutils gtimeout; absent → warn once.
EVAL_TIMEOUT="${EVAL_TIMEOUT:-600}"
timeout_cmd=()
if command -v timeout &> /dev/null; then
    timeout_cmd=(timeout "$EVAL_TIMEOUT")
elif command -v gtimeout &> /dev/null; then
    timeout_cmd=(gtimeout "$EVAL_TIMEOUT")
else
    echo "warning: no timeout/gtimeout on PATH — a hung task will hang the suite"
fi

# Select tasks: args, or every directory under evals/tasks/.
tasks=("$@")
if [[ ${#tasks[@]} -eq 0 ]]; then
    shopt -s nullglob
    for d in "$TASKS_DIR"/*/; do
        tasks+=("$(basename "$d")")
    done
    shopt -u nullglob
fi
[[ ${#tasks[@]} -gt 0 ]] || { echo "no tasks under $TASKS_DIR"; exit 1; }

model_args=()
[[ -n "${EVAL_MODEL:-}" ]] && model_args=(--model "$EVAL_MODEL")
echo "model: ${EVAL_MODEL:-<cli default — pin EVAL_MODEL for comparable runs>}"

PASS=0
FAIL=0
for name in "${tasks[@]}"; do
    task="$TASKS_DIR/$name"
    if [[ ! -f "$task/prompt.md" || ! -f "$task/check.sh" ]]; then
        echo "[skip] $name: missing prompt.md or check.sh"
        continue
    fi

    work="$(mktemp -d)/work"
    mkdir -p "$work"
    [[ -d "$task/fixture" ]] && cp -R "$task/fixture/." "$work/"

    echo "── $name ──"
    # The answer file captures the agent's final text for graders that check
    # what was SAID (e.g. SAFE/UNSAFE); CLI noise goes to stderr.txt so a
    # grader can never pass on a log line instead of the model's own words.
    # ${arr[@]+...} guards: bash 3.2 + set -u aborts on empty-array expansion.
    ( cd "$work" && ${timeout_cmd[@]+"${timeout_cmd[@]}"} \
        claude -p "$(cat "$ROOT/$task/prompt.md")" \
        ${model_args[@]+"${model_args[@]}"} --permission-mode acceptEdits ) \
        > "$work/answer.txt" 2> "$work/stderr.txt"
    if bash "$task/check.sh" "$work"; then
        echo "  [pass] $name"
        PASS=$((PASS + 1))
        [[ "${EVAL_KEEP:-0}" == "1" ]] || rm -rf "$(dirname "$work")"
    else
        echo "  [FAIL] $name (workdir kept: $work)"
        FAIL=$((FAIL + 1))
    fi
done

echo
echo "evals: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
