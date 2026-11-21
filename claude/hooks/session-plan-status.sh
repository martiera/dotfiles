#!/bin/sh
# SessionStart hook: print the status line of recently touched plans so a new
# session or agent can resume. A plan carries `<!-- status: step=3/5 checks=pass ... -->`.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -d docs/plans ] || exit 0
out=$(find docs/plans -name '*.md' -mtime -14 2>/dev/null | sort | while read -r f; do
  s=$(grep -m1 -o '<!-- status:[^>]*-->' "$f" 2>/dev/null) && echo "- $f: $s"
done)
[ -n "$out" ] && printf 'Active plans (status from the plan files; read the plan before continuing):\n%s\n' "$out"
exit 0
