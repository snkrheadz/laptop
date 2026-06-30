#!/bin/bash
# Behavior tests for install.sh / rollback.sh.
#
# SAFETY: every case runs the script's functions against an ISOLATED HOME (a
# throwaway mktemp dir exported as $HOME inside a subshell). The real home
# directory and real packages are never touched. The scripts are SOURCED (their
# main guards keep main from running), so only the symlink/backup/restore
# functions execute — no brew/mise/xcode, no network.
#
# Exit 0 when all cases pass; non-zero (listing the failed case) otherwise.

# SC1091: sourced paths are dynamic ($DOTFILES_DIR/...), shellcheck can't follow them.
# SC2030/SC2031: scoping HOME to the (..) subshell is the whole point — the isolation
# is intentional, not an accidental "lost" modification.
# shellcheck disable=SC1091,SC2030,SC2031

set -uo pipefail   # no -e: failures are aggregated, not aborted on

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1
DOTFILES_DIR="$(pwd)"

PASS=0
FAIL=0
pass() {
    echo "  [pass] $1"
    PASS=$((PASS + 1))
}
fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

assert_symlink_to() { # link, expected target
    local got
    got="$(readlink "$1" 2> /dev/null || true)"
    if [[ -L "$1" && "$got" == "$2" ]]; then
        pass "symlink $(basename "$1") -> repo"
    else
        fail "symlink $1 should point to $2 (got: ${got:-MISSING})"
    fi
}

# Track and clean up isolated homes even if a case aborts.
TMPDIRS=()
cleanup() {
    local d
    for d in "${TMPDIRS[@]:-}"; do
        [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
    done
}
trap cleanup EXIT
mkhome() {
    local d
    d="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"
    TMPDIRS+=("$d")
    echo "$d"
}

# Read-only fingerprint of the REAL home's managed entries, to prove the test
# left the real environment untouched.
real_home_fingerprint() {
    {
        readlink "$HOME/.zshrc" 2> /dev/null
        readlink "$HOME/.gitconfig" 2> /dev/null
        ls -d "$HOME/.dotfiles_backup" 2> /dev/null
    } | sort
}

# ── Case 1: symlink creation points at the repo ──────────────────────
case_symlink_creation() {
    echo "case: symlink creation"
    local h
    h="$(mkhome)"
    ( set -e; export HOME="$h"; source "$DOTFILES_DIR/install.sh"; create_symlinks ) > /dev/null 2>&1
    assert_symlink_to "$h/.zshrc" "$DOTFILES_DIR/zsh/.zshrc"
    assert_symlink_to "$h/.gitconfig" "$DOTFILES_DIR/git/.gitconfig"
    assert_symlink_to "$h/.tmux.conf" "$DOTFILES_DIR/tmux/.tmux.conf"
}

# ── Case 2: existing real file is backed up before being replaced ─────
case_backup() {
    echo "case: backup of existing file"
    local h bdir
    h="$(mkhome)"
    printf 'ORIGINAL_ZSHRC\n' > "$h/.zshrc"   # a real file, not a symlink
    ( set -e; export HOME="$h"; source "$DOTFILES_DIR/install.sh"; create_backup ) > /dev/null 2>&1
    bdir="$(cat "$h/.dotfiles_last_backup" 2> /dev/null || true)"
    if [[ -n "$bdir" && -f "$bdir/.zshrc" && "$(cat "$bdir/.zshrc")" == "ORIGINAL_ZSHRC" ]]; then
        pass "existing .zshrc backed up with original content"
    else
        fail "backup did not preserve original .zshrc (bdir=${bdir:-none})"
    fi
}

# ── Case 3: rollback restores the original file ──────────────────────
case_rollback() {
    echo "case: rollback restores original"
    local h bdir
    h="$(mkhome)"
    printf 'ORIGINAL_ZSHRC\n' > "$h/.zshrc"
    ( set -e; export HOME="$h"; source "$DOTFILES_DIR/install.sh"; create_backup; create_symlinks ) > /dev/null 2>&1
    bdir="$(cat "$h/.dotfiles_last_backup" 2> /dev/null || true)"
    ( set -e; export HOME="$h"; source "$DOTFILES_DIR/rollback.sh"; remove_symlinks; restore_backup "$bdir" ) > /dev/null 2>&1
    if [[ ! -L "$h/.zshrc" && -f "$h/.zshrc" && "$(cat "$h/.zshrc")" == "ORIGINAL_ZSHRC" ]]; then
        pass "rollback restored original .zshrc (not a symlink)"
    else
        fail "rollback did not restore original .zshrc"
    fi
}

# ── Case 4: running install twice is idempotent ──────────────────────
case_idempotent() {
    echo "case: idempotent re-run"
    local h rc
    h="$(mkhome)"
    ( set -e; export HOME="$h"; source "$DOTFILES_DIR/install.sh"; create_symlinks; create_symlinks ) > /dev/null 2>&1
    rc=$?
    if [[ $rc -eq 0 ]]; then
        assert_symlink_to "$h/.zshrc" "$DOTFILES_DIR/zsh/.zshrc"
    else
        fail "second create_symlinks run failed (rc=$rc)"
    fi
}

echo "test-install: running behavior tests against isolated HOME"
before="$(real_home_fingerprint)"

case_symlink_creation
case_backup
case_rollback
case_idempotent

# Safety: the real home must be unchanged by this test run.
after="$(real_home_fingerprint)"
if [[ "$before" == "$after" ]]; then
    pass "real HOME untouched by test run"
else
    fail "real HOME changed during test run"
fi

echo "── test-install: ${PASS} passed, ${FAIL} failed ──"
[[ $FAIL -eq 0 ]]
