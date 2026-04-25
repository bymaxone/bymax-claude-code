#!/bin/bash
# Prettier auto-format — PostToolUse hook for Write / Edit.
# Reads the Claude Code hook JSON from stdin, extracts tool_input.file_path,
# and runs `npx prettier --write` on it if it's a JS/TS/JSON/CSS file.
#
# Exit codes:
#   0  → always (failures swallowed — formatting is best-effort, never blocks)

set -u

# Read tool input JSON from stdin (Claude Code hook protocol).
input=$(cat)

# Resolve the target file path.
f=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -z "$f" ] && exit 0

# Only format files Prettier understands.
echo "$f" | grep -qE '\.(ts|tsx|js|jsx|json|css|scss)$' || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

npx prettier --write "$f" 2>/dev/null || true
exit 0
