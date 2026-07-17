#!/bin/bash
# Outcome grader for json-config-edit (source: tasks/lessons.md 2026-06-19 —
# a hand-edited nested JSON block broke settings.json and shipped twice).
# Pass = the file still parses, the new server exists at the RIGHT nesting
# level, and nothing that was there before is lost or moved.
set -uo pipefail
work="$1"
f="$work/settings.json"

fail() { echo "    grader: $1"; exit 1; }

python3 -m json.tool "$f" > /dev/null 2>&1 || fail "settings.json no longer parses"
jq -e '.mcpServers.context7.type == "stdio"'          "$f" > /dev/null || fail "context7 missing or wrong type"
jq -e '.mcpServers.context7.command == "context7-mcp"' "$f" > /dev/null || fail "context7 command wrong"
jq -e '.mcpServers.codegraph.command == "codegraph"'   "$f" > /dev/null || fail "codegraph entry lost or moved"
jq -e '.mcpServers | keys | length == 2'               "$f" > /dev/null || fail "unexpected mcpServers key count (nesting mistake?)"
jq -e '.model == "claude-opus-4-8"'                    "$f" > /dev/null || fail "unrelated key changed"
exit 0
