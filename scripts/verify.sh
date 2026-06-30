#!/bin/bash
# Unified verification entrypoint for this dotfiles repo.
#
# Bundles every check that defines a "healthy" tree into ONE command so neither
# humans nor agents have to remember the incantation:
#   1. shellcheck   — via scripts/lint-shell.sh (all shell scripts)
#   2. pre-commit   — `pre-commit run --all-files` (incl. gitleaks)
#   3. symlink      — no broken symlinks pointing into this repo
#   4. shell-init   — ~/.zshrc loads (local) / zsh syntax check (CI)
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

# Environment: GitHub Actions (and most CI) set CI=true.
ENV="local"
[[ -n "${CI:-}" ]] && ENV="ci"

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

# 3. No broken symlinks pointing into this repo. The set of links is DERIVED
#    (not a re-declared expected list) so it cannot drift from install.sh.
check_symlinks() {
    hr "symlink"
    local roots=(
        "$HOME"
        "$HOME/.claude" "$HOME/.claude/hooks" "$HOME/.claude/commands"
        "$HOME/.claude/agents" "$HOME/.claude/skills"
        "$HOME/.zsh" "$HOME/.config/ghostty" "$HOME/.config/mise"
    )
    local found=0 broken=0 link target root
    shopt -s nullglob dotglob
    for root in "${roots[@]}"; do
        [[ -d "$root" ]] || continue
        for link in "$root"/*; do
            [[ -L "$link" ]] || continue
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
        done
    done
    shopt -u nullglob dotglob

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
        for f in zsh/.zshrc zsh/.aliases zsh/configs/*.zsh zsh/configs/post/*.zsh; do
            [[ -f "$f" ]] || continue
            if ! zsh -n "$f" 2> /dev/null; then
                echo "  [SYNTAX] $f"
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
    if zsh -c "source $HOME/.zshrc" > /dev/null 2>&1; then
        record "shell-init" "PASS" "読み込み OK (~/.zshrc)"
    else
        echo "  ~/.zshrc failed to source:"
        zsh -c "source $HOME/.zshrc" 2>&1 | sed 's/^/    /' | head -20
        record "shell-init" "FAIL" "読み込み失敗 (~/.zshrc)"
    fi
}

echo "verify: env=$ENV  root=$DOTFILES_DIR"
check_shellcheck
check_precommit
check_symlinks
check_shell_init

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
