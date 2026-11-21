#!/bin/sh
# Stop hook: ask for an independent review when code files changed and the
# current code diff has no approved review (or recorded skip).
# Fires at the end of every turn, so it is a reminder, not a hard gate: with
# stop_hook_active set it lets the agent stop on the second attempt.
# Never blocks when jq/herdr-review are missing, when not in a git repo, or in a tester pane.
command -v jq >/dev/null 2>&1 || exit 0
command -v herdr-review >/dev/null 2>&1 || exit 0
input=$(cat)
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = true ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# the tester's own pane must never be blocked
if [ -n "${HERDR_PANE_ID:-}" ]; then
  for f in /tmp/herdr-review/*/pending.json; do
    [ -f "$f" ] && grep -q "\"pane\": *\"$HERDR_PANE_ID\"" "$f" && exit 0
  done
fi

fp=$(herdr-review --fingerprint 2>/dev/null) || exit 0
[ -z "$fp" ] && exit 0                       # no code changes (clean or docs only)
gd=$(git rev-parse --git-dir)
for m in herdr-review.ok herdr-review.skip; do
  [ "$(cat "$gd/$m" 2>/dev/null)" = "$fp" ] && exit 0
done
jq -n '{decision:"block", reason:"Code files changed and this exact diff has no approved herdr-review. Run the herdr-review skill, or ask the user to run `! herdr-review --skip`."}'
