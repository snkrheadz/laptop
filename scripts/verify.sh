#!/bin/bash
# Unified verification entrypoint for this dotfiles repo.
#
# Bundles every check that defines a "healthy" tree into ONE command so neither
# humans nor agents have to remember the incantation:
#   1. shellcheck   — via scripts/lint-shell.sh (all shell scripts)
#   2. pre-commit   — `pre-commit run --all-files` (incl. gitleaks)
#   3. symlink      — no broken symlinks pointing into this repo
#   4. shell-init   — ~/.zshrc loads (local) / zsh syntax check (CI)
#   5. gitleaks     — standalone secret scan (also runs inside pre-commit)
#   6. install-tests — install.sh / rollback.sh behavior tests (isolated HOME)
#   7. docs-drift   — every .claude/skills/ skill appears in README.md's table
#   8. hook-tests   — every claude/hooks/*_test.sh suite (red/green + fail-open)
#
# Same command in CI and locally; the environment is detected and inapplicable
# checks are reported as SKIP (with a reason) — never silently treated as pass.
# Each underlying check is still runnable on its own; this only orchestrates.
#
# Exit 0 when no check FAILs (SKIP does not fail the run); non-zero otherwise.

set -uo pipefail

# Anchor to the repo root so every check runs against the same tree regardless
# of the caller's CWD (lesson from scripts/lint-shell.sh).
cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
DOTFILES_DIR="$(pwd)"

# Environment: CI sets CI=true; GitHub Actions also sets GITHUB_ACTIONS=true.
# Require GITHUB_ACTIONS too where possible to reduce false positives from a
# stray CI=true in a local shell.
ENV="local"
if [[ -n "${GITHUB_ACTIONS:-}" || -n "${CI:-}" ]]; then
    ENV="ci"
fi

# Result accumulation (name / status PASS|FAIL|SKIP / detail).
R_NAME=()
R_STATUS=()
R_DETAIL=()
record() {
    R_NAME+=("$1")
    R_STATUS+=("$2")
    R_DETAIL+=("$3")
}

hr() { echo "── $1 ──────────────────────────────"; }

# 1. shellcheck over all shell scripts.
check_shellcheck() {
    hr "shellcheck"
    if ! command -v shellcheck &> /dev/null; then
        echo "  shellcheck not installed"
        record "shellcheck" "SKIP" "shellcheck 未インストール"
        return
    fi
    if bash scripts/lint-shell.sh; then
        record "shellcheck" "PASS" ""
    else
        record "shellcheck" "FAIL" "shellcheck 指摘あり"
    fi
}

# 2. pre-commit hook suite (includes gitleaks, whitespace, yaml, etc).
check_precommit() {
    hr "pre-commit"
    if ! command -v pre-commit &> /dev/null; then
        echo "  pre-commit not installed"
        record "pre-commit" "SKIP" "pre-commit 未インストール"
        return
    fi
    if pre-commit run --all-files; then
        record "pre-commit" "PASS" ""
    else
        record "pre-commit" "FAIL" "フック失敗"
    fi
}

# 3. Full working-tree secret scan. pre-commit's gitleaks hook runs in
#    `protect --staged` mode (staged diff only) — in a fresh CI checkout nothing
#    is staged, so it scans nothing. This explicit `detect` restores the
#    full-tree scan the CI did before, so secret coverage does not regress.
check_gitleaks() {
    hr "gitleaks"
    if ! command -v gitleaks &> /dev/null; then
        echo "  gitleaks not installed"
        record "gitleaks" "SKIP" "gitleaks 未インストール"
        return
    fi
    local out rc
    out="$(gitleaks detect --source=. --no-git 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        record "gitleaks" "PASS" ""
    else
        echo "$out" | tail -20
        record "gitleaks" "FAIL" "秘密情報検出"
    fi
}

