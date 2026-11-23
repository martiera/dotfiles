#!/bin/sh
# Claude Code adapter: PreToolUse(Bash) hook around the agent-neutral guard
# (guard-core.sh, a copy of bin/herdr-guard installed next to this file).
command -v jq >/dev/null 2>&1 || exit 0
core="$(dirname "$0")/guard-core.sh"
[ -x "$core" ] || exit 0
reason=$("$core" --json --project "${CLAUDE_PROJECT_DIR:-.}" 2>&1 >/dev/null)
[ $? = 2 ] || exit 0
jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
