#!/bin/bash
# Lint every shell script under version control with shellcheck.
#
# Target set is DERIVED, not a hand-maintained list: a file is in scope when it
# is git-tracked AND is either named *.sh OR carries a shell shebang
# (sh / bash / dash / ksh, including `#!/usr/bin/env <shell>`). zsh is excluded
# because shellcheck cannot parse it. New scripts are picked up automatically.
#
# Used by CI (.github/workflows/main.yml) and runnable locally — same procedure
# in both places, so CI and local stay in sync.
#
# Exit 0 when every in-scope script passes; non-zero if shellcheck finds issues
# or is unavailable.

set -euo pipefail

# Anchor to the repository root so `git ls-files` (and the relative paths it
# emits) resolve identically no matter where the script is invoked from. Without
# this, running from a subdirectory silently scans only that subtree.
cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

# Scripts to permanently exclude from the scan. Keep empty unless there is a
# justified reason; any entry here is visible and reviewable in the diff.
# Paths are repo-relative (as emitted by `git ls-files`).
EXCLUDES=(
)

is_excluded() {
    local candidate="$1" e
    # ${EXCLUDES[@]+...} guards against "unbound variable" on bash 3.2 (macOS)
    # when the array is empty under `set -u`.
    for e in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
        [[ "$candidate" == "$e" ]] && return 0
    done
    return 1
}

# Decide whether a git-tracked file is an in-scope shell script.
is_shell_script() {
    local f="$1"

    # *.sh is always in scope.
    [[ "$f" == *.sh ]] && return 0

    # Otherwise inspect the shebang.
    local first
    IFS= read -r first < "$f" 2>/dev/null || return 1
    first=${first%$'\r'}                  # tolerate CRLF
    first=${first#$'\xef\xbb\xbf'}        # tolerate UTF-8 BOM
    [[ "$first" == '#!'* ]] || return 1

    # Resolve the interpreter, handling `#!/usr/bin/env [-S] <shell>` — skip any
    # leading flags (e.g. env's -S/--split-string) before the interpreter name.
    local shebang=${first#'#!'}
    read -r -a parts <<< "$shebang"
    local interp=${parts[0]:-}
    if [[ "${interp##*/}" == "env" ]]; then
        local i=1
        while [[ "${parts[$i]:-}" == -* ]]; do ((i++)); done
        interp=${parts[$i]:-}
    fi

    case "${interp##*/}" in
        sh | bash | dash | ksh) return 0 ;;
        *) return 1 ;;
    esac
}

if ! command -v shellcheck &> /dev/null; then
    echo "Error: shellcheck is not installed. Run 'brew install shellcheck'." >&2
    exit 1
fi

# Build the target list from version-controlled files.
targets=()
while IFS= read -r f; do
    [[ -f "$f" ]] || continue           # skip deleted-but-tracked (symlinks to regular files pass -f)
    is_excluded "$f" && continue
    is_shell_script "$f" && targets+=("$f")
done < <(git ls-files)

if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No shell scripts found to lint." >&2
    exit 0
fi

echo "Linting ${#targets[@]} shell script(s):"
printf '  %s\n' "${targets[@]}"

shellcheck "${targets[@]}"
echo "shellcheck: all ${#targets[@]} script(s) passed."
