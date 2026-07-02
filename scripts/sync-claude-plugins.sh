#!/bin/bash
set -uo pipefail

# sync-claude-plugins.sh — Materialize the Claude Code plugins declared in
# claude/settings.json onto this machine, headlessly and idempotently.
#
# The symlink sync (install.sh / sync-claude.sh) distributes *files*
# (skills, agents, hooks, settings.json). It does NOT install the plugins that
# come from marketplaces (official, autoresearch, document-skills, the-boris-way…) —
# those live in a per-machine cache and must be installed via the `claude` CLI.
#
# settings.json is the single source of truth: `claude plugin` commands write
# their state back into it (via the ~/.claude/settings.json symlink), and you
# commit/push it with scripts/auto-sync.sh (manual sync). This script just reads
# that declared state and reconciles the local machine to match — no separate
# plugin list to maintain.
#
# Reconciles:
#   .extraKnownMarketplaces  → `claude plugin marketplace add <repo|url>`
#   .enabledPlugins (true)   → `claude plugin install <plugin@marketplace>`

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../install.sh disable=SC1091
source "$SCRIPT_DIR/../install.sh"

SETTINGS="$DOTFILES_DIR/claude/settings.json"

echo ""
echo "=========================================="
echo "        Claude Plugin Sync                "
echo "=========================================="
echo ""

# --- preconditions ---------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
    log_error "claude CLI not found on PATH. Install Claude Code first."
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq not found. Install with: brew install jq"
    exit 1
fi
if [[ ! -f "$SETTINGS" ]]; then
    log_error "settings.json not found at: $SETTINGS"
    exit 1
fi
# Fail loud on corrupt JSON. Without this, a parse error in the loops below is
# swallowed (process substitution hides jq's exit code) → false "synced!".
if ! jq empty "$SETTINGS" 2>/dev/null; then
    log_error "settings.json is not valid JSON: $SETTINGS"
    exit 1
fi

failures=0

# --- 1. marketplaces -------------------------------------------------------
log_info "Reconciling marketplaces from extraKnownMarketplaces…"
# Keep stderr visible (no 2>/dev/null) so a broken/unauth CLI is diagnosable;
# || true keeps a list failure non-fatal (items just re-attempt, idempotent).
known_markets="$(claude plugin marketplace list || true)"

while IFS=$'\t' read -r name repo; do
    [[ -z "$name" ]] && continue
    if [[ -z "$repo" ]]; then
        log_warning "  $name: no github repo / git url in source — skipping"
        continue
    fi
    # Substring match against the (indented) `marketplace list` output; the bare
    # name appears as e.g. "  ❯ the-boris-way", so -Fx whole-line match would miss.
    if printf '%s\n' "$known_markets" | grep -qF "$name"; then
        log_info "  $name: already configured — skipping"
        continue
    fi
    if claude plugin marketplace add "$repo" >/dev/null 2>&1; then
        log_success "  $name: added ($repo)"
    else
        log_error "  $name: failed to add ($repo)"
        failures=$((failures + 1))
    fi
done < <(jq -r '
    (.extraKnownMarketplaces // {})
    | to_entries[]
    | [.key, (.value.source.repo // .value.source.url // "")]
    | @tsv
' "$SETTINGS")

# --- 2. plugins ------------------------------------------------------------
log_info "Reconciling plugins from enabledPlugins…"
installed="$(claude plugin list || true)"

while IFS= read -r plugin; do
    [[ -z "$plugin" ]] && continue
    if printf '%s\n' "$installed" | grep -qF "$plugin"; then
        log_info "  $plugin: already installed — skipping"
        continue
    fi
    if claude plugin install "$plugin" >/dev/null 2>&1; then
        log_success "  $plugin: installed"
    else
        log_error "  $plugin: failed to install (is its marketplace known?)"
        failures=$((failures + 1))
    fi
done < <(jq -r '
    (.enabledPlugins // {})
    | to_entries[]
    | select(.value == true or (.value | type == "object" and .enabled == true))
    | .key
' "$SETTINGS")

echo ""
if [[ "$failures" -eq 0 ]]; then
    log_success "Claude plugins synced!"
else
    log_warning "Claude plugin sync finished with $failures failure(s) — see above."
fi
echo ""
echo "Restart Claude Code to load newly installed plugins."
echo ""

exit "$failures"
