#!/bin/bash
set -e

# sync-claude.sh — Sync ONLY the Claude Code symlinks (~/.claude/*).
#
# Unlike install.sh, this skips Homebrew upgrades, mise, security tooling,
# backups, and auto-sync setup. Use it for a fast refresh after editing
# anything under claude/ (agents, skills, commands, hooks, settings.json).
#
# It reuses install.sh's symlink functions as the single source of truth:
# sourcing install.sh defines the functions but does NOT run main (guarded
# by a BASH_SOURCE check at the bottom of install.sh).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../install.sh disable=SC1091
source "$SCRIPT_DIR/../install.sh"

echo ""
echo "=========================================="
echo "         Claude Symlink Sync              "
echo "=========================================="
echo ""

check_macos
setup_claude_core      # statusline, hooks, CLAUDE.md, settings.json
setup_claude_agents    # ~/.claude/agents/*.md (+ stale symlink cleanup)
setup_claude_skills    # ~/.claude/skills/*
setup_claude_commands  # ~/.claude/commands/*.md

echo ""
log_success "Claude symlinks synced!"

# Also reconcile marketplace plugins declared in settings.json (best-effort).
if command -v claude >/dev/null 2>&1; then
    bash "$SCRIPT_DIR/sync-claude-plugins.sh" || log_warning "Plugin sync had issues"
else
    log_warning "claude CLI not found — skipping plugin sync"
fi

echo ""
echo "Next steps:"
echo "  1. Start a new Claude Code session to pick up the changes"
echo "  2. Role agents ship via the-boris-way marketplace packs (eng/marketer/designer/research)"
echo ""