# 4. No broken symlinks pointing into this repo. The set of links is DERIVED
#    (not a re-declared expected list) so it cannot drift from install.sh.
check_symlinks() {
    hr "symlink"
    # DERIVE the link set instead of hardcoding paths (no drift vs install.sh):
    # scan HOME's top level plus the app-config trees this repo installs into.
    # Bounded so we never walk ~/Library etc. New links under these trees are
    # picked up automatically.
    local found=0 broken=0 link target
    local links
    links="$( {
        find "$HOME" -maxdepth 1 -type l
        [[ -d "$HOME/.config" ]] && find "$HOME/.config" -type l
        [[ -d "$HOME/.claude" ]] && find "$HOME/.claude" -type l
    } 2> /dev/null )"

    while IFS= read -r link; do
        [[ -n "$link" ]] || continue
        target="$(readlink "$link")"
        case "$target" in
            "$DOTFILES_DIR"/*)
                found=$((found + 1))
                if [[ ! -e "$link" ]]; then   # -e follows the link: false = broken
                    echo "  [BROKEN] $link -> $target"
                    broken=$((broken + 1))
                fi
                ;;
        esac
    done <<< "$links"

    if [[ $found -eq 0 ]]; then
        echo "  no dotfiles symlinks found (not installed?)"
        record "symlink" "SKIP" "dotfiles を指す symlink 無し(未インストール)"
    elif [[ $broken -eq 0 ]]; then
        echo "  $found dotfiles symlink(s), none broken"
        record "symlink" "PASS" "$found 本 健全"
    else
        record "symlink" "FAIL" "$broken/$found 本 壊れ"
    fi
}

# 4. Shell init: full source locally, syntax check in CI (no personal zsh env).
check_shell_init() {
    hr "shell-init"
    if ! command -v zsh &> /dev/null; then
        echo "  zsh not installed"
        record "shell-init" "SKIP" "zsh 未インストール"
        return
    fi

    if [[ "$ENV" == "ci" ]]; then
        local errs=0 f
        shopt -s nullglob
        local nout
        for f in zsh/.zshrc zsh/.aliases zsh/configs/*.zsh zsh/configs/post/*.zsh; do
            [[ -f "$f" ]] || continue
            if ! nout="$(zsh -n "$f" 2>&1)"; then
                echo "  [SYNTAX] $f"
                [[ -n "$nout" ]] && echo "$nout"
                errs=$((errs + 1))
            fi
        done
        shopt -u nullglob
        if [[ $errs -eq 0 ]]; then
            record "shell-init" "PASS" "ci: zsh -n 構文チェック"
        else
            record "shell-init" "FAIL" "$errs 件 構文エラー"
        fi
        return
    fi

    # local
    if [[ ! -L "$HOME/.zshrc" ]]; then
        echo "  ~/.zshrc is not an installed symlink"
        record "shell-init" "SKIP" "未インストール (~/.zshrc)"
        return
    fi
    # Pass the path as an argument (not interpolated into the -c string) so a
    # space in $HOME can't break word-splitting. Capture once — no double run.
    local sout
    if sout="$(zsh -c 'source "$1"' -- "$HOME/.zshrc" 2>&1)"; then
        record "shell-init" "PASS" "読み込み OK (~/.zshrc)"
    else
        echo "  ~/.zshrc failed to source:"
        [[ -n "$sout" ]] && echo "$sout"
        record "shell-init" "FAIL" "読み込み失敗 (~/.zshrc)"
    fi
}

# 6. Behavior tests for install.sh / rollback.sh (run against an isolated HOME;
#    never touches the real environment). Catches regressions in the destructive
#    symlink/backup/restore paths that static checks cannot see.
check_install_tests() {
    hr "install-tests"
    if [[ ! -f tests/test-install.sh ]]; then
        echo "  tests/test-install.sh not found"
        record "install-tests" "SKIP" "テスト未配置"
        return
    fi
    if bash tests/test-install.sh; then
        record "install-tests" "PASS" ""
    else
        record "install-tests" "FAIL" "振る舞いテスト失敗"
    fi
}

# 7. Docs drift — every local skill on disk must appear in README.md's skill
#    table. Hand-maintained enumerations rot silently (a stale count survived
#    two releases before PR #116 caught it by hand); this makes the drift a
#    FAIL instead of trusting memory. Disk → docs direction only.
check_docs_drift() {
    hr "docs-drift"
    local missing=0 n
    for s in .claude/skills/*/; do
        [[ -d "$s" ]] || continue
        n="$(basename "$s")"
        if ! grep -qF "\`$n\`" README.md; then
            echo "  skill '$n' is not documented in README.md"
            missing=$((missing + 1))
        fi
    done
    if [[ $missing -eq 0 ]]; then
        record "docs-drift" "PASS" ""
    else
        record "docs-drift" "FAIL" "README.md に載っていない skill が ${missing} 件"
    fi
}

