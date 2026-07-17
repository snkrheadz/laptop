#!/bin/bash
# Eval runner: for each task under evals/tasks/, copy its fixture into a
# throwaway workdir, run `claude -p` with the task prompt inside it, then
# grade the OUTCOME with the task's check.sh (which inspects the final state
# of the workdir + the agent's answer, never the path taken).
#
# Usage: ./evals/run.sh [task-name ...]      # default: every task
#   EVAL_MODEL=<model>   pin the model (default: the CLI's configured default)
#   EVAL_KEEP=1          keep workdirs for transcript reading on failure
#
# Exit 0 when every selected task passes; non-zero otherwise.

set -uo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
TASKS_DIR="evals/tasks"

command -v claude &> /dev/null || { echo "claude CLI not found"; exit 1; }

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
    # what was SAID (e.g. SAFE/UNSAFE); file-state graders inspect $work.
    ( cd "$work" && claude -p "$(cat "$OLDPWD/$task/prompt.md")" \
        "${model_args[@]}" --permission-mode acceptEdits ) > "$work/answer.txt" 2>&1
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