# 8. Behavior tests for the lifecycle hooks. The test set is DERIVED (every
#    claude/hooks/*_test.sh runs) so adding a hook test never requires touching
#    this file — same no-drift principle as the symlink and docs-drift checks.
check_hook_tests() {
    hr "hook-tests"
    local ran=0 failed=0 t
    shopt -s nullglob
    for t in claude/hooks/*_test.sh; do
        ran=$((ran + 1))
        echo "  → $t"
        if ! bash "$t"; then
            failed=$((failed + 1))
        fi
    done
    shopt -u nullglob
    if [[ $ran -eq 0 ]]; then
        echo "  no claude/hooks/*_test.sh found"
        record "hook-tests" "SKIP" "テスト未配置"
    elif [[ $failed -eq 0 ]]; then
        record "hook-tests" "PASS" "${ran} スイート"
    else
        record "hook-tests" "FAIL" "${failed}/${ran} スイート失敗"
    fi
}

# 9. Hook wiring parity: every ~/.claude/hooks/*.sh referenced in
#    claude/settings.json must exist in claude/hooks/ (and not be a test file).
#    install.sh links hooks by glob, so a repo file present here is guaranteed
#    to be linked; a wired-but-missing file means the hook is dead on install.
check_hook_wiring() {
    hr "hook-wiring"
    local missing=0 wired
    # shellcheck disable=SC2088  # matching the literal '~/...' string in JSON, not expanding it
    wired=$(grep -oE '~/.claude/hooks/[A-Za-z0-9._-]+\.sh' claude/settings.json | sort -u)
    if [[ -z "$wired" ]]; then
        record "hook-wiring" "SKIP" "settings.json に hooks 配線なし"
        return
    fi
    while IFS= read -r w; do
        local n
        n="$(basename "$w")"
        if [[ "$n" == *_test.sh ]]; then
            echo "  wired hook is a test file: $n"
            missing=$((missing + 1))
        elif [[ ! -f "claude/hooks/$n" ]]; then
            echo "  wired hook has no repo file: claude/hooks/$n"
            missing=$((missing + 1))
        fi
    done <<< "$wired"
    if [[ $missing -eq 0 ]]; then
        record "hook-wiring" "PASS" ""
    else
        record "hook-wiring" "FAIL" "配線と実ファイルの不一致 ${missing} 件"
    fi
}

echo "verify: env=$ENV  root=$DOTFILES_DIR"
check_shellcheck
check_precommit
check_gitleaks
check_symlinks
check_install_tests
check_shell_init
check_docs_drift
check_hook_tests
check_hook_wiring

echo
echo "════ verify summary ════"
pass=0 fail=0 skip=0
for i in "${!R_NAME[@]}"; do
    printf "  %-4s  %-11s%s\n" "${R_STATUS[$i]}" "${R_NAME[$i]}" "${R_DETAIL[$i]:+ — ${R_DETAIL[$i]}}"
    case "${R_STATUS[$i]}" in
        PASS) pass=$((pass + 1)) ;;
        FAIL) fail=$((fail + 1)) ;;
        SKIP) skip=$((skip + 1)) ;;
    esac
done
echo "  → ${pass} pass / ${fail} fail / ${skip} skip  (env=$ENV)"

[[ $fail -eq 0 ]]
